require "test_helper"

module Staff
  class LoginServiceTest < ActiveSupport::TestCase
    setup do
      @staff = StaffUser.create!(email: "login-test@example.com", password: "correct-horse-battery")
    end

    def call(email, password)
      LoginService.call(email: email, password: password)
    end

    # --- Test 1: valid login succeeds ---

    test "valid credentials succeed and return a token" do
      result = call(@staff.email, "correct-horse-battery")

      assert_equal :success, result.outcome
      assert_equal @staff.id, result.staff_user.id
      assert result.token.present?
    end

    # --- Test 5: password/hash never returned ---

    test "the result never exposes the password or password_digest" do
      result = call(@staff.email, "correct-horse-battery")

      refute_respond_to result, :password
      assert_not result.token.include?(@staff.password_digest)
    end

    # --- Test 6: authenticated identity represented correctly ---

    test "the issued token verifies back to the correct staff_user id" do
      result = call(@staff.email, "correct-horse-battery")

      assert_equal @staff.id, SessionToken.verify(result.token)
    end

    # --- Test 2: invalid credentials fail ---

    test "the wrong password fails" do
      result = call(@staff.email, "wrong-password")
      assert_equal :invalid_credentials, result.outcome
      assert_nil result.token
    end

    # --- Test 4: unknown staff user fails ---

    test "an unknown email fails, identically to a wrong password (no user enumeration)" do
      unknown_result = call("nobody@example.com", "whatever")
      wrong_password_result = call(@staff.email, "wrong-password")

      assert_equal :invalid_credentials, unknown_result.outcome
      assert_equal wrong_password_result.outcome, unknown_result.outcome
    end

    # --- Test 3: missing credentials fail ---

    test "missing email or password fails" do
      assert_equal :invalid_credentials, call(nil, "correct-horse-battery").outcome
      assert_equal :invalid_credentials, call(@staff.email, nil).outcome
      assert_equal :invalid_credentials, call("", "").outcome
    end

    # --- Test 7: repeated valid login behaves correctly ---

    test "repeated valid logins each succeed and issue independently-valid tokens" do
      first = call(@staff.email, "correct-horse-battery")
      second = call(@staff.email, "correct-horse-battery")

      assert_equal :success, first.outcome
      assert_equal :success, second.outcome
      assert_equal @staff.id, SessionToken.verify(first.token)
      assert_equal @staff.id, SessionToken.verify(second.token)
    end
  end
end
