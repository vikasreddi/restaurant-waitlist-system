require "test_helper"

module Staff
  class ReleaseControllerTest < ActionDispatch::IntegrationTest
    def staff_token
      staff = StaffUser.find_by(email: "release-test-staff@example.com") ||
        StaffUser.create!(email: "release-test-staff@example.com", password: "irrelevant-test-password")
      Staff::SessionToken.generate(staff)
    end

    def build_seated_entry
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      table = Table.create!(name: "RC-#{SecureRandom.hex(4)}", capacity: 2)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      assignment.update!(status: "active", activated_at: Time.current)
      entry.update!(status: "seated", seated_at: Time.current)
      [entry, table]
    end

    def post_release(entry_id, authenticated: true)
      headers = authenticated ? { "Authorization" => "Bearer #{staff_token}" } : {}
      post "/staff/seating-assignments/release", params: { entry_id: entry_id }, headers: headers, as: :json
    end

    test "an unauthenticated request is rejected with 401" do
      entry, = build_seated_entry
      post_release(entry.id, authenticated: false)
      assert_response :unauthorized
    end

    test "a guest active_visit_token cannot authenticate as staff" do
      post "/guest/queue-entries", params: {
        group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid
      }, as: :json
      guest_token = JSON.parse(response.body)["active_visit_token"]
      entry, = build_seated_entry

      post "/staff/seating-assignments/release", params: { entry_id: entry.id },
        headers: { "Authorization" => "Bearer #{guest_token}" }, as: :json
      assert_response :unauthorized
    end

    test "a real seated entry releases via HTTP and its table becomes free" do
      entry, table = build_seated_entry

      post_release(entry.id)

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal entry.id, body["entry_id"]
      assert_equal [ table.id ], body["table_ids_released"]
      assert table.reload.free?
    end

    test "releasing an unknown entry_id returns 404" do
      post_release(-1)
      assert_response :not_found
    end

    test "releasing a non-seated entry returns 409 conflict" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      post_release(entry.id)
      assert_response :conflict
    end
  end
end
