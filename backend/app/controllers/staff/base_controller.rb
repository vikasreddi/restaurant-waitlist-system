module Staff
  # Shared authentication boundary for staff endpoints (this phase's own
  # governing prompt §5: "establish the minimum authentication boundary
  # needed by subsequent Staff P0 APIs"). Not itself a new endpoint —
  # Staff::SeatController inherits this instead of ApplicationController.
  class BaseController < ApplicationController
    before_action :authenticate_staff!

    private

    def authenticate_staff!
      staff_user_id = SessionToken.verify(bearer_token)
      @current_staff_user = staff_user_id && StaffUser.find_by(id: staff_user_id)

      return if @current_staff_user

      render json: { error: { type: "unauthorized", message: "Staff authentication required." } },
        status: :unauthorized
    end

    def bearer_token
      header = request.headers["Authorization"].to_s
      match = header.match(/\ABearer\s+(.+)\z/i)
      match && match[1]
    end
  end
end
