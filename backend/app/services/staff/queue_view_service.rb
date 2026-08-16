module Staff
  # Implements functional-spec.md §5 / api-spec.md "GET /staff/queue" — a
  # read-only view of the current queue for staff. Never allocates, never
  # creates a SeatingAssignment/SeatingAssignmentTable row, never selects or
  # reserves a table — Allocation::DecisionEngine/ReservationService/
  # Orchestrator are never called from this service.
  #
  # Per functional-spec.md §5, this read is also one of DEC-015's lazy-
  # expiration checkpoints (via the shared Allocation::LazyExpiration module,
  # also used by Guest::CurrentQueueStatusService and
  # Staff::ConfirmSeatingService) — an overdue `ready` entry encountered here
  # is expired to `no_show` (and its table(s) released) before being excluded
  # from the `ready` list. Unlike Guest::CurrentQueueStatusService, the table
  # this frees is deliberately NOT passed to Allocation::Orchestrator — this
  # phase's own governing prompt §6 is unconditional ("A Staff Queue read
  # must not perform new allocation"), the same textual pattern
  # Staff::ConfirmSeatingService's own phase already established (see
  # agent-decisions.md Session 18) for the identical situation. The freed
  # table simply stays free until a future join or guest status read (an
  # already-approved allocation trigger) picks it up.
  #
  # `position` here is the same simple chronological rank
  # Guest::CurrentQueueStatusService already computes — not allocation
  # priority. `is_starvation_protected` is an informational flag derived from
  # the same threshold Allocation::DecisionEngine uses
  # (Allocation::Policy::STARVATION_THRESHOLD_SECONDS) — duplicated as a
  # two-line comparison against the existing shared constant, not a second
  # implementation of the allocation algorithm itself.
  class QueueViewService
    WaitingEntry = Struct.new(
      :entry_id, :group_size, :joined_at, :position, :is_starvation_protected, keyword_init: true
    )
    ReadyEntry = Struct.new(:entry_id, :group_size, :ready_at, :seating_code, keyword_init: true)
    Result = Struct.new(:waiting, :ready, keyword_init: true)

    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now:)
      @now = now
    end

    def call
      ready_entries = []

      QueueEntry.transaction do
        QueueEntry.where(status: "ready").lock.each do |entry|
          ready_entries << entry unless Allocation::LazyExpiration.expire_if_overdue!(entry)
        end
      end

      waiting_entries = QueueEntry.where(status: "waiting").order(:joined_at).to_a

      Result.new(
        waiting: waiting_entries.each_with_index.map { |entry, index| waiting_entry(entry, index) },
        ready: ready_entries.sort_by(&:ready_at).map { |entry| ready_entry(entry) }
      )
    end

    private

    def waiting_entry(entry, index)
      WaitingEntry.new(
        entry_id: entry.id,
        group_size: entry.group_size,
        joined_at: entry.joined_at,
        position: index + 1,
        is_starvation_protected: starvation_protected?(entry)
      )
    end

    def ready_entry(entry)
      ReadyEntry.new(
        entry_id: entry.id,
        group_size: entry.group_size,
        ready_at: entry.ready_at,
        seating_code: entry.seating_code
      )
    end

    def starvation_protected?(entry)
      (@now - entry.joined_at) >= Allocation::Policy::STARVATION_THRESHOLD_SECONDS
    end
  end
end
