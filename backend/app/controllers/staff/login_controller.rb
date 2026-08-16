module Staff
  # POST /staff/login (functional-spec.md §4, api-spec.md). Public endpoint —
  # deliberately does NOT inherit Staff::BaseController (that would require
  # being authenticated in order to log in).
  class LoginController < ApplicationController
    def create
      result = LoginService.call(email: params[:email], password: params[:password])

      if result.outcome == :success
        render json: { token: result.token }, status: :ok
      else
        render json: { error: { type: "unauthorized", message: "Invalid email or password." } },
          status: :unauthorized
      end
    end
  end
end
