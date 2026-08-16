require "test_helper"

module Staff
  class LoginControllerTest < ActionDispatch::IntegrationTest
    setup do
      @staff = StaffUser.create!(email: "ctl-login@example.com", password: "correct-horse-battery")
    end

    def post_login(email, password)
      post "/staff/login", params: { email: email, password: password }, as: :json
    end

    test "valid credentials return 200 with a token, never a password/hash" do
      post_login(@staff.email, "correct-horse-battery")

      assert_response :ok
      body = JSON.parse(response.body)
      assert body["token"].present?
      assert_not body.key?("password")
      assert_not body.key?("password_digest")
      assert_not response.body.include?(@staff.password_digest)
    end

    test "invalid credentials return 401 with a generic error" do
      post_login(@staff.email, "wrong-password")

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_equal "unauthorized", body["error"]["type"]
    end

    test "an unknown email returns the same 401 shape as a wrong password (no user enumeration)" do
      post_login("nobody@example.com", "whatever")

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_equal "unauthorized", body["error"]["type"]
    end

    test "missing credentials return 401" do
      post_login(nil, nil)
      assert_response :unauthorized
    end

    test "the issued token successfully authenticates POST /staff/seat" do
      post_login(@staff.email, "correct-horse-battery")
      token = JSON.parse(response.body)["token"]

      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: "LOGIN01")
      table = Table.create!(name: "LC-#{SecureRandom.hex(4)}", capacity: 2)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      post "/staff/seat", params: { seating_code: "LOGIN01" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

      assert_response :ok
    end

    test "a guest active_visit_token cannot log in as staff (different endpoint/credential shape entirely)" do
      post "/guest/queue-entries", params: {
        group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid
      }, as: :json
      guest_token = JSON.parse(response.body)["active_visit_token"]

      # There is no code path by which a guest token could even be submitted
      # to /staff/login meaningfully (it's not an email/password pair) — the
      # real isolation guarantee is tested at /staff/seat directly (see
      # seat_controller_test.rb), where a guest token is explicitly proven
      # unable to authenticate. This test only confirms the login endpoint
      # itself never accidentally accepts a bare token as a credential.
      post_login(guest_token, guest_token)

      assert_response :unauthorized
    end
  end
end
