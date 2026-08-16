require "test_helper"

module Staff
  class SeatControllerTest < ActionDispatch::IntegrationTest
    def build_ready_entry(code: SecureRandom.hex(4))
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: code)
      table = Table.create!(name: "SC-#{SecureRandom.hex(4)}", capacity: 2)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      [entry, assignment, table]
    end

    def post_seat(code)
      post "/staff/seat", params: { seating_code: code }, as: :json
    end

    test "a valid seating code returns 200 with entry_id, status seated, and table_ids" do
      entry, _assignment, table = build_ready_entry(code: "HTTP001")

      post_seat("HTTP001")

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal entry.id, body["entry_id"]
      assert_equal "seated", body["status"]
      assert_equal [table.id], body["table_ids"]
    end

    test "an unknown seating code returns 404" do
      post_seat("MISSING")

      assert_response :not_found
      body = JSON.parse(response.body)
      assert_equal "not_found", body["error"]["type"]
    end

    test "confirming an already-seated code returns 409 conflict" do
      build_ready_entry(code: "HTTP002")
      post_seat("HTTP002")
      assert_response :ok

      post_seat("HTTP002")

      assert_response :conflict
      body = JSON.parse(response.body)
      assert_equal "conflict", body["error"]["type"]
    end

    test "confirming a no_show code returns 409 conflict, not 404" do
      entry, assignment, = build_ready_entry(code: "HTTP003")
      assignment.seating_assignment_tables.update_all(released_at: Time.current)
      assignment.update!(status: "released")
      entry.update!(status: "no_show", no_show_at: Time.current)

      post_seat("HTTP003")

      assert_response :conflict
    end

    test "repeated confirmation via HTTP does not change the database state further" do
      entry, assignment, = build_ready_entry(code: "HTTP004")
      post_seat("HTTP004")

      post_seat("HTTP004")
      post_seat("HTTP004")

      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id).count
      assert_equal "seated", entry.reload.status
      assert_equal "active", assignment.reload.status
    end

    test "the guest current-status endpoint reflects seated after staff confirmation" do
      entry, = build_ready_entry(code: "HTTP005")

      post_seat("HTTP005")
      assert_response :ok

      get "/guest/queue-entries/current", headers: { "Authorization" => "Bearer #{entry.active_visit_token}" }

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "seated", body["status"]
      assert_not body.key?("position")
      assert_not body.key?("entry_id")
    end

    test "guest current-status read after confirmation does not allocate another table or create another assignment" do
      entry, = build_ready_entry(code: "HTTP006")
      other_waiting = QueueEntry.create!(group_size: 2, phone_number: "555-0300", idempotency_key: SecureRandom.uuid)
      Table.create!(name: "SC-EXTRA-#{SecureRandom.hex(4)}", capacity: 2)

      post_seat("HTTP006")
      get "/guest/queue-entries/current", headers: { "Authorization" => "Bearer #{entry.active_visit_token}" }

      assert_equal "waiting", other_waiting.reload.status
      assert_equal 1, SeatingAssignment.count
    end
  end
end
