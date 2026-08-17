require "test_helper"

module Staff
  class NoShowControllerTest < ActionDispatch::IntegrationTest
    def staff_token
      staff = StaffUser.find_by(email: "noshow-test-staff@example.com") ||
        StaffUser.create!(email: "noshow-test-staff@example.com", password: "irrelevant-test-password")
      Staff::SessionToken.generate(staff)
    end

    def post_no_show(entry_id, authenticated: true)
      headers = authenticated ? { "Authorization" => "Bearer #{staff_token}" } : {}
      post "/staff/queue/no-show", params: { entry_id: entry_id }, headers: headers, as: :json
    end

    test "an unauthenticated request is rejected with 401" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      post_no_show(entry.id, authenticated: false)
      assert_response :unauthorized
    end

    test "a guest active_visit_token cannot authenticate as staff" do
      post "/guest/queue-entries", params: {
        group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid
      }, as: :json
      guest_token = JSON.parse(response.body)["active_visit_token"]
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)

      post "/staff/queue/no-show", params: { entry_id: entry.id },
        headers: { "Authorization" => "Bearer #{guest_token}" }, as: :json
      assert_response :unauthorized
    end

    test "a real waiting entry is marked no_show via HTTP" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)

      post_no_show(entry.id)

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal entry.id, body["entry_id"]
      assert_equal "no_show", body["status"]
      assert_equal "no_show", entry.reload.status
    end

    test "a real ready entry is marked no_show and its table freed via HTTP" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      table = Table.create!(name: "NC-#{SecureRandom.hex(4)}", capacity: 2)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      post_no_show(entry.id)

      assert_response :ok
      assert table.reload.free?
    end

    test "marking an unknown entry_id no-show returns 404" do
      post_no_show(-1)
      assert_response :not_found
    end

    test "marking a seated entry no-show returns 409 conflict" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid,
        status: "seated", seated_at: Time.current)
      post_no_show(entry.id)
      assert_response :conflict
    end
  end
end
