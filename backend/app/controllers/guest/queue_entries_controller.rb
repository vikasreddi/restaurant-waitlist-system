module Guest
  # Thin controller: HTTP in, HTTP out. All idempotency/creation logic lives in
  # Guest::JoinService (functional-spec.md §1, api-spec.md).
  class QueueEntriesController < ApplicationController
    def create
      result = JoinService.call(
        group_size: join_params[:group_size],
        phone_number: join_params[:phone_number],
        idempotency_key: join_params[:idempotency_key]
      )

      case result.outcome
      when :created
        render json: entry_json(result.queue_entry), status: :created
      when :idempotent_replay
        render json: entry_json(result.queue_entry), status: :ok
      when :conflict
        render json: error_json(
          "conflict",
          "This idempotency key was already used for a different request."
        ), status: :conflict
      when :validation_error
        render json: error_json(
          "validation_error",
          "Invalid join request.",
          result.errors.to_hash(true)
        ), status: :unprocessable_content
      end
    end

    private

    def join_params
      params.permit(:group_size, :phone_number, :idempotency_key)
    end

    # No position (not implemented until the allocation service exists — this
    # phase's governing prompt §18 explicitly defers it), no table/seating
    # information (none exists yet), no internal fields beyond the entry's own
    # id (which is not usable to access anyone else's entry — lookups are only
    # ever by active_visit_token, never by entry_id).
    def entry_json(entry)
      { entry_id: entry.id, active_visit_token: entry.active_visit_token, status: entry.status }
    end

    def error_json(type, message, details = nil)
      { error: { type: type, message: message, details: details }.compact }
    end
  end
end
