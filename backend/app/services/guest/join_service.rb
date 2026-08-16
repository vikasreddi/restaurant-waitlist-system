module Guest
  # Implements functional-spec.md §1 (Guest join). Owns the idempotency
  # decision and the transaction boundary — the controller only translates
  # its Result into an HTTP response; QueueEntry only knows how to persist
  # and validate itself.
  #
  # As of Phase 5B.5.4, a genuinely NEW join (never a replay/conflict/
  # validation-error outcome) triggers Allocation::Orchestrator after the
  # entry's creation has committed (this phase's governing prompt §10/§12):
  # if a compatible table configuration is already available, the entry may
  # synchronously become `ready` before this service returns. If none is
  # available, the entry simply stays `waiting` — the orchestrator's
  # `:no_candidate` result is a normal outcome, not an error. Still
  # explicitly NOT this service's job: choosing which table/configuration
  # wins, or any part of the scoring/reservation logic itself — that's
  # entirely Allocation::DecisionEngine/ReservationService, called as-is.
  class JoinService
    Result = Struct.new(:outcome, :queue_entry, :errors, keyword_init: true)

    def self.call(group_size:, phone_number:, idempotency_key:)
      new(group_size: group_size, phone_number: phone_number, idempotency_key: idempotency_key).call
    end

    def initialize(group_size:, phone_number:, idempotency_key:)
      @group_size = group_size
      @phone_number = phone_number
      @idempotency_key = idempotency_key
    end

    def call
      # A first, non-authoritative check — this alone is NOT what makes retries
      # safe under concurrency (functional-spec.md §11 / api-spec.md): two
      # requests can both observe "not found" here. The actual guarantee comes
      # from the database's unique constraint on idempotency_key, handled below
      # via the ActiveRecord::RecordNotUnique rescue.
      existing = @idempotency_key.present? ? QueueEntry.find_by(idempotency_key: @idempotency_key) : nil
      return resolve_existing(existing) if existing

      create_new_entry
    end

    private

    def create_new_entry
      entry = QueueEntry.create!(
        group_size: @group_size,
        phone_number: @phone_number,
        idempotency_key: @idempotency_key
      )
      # Entry creation is already committed at this point (a single create!
      # is its own implicit transaction) — the orchestrator runs strictly
      # after, in its own separate transaction(s) per ReservationService
      # call, never nested inside this one (§11). Runs only for a genuinely
      # NEW entry — never on an idempotent replay/conflict, which return
      # from #call before ever reaching this method (§12).
      Allocation::Orchestrator.call(now: Time.current)
      Result.new(outcome: :created, queue_entry: entry.reload)
    rescue ActiveRecord::RecordInvalid => e
      # Genuine bad input only (e.g. group_size <= 0, blank phone_number).
      # idempotency_key uniqueness is deliberately NOT a Rails validation
      # (CORR-005, see the model) specifically so this branch can never fire
      # for a duplicate key — that case is only ever reachable via the
      # RecordNotUnique rescue below, from the database's own unique index.
      Result.new(outcome: :validation_error, errors: e.record.errors)
    rescue ActiveRecord::RecordNotUnique
      # Lost a genuine concurrent race for this idempotency_key: another request
      # committed first, in the window between our find_by above and our INSERT.
      # This is the actual idempotency guarantee — resolve exactly like a normal
      # sequential retry would.
      resolve_existing(QueueEntry.find_by!(idempotency_key: @idempotency_key))
    end

    # Same idempotency key, request already exists. Either this is a genuine
    # retry (identical inputs — return the existing entry, do NOT mutate it or
    # generate a new token), or the key is being reused for a logically
    # different request (functional-spec.md / this phase's governing prompt
    # §13) — which is a conflict, not a silent update.
    def resolve_existing(entry)
      if same_logical_request?(entry)
        Result.new(outcome: :idempotent_replay, queue_entry: entry)
      else
        Result.new(outcome: :conflict, queue_entry: entry)
      end
    end

    def same_logical_request?(entry)
      entry.group_size == @group_size.to_i && entry.phone_number == @phone_number.to_s
    end
  end
end
