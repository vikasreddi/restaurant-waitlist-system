module Staff
  # Thin controller: HTTP in, HTTP out. All lookup/locking/validation/
  # state-transition logic lives in Staff::ConfirmSeatingService
  # (api-spec.md "POST /staff/seat").
  #
  # No staff authentication: no session/login mechanism exists anywhere in
  # this codebase yet (StaffUser has no login endpoint, deferred every phase
  # since 5B.2) — this is a known, explicitly-documented gap for this phase,
  # not a silently-introduced one. See CLAUDE.md/session-log.md Session 18.
  class SeatController < ApplicationController
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
