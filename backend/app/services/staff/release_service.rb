module Staff
  # Implements functional-spec.md §7 / api-spec.md "POST /staff/seating-
  # assignments/release". Identifies the seated group solely by `entry_id`
  # (DEC-014/INV-015) — never a raw `table_id`, which could reference only
  # part of a combined assignment. The server resolves the entry's current
  # SeatingAssignment internally and releases it atomically as one unit.
  #
  # Per domain-model.md §2's own explicit clarification ("A seated entry can
  # later be followed by table release, but release is a SeatingAssignment
  # transition, not a further QueueEntry state change — the entry stays
  # `seated` as the historical record; the *assignment* and its table(s)
  # transition instead"), QueueEntry.status is deliberately left unchanged by
  # this service — there is no "released" QueueEntry status in
  # QueueEntry::STATUSES, and inventing one would contradict this already-
  # documented design rather than follow it. This governing task's own
  # lifecycle diagram sketch ("SEATED -> Staff Release -> RELEASED") is read
  # as describing the *assignment's* resulting state (which already has a
  # `released` status value), not a new QueueEntry terminal state — api-
  # spec.md's own response shape for this endpoint (`{ entry_id,
  # table_ids_released }`, no `status` field) supports the same reading: if
  # the entry's own status were expected to change, the response would need
  # to report it, the way Leave/No-show's responses always do.
  #
  # Mirrors Guest::LeaveService's exact lock order (the entry, then its own
  # current_seating_assignment — a fixed single-path relationship) and
  # SeatingAssignment.released_at is deliberately never set here, matching
  # every other existing release path (Guest::LeaveService,
  # Allocation::LazyExpiration) — only `status: "released"` and each
  # SeatingAssignmentTable's own `released_at` are ever written; the column
  # on `seating_assignments` itself has never been used by any existing
  # service and this task does not introduce a new pattern for it.
  class ReleaseService
    Result = Struct.new(:outcome, :queue_entry, :table_ids_released, keyword_init: true)

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
      released_table_ids = []

      ActiveRecord::Base.transaction do
        entry = QueueEntry.lock.find_by(id: @entry_id)
        next if entry.nil?

        unless entry.status == "seated"
          invalid = true
          next
        end

        assignment = entry.current_seating_assignment&.tap(&:lock!)
        # current_seating_assignment only ever returns a pending/active
        # assignment (the association's own scope) — nil here means this
        # entry's seating was already released by an earlier call: a safe,
        # idempotent no-op (api-spec.md: "releasing an already-released
        # entry returns 200 with no state change, not an error").
        next if assignment.nil?

        released_table_ids = assignment.seating_assignment_tables.where(released_at: nil).pluck(:table_id)
        assignment.seating_assignment_tables.where(released_at: nil).update_all(released_at: Time.current)
        assignment.update!(status: "released")
      end

      return Result.new(outcome: :not_found) if entry.nil?
      return Result.new(outcome: :invalid_target, queue_entry: entry) if invalid

      Allocation::Orchestrator.call(now: Time.current) if released_table_ids.any?

      Result.new(outcome: :success, queue_entry: entry, table_ids_released: released_table_ids)
    end
  end
end
