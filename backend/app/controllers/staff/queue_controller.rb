module Staff
  # Thin controller: HTTP in, HTTP out. All read/expiration logic lives in
  # Staff::QueueViewService (api-spec.md "GET /staff/queue").
  class QueueController < Staff::BaseController
    def index
      result = QueueViewService.call

      render json: {
        waiting: result.waiting.map { |entry| waiting_json(entry) },
        ready: result.ready.map { |entry| ready_json(entry) }
      }, status: :ok
    end

    private

    def waiting_json(entry)
      {
        entry_id: entry.entry_id,
        group_size: entry.group_size,
        joined_at: entry.joined_at.iso8601,
        position: entry.position,
        is_starvation_protected: entry.is_starvation_protected
      }
    end

    def ready_json(entry)
      {
        entry_id: entry.entry_id,
        group_size: entry.group_size,
        ready_at: entry.ready_at.iso8601,
        seating_code: entry.seating_code
      }
    end
  end
end
