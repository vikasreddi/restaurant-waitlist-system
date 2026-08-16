module Allocation
  # Connects the pure Allocation::DecisionEngine to the real database
  # (allocation-algorithm.md §12/§18; this phase's own governing prompt §3).
  # Selects and persists AT MOST ONE candidate per call:
  #
  #   ConfigurationGenerator + current WAITING entries
  #     -> DecisionEngine (pure, unchanged)
  #     -> winner
  #     -> ONE database transaction: lock table(s), re-check availability,
  #        re-check the entry is still `waiting`, create SeatingAssignment
  #        (pending) + 1-2 SeatingAssignmentTable rows, generate a
  #        seating_code, transition the entry `waiting -> ready`, commit.
  #
  # If the DecisionEngine's proposed winner turns out to be unavailable by
  # the time the transaction actually locks it (lost a race to another
  # allocation), this service does NOT silently pick a second candidate —
  # it reports :stale_candidate and returns. Repeating the whole decide+
  # reserve cycle, and wiring this service to actual triggers (join/release/
  # no-show/leave), are both explicitly deferred to the next phase.
  class ReservationService
    Result = Struct.new(:outcome, :seating_assignment, :queue_entry, keyword_init: true) do
      def success?
        outcome == :success
      end
    end

    MAX_SEATING_CODE_ATTEMPTS = 5

    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now:)
      @now = now
    end

    def call
      decision = DecisionEngine.decide(
        waiting_entries: QueueEntry.where(status: "waiting").to_a,
        configurations: ConfigurationGenerator.call,
        now: @now
      )

      return Result.new(outcome: :no_candidate) unless decision.winner?

      reserve(decision.winner)
    rescue ActiveRecord::RecordNotUnique
      # Defense-in-depth constraint violation (allocation-algorithm.md §18;
      # UNIQUE(table_id) WHERE released_at IS NULL, or the seating_code
      # partial unique index) fired despite the row locks below — some other
      # write path claimed the same resource outside this service's own
      # locking discipline. Report it as a lost race, never swallow it as
      # "no availability" and never retry with a different candidate here.
      Result.new(outcome: :stale_candidate)
    end

    private

    def reserve(candidate)
      table_ids = candidate.configuration.table_ids.sort # deterministic lock order, allocation-algorithm.md §18
      outcome = nil
      assignment = nil
      entry = nil

      ActiveRecord::Base.transaction do
        tables = Table.where(id: table_ids).order(:id).lock.to_a

        if tables.size != table_ids.size || tables.any? { |table| !table.free? }
          outcome = :stale_candidate
          raise ActiveRecord::Rollback
        end

        entry = QueueEntry.lock.find(candidate.entry.id)
        unless entry.status == "waiting"
          outcome = :stale_candidate
          raise ActiveRecord::Rollback
        end

        assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
        tables.each { |table| SeatingAssignmentTable.create!(seating_assignment: assignment, table: table) }

        assign_seating_code!(entry)
        outcome = :success
      end

      case outcome
      when :success
        Result.new(outcome: :success, seating_assignment: assignment, queue_entry: entry)
      else
        Result.new(outcome: outcome)
      end
    end

    # Retries inside a savepoint (not the outer transaction) on a genuine
    # seating_code collision, per this phase's governing prompt §15 — a
    # failed UNIQUE violation would otherwise poison the entire enclosing
    # transaction (the same PG::InFailedSqlTransaction lesson already
    # applied elsewhere in this project, see CORR-004's Rails-console
    # verification pattern: `ActiveRecord::Base.transaction(requires_new:
    # true)` is a real SAVEPOINT, so a failed attempt rolls back only this
    # one update, not the surrounding reservation). Collision space is
    # ~1.07 billion codes (SeatingCodeGenerator), so exhausting every
    # attempt here in practice only happens under a deliberately forced
    # test.
    def assign_seating_code!(entry)
      attempts = 0
      begin
        attempts += 1
        code = SeatingCodeGenerator.call
        ActiveRecord::Base.transaction(requires_new: true) do
          entry.update!(status: "ready", ready_at: @now, seating_code: code)
        end
      rescue ActiveRecord::RecordNotUnique
        retry if attempts < MAX_SEATING_CODE_ATTEMPTS
        raise
      end
    end
  end
end
