module Staff
  # Implements functional-spec.md §4 / api-spec.md "POST /staff/login" —
  # stub-strength credential check (REQ-STAFF-001), issues a Staff::
  # SessionToken. A single generic failure outcome for every credential
  # problem (unknown email, wrong password, missing email/password) — never
  # distinguishes "unknown user" from "wrong password" in the outcome or any
  # message built from it (api-spec.md: "no user enumeration").
  class LoginService
    Result = Struct.new(:outcome, :staff_user, :token, keyword_init: true)

    def self.call(email:, password:)
      new(email: email, password: password).call
    end

    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def call
      return Result.new(outcome: :invalid_credentials) if @email.blank? || @password.blank?

      staff_user = StaffUser.find_by(email: @email)
      # Guard staff_user.nil? explicitly (calling #authenticate on nil would
      # raise, not return false) — but both branches converge on the exact
      # same :invalid_credentials outcome regardless, which is the actual
      # "no user enumeration" point: an unknown email and a known email with
      # the wrong password are indistinguishable from the caller's side.
      return Result.new(outcome: :invalid_credentials) if staff_user.nil? || !staff_user.authenticate(@password)

      Result.new(outcome: :success, staff_user: staff_user, token: SessionToken.generate(staff_user))
    end
  end
end
