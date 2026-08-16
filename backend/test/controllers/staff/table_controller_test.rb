require "test_helper"

module Staff
  class TableControllerTest < ActionDispatch::IntegrationTest
    def staff_token
      staff = StaffUser.find_by(email: "table-test-staff@example.com") ||
        StaffUser.create!(email: "table-test-staff@example.com", password: "irrelevant-test-password")
      Staff::SessionToken.generate(staff)
    end

    def get_tables(authenticated: true)
      headers = authenticated ? { "Authorization" => "Bearer #{staff_token}" } : {}
      get "/staff/tables", headers: headers, as: :json
    end

    test "an unauthenticated request is rejected with 401" do
      get_tables(authenticated: false)
      assert_response :unauthorized
    end

    test "an invalid bearer token is rejected with 401" do
      get "/staff/tables", headers: { "Authorization" => "Bearer not-a-real-token" }, as: :json
      assert_response :unauthorized
    end

    test "a guest active_visit_token cannot authenticate as staff" do
      post "/guest/queue-entries", params: {
        group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid
      }, as: :json
      guest_token = JSON.parse(response.body)["active_visit_token"]

      get "/staff/tables", headers: { "Authorization" => "Bearer #{guest_token}" }, as: :json
      assert_response :unauthorized
    end

    test "an authenticated request returns 200 with every seeded table" do
      get_tables

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal Table.count, body["tables"].size
    end

    test "response data matches real PostgreSQL state, not hardcoded values" do
      table = Table.create!(name: "TC-#{SecureRandom.hex(4)}", capacity: 6)

      get_tables

      body = JSON.parse(response.body)
      entry = body["tables"].find { |t| t["table_id"] == table.id }
      assert_equal 6, entry["capacity"]
      assert_equal "free", entry["status"]
      refute entry.key?("current_queue_entry_id")
      refute entry.key?("seating_assignment_id")
    end

    test "a held table exposes current_queue_entry_id and seating_assignment_id" do
      table = Table.create!(name: "TC-#{SecureRandom.hex(4)}", capacity: 2)
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      get_tables

      body = JSON.parse(response.body)
      held = body["tables"].find { |t| t["table_id"] == table.id }
      assert_equal "held", held["status"]
      assert_equal entry.id, held["current_queue_entry_id"]
      assert_equal assignment.id, held["seating_assignment_id"]
    end

    test "no tokens, passwords, or secrets ever appear in the response" do
      get_tables
      refute response.body.include?(staff_token)
    end
  end
end
