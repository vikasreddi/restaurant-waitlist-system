module Staff
  # Implements functional-spec.md §5 / api-spec.md "GET /staff/tables" — a
  # read-only view of every table's current operational state. Never
  # allocates, never releases, never creates/modifies a SeatingAssignment or
  # SeatingAssignmentTable row — Allocation::DecisionEngine/ReservationService/
  # Orchestrator are never called from this service.
  #
  # Table state is derived, never stored (INV-014, domain-model.md §2):
  # `free` (no current, non-released SeatingAssignmentTable claim), `held`
  # (claimed by a `pending` assignment — a `ready` group awaiting staff
  # confirmation), `occupied` (claimed by an `active` one — `seated`).
  # Released claim rows are excluded by construction (`released_at IS NULL`),
  # so historical assignments can never make a table appear occupied.
  #
  # Per functional-spec.md §5 ("Staff view queue / tables... also a DEC-015
  # lazy-expiration checkpoint, same as §2"), this read applies the same
  # shared Allocation::LazyExpiration module Staff::QueueViewService,
  # Guest::CurrentQueueStatusService, and Staff::ConfirmSeatingService already
  # use (a fourth call site — reused, not re-duplicated). As with Staff Queue,
  # a table freed by an expiration this read triggers is deliberately NOT
  # passed to Allocation::Orchestrator — this phase's own governing prompt §8
  # is unconditional ("Do not trigger the allocation orchestrator from this
  # read unless the specification explicitly requires it"), the same
  # precedent already established for Staff Queue and POST /staff/seat (see
  # agent-decisions.md Session 18/22).
  class TableViewService
    TableState = Struct.new(
      :table_id, :capacity, :status, :current_queue_entry_id, :seating_assignment_id, keyword_init: true
    )
    Result = Struct.new(:tables, keyword_init: true)

    def self.call
      new.call
    end

    def call
      QueueEntry.transaction do
        QueueEntry.where(status: "ready").lock.each do |entry|
          Allocation::LazyExpiration.expire_if_overdue!(entry)
        end
      end

      current_claims = SeatingAssignmentTable
        .where(released_at: nil)
        .includes(:seating_assignment)
        .index_by(&:table_id)

      Result.new(tables: Table.order(:id).map { |table| table_state(table, current_claims[table.id]) })
    end

    private

    def table_state(table, claim)
      return TableState.new(table_id: table.id, capacity: table.capacity, status: "free") if claim.nil?

      assignment = claim.seating_assignment
      TableState.new(
        table_id: table.id,
        capacity: table.capacity,
        status: assignment.status == "active" ? "occupied" : "held",
        current_queue_entry_id: assignment.queue_entry_id,
        seating_assignment_id: assignment.id
      )
    end
  end
end
