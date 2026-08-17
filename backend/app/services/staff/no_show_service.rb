module Staff
  # Implements functional-spec.md §8 / api-spec.md "POST /staff/queue/no-
  # show". A staff-initiated counterpart to DEC-015's automatic expiration
  # (§8a) — both converge on the identical outcome (entry -> no_show,
  # SeatingAssignment released if one existed), the record does not
  # distinguish which path caused it.
  #
  # WAITING -> no_show: no SeatingAssignment exists yet, nothing to release.
  # READY -> no_show: releases the current (pending) SeatingAssignment
  # atomically with the status transition, mirroring Guest::LeaveService's
  # exact release pattern (and lock order: the entry, then its own
  # current_seating_assignment).
  # Already no_show -> idempotent no-op (api-spec.md: "Idempotent against an
  # already-terminal entry").
  # seated/left -> :invalid_target — no_show only ever applies to a currently
  # active waitlist position (waiting or ready); a seated group is released,
  # not marked no-show, and a left entry already has its own terminal
  # outcome. This also guarantees a no_show entry can never later be seated —
  # Staff::ConfirmSeatingService#classify already rejects `left`/`no_show`
  # codes as :conflict, and no_show is terminal (QueueEntry.STATUSES), so
  # this needs no new enforcement here.
  class NoShowService
    Result = Struct.new(:outcome, :queue_entry, keyword_init: true)

    def self.call(entry_id:)
      new(entry_id: entry_id).call
    end

    def initialize(entry_id:)
      @entry_id = entry_id
    end

    def call
      return Result.new(outcome: :not_found) if @entry_id.blank?

      entry = nil
      invalid = false
      released = false

      ActiveRecord::Base.transaction do
        entry = QueueEntry.lock.find_by(id: @entry_id)
        next if entry.nil?

        case entry.status
        when "waiting"
          entry.update!(status: "no_show", no_show_at: Time.current)
        when "ready"
          released = release_current_assignment!(entry)
          entry.update!(status: "no_show", no_show_at: Time.current)
        when "no_show"
          # already terminal — idempotent no-op, no side effects re-fired.
        else # "seated", "left"
          invalid = true
        end
      end

      return Result.new(outcome: :not_found) if entry.nil?
      return Result.new(outcome: :invalid_target, queue_entry: entry) if invalid

      Allocation::Orchestrator.call(now: Time.current) if released

      Result.new(outcome: :success, queue_entry: entry)
    end

    private

    def release_current_assignment!(entry)
      assignment = entry.current_seating_assignment&.tap(&:lock!)
      return false if assignment.nil?

      assignment.seating_assignment_tables.where(released_at: nil).update_all(released_at: Time.current)
      assignment.update!(status: "released")
      true
    end
  end
end
