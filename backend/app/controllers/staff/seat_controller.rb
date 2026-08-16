module Staff
  # Thin controller: HTTP in, HTTP out. All lookup/locking/validation/
  # state-transition logic lives in Staff::ConfirmSeatingService
  # (api-spec.md "POST /staff/seat").
  #
  # Now requires staff authentication (Staff::BaseController's before_action)
  # — the gap noted in Session 18 ("deferred to whichever future phase
  # builds POST /staff/login") is closed by this phase, which is that phase.
  # See 06-ai-working-record/agent-decisions.md Session 21 for the reasoning.
  class SeatController < Staff::BaseController
    def create
      result = ConfirmSeatingService.call(seating_code: params[:seating_code])

      case result.outcome
      when :success
        render json: seated_json(result), status: :ok
      when :not_found
        render json: error_json("not_found", "Unknown or invalid seating code."), status: :not_found
      when :already_confirmed
        render json: error_json("conflict", "This reservation has already been confirmed."), status: :conflict
      when :conflict
        render json: error_json(
          "conflict",
          "This reservation is no longer valid — it may have expired or been released."
        ), status: :conflict
      end
    end

    private

    def seated_json(result)
      {
        entry_id: result.queue_entry.id,
        status: "seated",
        table_ids: result.seating_assignment.seating_assignment_tables.map(&:table_id)
      }
    end

    def error_json(type, message)
      { error: { type: type, message: message } }
    end
  end
end
