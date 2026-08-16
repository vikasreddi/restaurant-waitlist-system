module Staff
  # Thin controller: HTTP in, HTTP out. All read/derivation/expiration logic
  # lives in Staff::TableViewService (api-spec.md "GET /staff/tables").
  class TableController < Staff::BaseController
    def index
      result = TableViewService.call

      render json: { tables: result.tables.map { |table| table_json(table) } }, status: :ok
    end

    private

    # current_queue_entry_id / seating_assignment_id are only present when the
    # table is held/occupied (api-spec.md: "if held/occupied") — omitted
    # rather than null for a free table, matching this project's existing
    # per-status conditional-field convention (e.g. Guest::
    # QueueEntriesController#current_status_json).
    def table_json(table)
      json = { table_id: table.table_id, capacity: table.capacity, status: table.status }
      if table.status != "free"
        json[:current_queue_entry_id] = table.current_queue_entry_id
        json[:seating_assignment_id] = table.seating_assignment_id
      end
      json
    end
  end
end
