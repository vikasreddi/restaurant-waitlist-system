module Staff
  # Thin controller: HTTP in, HTTP out. All lookup/locking/transition logic
  # lives in Staff::NoShowService (api-spec.md "POST /staff/queue/no-show").
  class NoShowController < Staff::BaseController
    def create
      result = NoShowService.call(entry_id: params[:entry_id])

      case result.outcome
      when :success
        render json: { entry_id: result.queue_entry.id, status: "no_show" }, status: :ok
      when :not_found
        render json: error_json("not_found", "Unknown queue entry."), status: :not_found
      when :invalid_target
        render json: error_json(
          "conflict",
          "This queue entry cannot be marked no-show from its current state."
        ), status: :conflict
      end
    end

    private

    def error_json(type, message)
      { error: { type: type, message: message } }
    end
  end
end
