require "test_helper"

module Staff
  class QueueControllerTest < ActionDispatch::IntegrationTest
    def staff_token
      staff = StaffUser.find_by(email: "queue-test-staff@example.com") ||
        StaffUser.create!(email: "queue-test-staff@example.com", password: "irrelevant-test-password")
      Staff::SessionToken.generate(staff)
    end

    def get_queue(authenticated: true)
      headers = authenticated ? { "Authorization" => "Bearer #{staff_token}" } : {}
      get "/staff/queue", headers: headers, as: :json
    end

    def create_waiting(joined_at: 5.minutes.ago)
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(joined_at: joined_at)
      entry
    end

    def create_ready(code:)
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: code)
      table = Table.create!(name: "QC-#{SecureRandom.hex(4)}", capacity: 2)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      entry
    end

    test "an unauthenticated request is rejected with 401" do
      get_queue(authenticated: false)
      assert_response :unauthorized
    end

    test "an invalid bearer token is rejected with 401" do
      get "/staff/queue", headers: { "Authorization" => "Bearer not-a-real-token" }, as: :json
      assert_response :unauthorized
    end

    test "a guest active_visit_token cannot authenticate as staff" do
      post "/guest/queue-entries", params: {
        group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid
      }, as: :json
      guest_token = JSON.parse(response.body)["active_visit_token"]

      get "/staff/queue", headers: { "Authorization" => "Bearer #{guest_token}" }, as: :json
      assert_response :unauthorized
    end

    test "an empty queue returns 200 with empty lists" do
      get_queue
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal [], body["waiting"]
      assert_equal [], body["ready"]
    end

    test "a real waiting entry appears with the specified fields" do
      entry = create_waiting

      get_queue

      assert_response :ok
      body = JSON.parse(response.body)
      waiting = body["waiting"].first
      assert_equal entry.id, waiting["entry_id"]
      assert_equal 2, waiting["group_size"]
      assert waiting.key?("joined_at")
      assert_equal 1, waiting["position"]
      assert_equal false, waiting["is_starvation_protected"]
    end

    test "a real ready entry appears with its seating_code and no position field" do
      entry = create_ready(code: "QC0001")

      get_queue

      assert_response :ok
      body = JSON.parse(response.body)
      ready = body["ready"].first
      assert_equal entry.id, ready["entry_id"]
      assert_equal "QC0001", ready["seating_code"]
      refute ready.key?("position")
    end

    test "mixed waiting and ready entries both appear, correctly separated" do
      waiting_entry = create_waiting
      ready_entry = create_ready(code: "QC0002")

      get_queue

      body = JSON.parse(response.body)
      assert_equal [ waiting_entry.id ], body["waiting"].map { |e| e["entry_id"] }
      assert_equal [ ready_entry.id ], body["ready"].map { |e| e["entry_id"] }
    end

    test "response data matches real PostgreSQL state, not hardcoded values" do
      entry = create_waiting(joined_at: 15.minutes.ago)

      get_queue
      body = JSON.parse(response.body)

      db_entry = QueueEntry.find(entry.id)
      assert_equal db_entry.group_size, body["waiting"].first["group_size"]
    end
  end
end
