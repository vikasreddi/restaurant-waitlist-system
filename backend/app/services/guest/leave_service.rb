module Guest
  # Implements functional-spec.md §3 / api-spec.md "POST /guest/queue-entries/
  # current/leave". Identifies the visit solely via active_visit_token (never
  # phone number, database id, or idempotency key — same rule as
  # CurrentQueueStatusService).
  #
  # Idempotent per functional-spec.md §3, more precisely than api-spec.md's
  # shorter phrasing: leaving an already-terminal entry — `left`, *or any
  # other terminal state* (`seated`, `no_show`) — is a safe no-op, never an
  # error, and never force-overwrites the entry's real status to "left". Only
  # `waiting`/`ready` entries actually transition.
  #
  # For a `ready` entry, release is atomic with the `left` transition — the
  # SeatingAssignment (`pending`) is released and its SeatingAssignmentTable
  # row(s) get released_at set (never deleted), in the same transaction as
  # QueueEntry -> left — mirroring Guest::CurrentQueueStatusService's DEC-015
  # release pattern and Staff::ConfirmSeatingService's lock ordering (the
  # entry, then its own assignment — a fixed, single-path relationship, no
  # "sort by id" question).
  #
  # Allocation::Orchestrator runs strictly AFTER this transaction commits,
  # only when a table was actually released (a `waiting` leave never touches
  # any table, so triggering allocation for it would only ever produce a
  # no-op `:no_candidate` — this mirrors the lazy no-show trigger's own
  # conditional pattern rather than calling the orchestrator unconditionally).
  class LeaveService
    Result = Struct.new(:outcome, :queue_entry, keyword_init: true)

    def self.call(active_visit_token:)
      new(active_visit_token: active_visit_token).call
    end

    def initialize(active_visit_token:)
      @active_visit_token = active_visit_token
    end

    def call
      return Result.new(outcome: :not_found) if @active_visit_token.blank?

      entry = nil
      released = false

      ActiveRecord::Base.transaction do
        entry = QueueEntry.lock.find_by(active_visit_token: @active_visit_token)
        next if entry.nil?

        if entry.status.in?(%w[waiting ready])
          released = release_current_assignment!(entry) if entry.status == "ready"
          entry.update!(status: "left", left_at: Time.current)
        end
        # else: already terminal (left/seated/no_show) — safe no-op, no change.
      end

      return Result.new(outcome: :not_found) if entry.nil?

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
