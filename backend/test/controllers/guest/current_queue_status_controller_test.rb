require "test_helper"

module Guest
  class CurrentQueueStatusControllerTest < ActionDispatch::IntegrationTest
    # DEC-011 (Phase 5B.12): group_size 2 must be seatable by some valid
    # configuration, or the join helpers below would be rejected before
    # ever reaching the behavior under test. Claimed (non-free) so it
    # doesn't turn any of these entries synchronously `ready`.
    setup do
      table = Table.create!(name: "CQ-#{SecureRandom.hex(4)}", capacity: 10)
      claimer = QueueEntry.create!(group_size: 2, phone_number: "555-0199", idempotency_key: SecureRandom.uuid)
      claimer.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: claimer, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
    end

    def get_current(token)
      headers = token ? { "Authorization" => "Bearer #{token}" } : {}
      get "/guest/queue-entries/current", headers: headers, as: :json
    end

    def create_waiting_entry
      body = { group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid }
      post "/guest/queue-entries", params: body, as: :json
      JSON.parse(response.body)
    end

    test "a valid token for a waiting entry returns 200 with status and position" do
      joined = create_waiting_entry

      get_current(joined["active_visit_token"])

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal joined["entry_id"], body["entry_id"]
      assert_equal "waiting", body["status"]
      assert_equal 1, body["position"]
    end

    test "no Authorization header returns 404, not a server error" do
      get_current(nil)
      assert_response :not_found
      assert_equal "not_found", JSON.parse(response.body)["error"]["type"]
    end

    test "an unknown token returns 404" do
      get_current(SecureRandom.urlsafe_base64(32))
      assert_response :not_found
    end

    test "one guest cannot retrieve another guest's visit" do
      mine = create_waiting_entry
      create_waiting_entry # another guest, different token

      get_current(mine["active_visit_token"])

      assert_response :ok
      assert_equal mine["entry_id"], JSON.parse(response.body)["entry_id"]
    end

    test "a ready entry returns status ready and a seating_code, no position field" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      table = Table.create!(name: "TEST-#{SecureRandom.hex(4)}", capacity: 2)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: "ABCD")
      assignment = SeatingAssignment.create!(queue_entry: entry, expires_at: 10.minutes.from_now)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      get_current(entry.active_visit_token)

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "ready", body["status"]
      assert_equal "ABCD", body["seating_code"]
      assert_not body.key?("position")
    end

    test "a seated entry returns only its status" do
      entry = QueueEntry.create!(
        group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid,
        status: "seated", seated_at: Time.current
      )

      get_current(entry.active_visit_token)

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "seated", body["status"]
      assert_not body.key?("entry_id")
      assert_not body.key?("position")
    end

    test "no side effects from a read: SeatingAssignment/SeatingAssignmentTable counts are unchanged" do
      joined = create_waiting_entry

      assert_no_difference [ "SeatingAssignment.count", "SeatingAssignmentTable.count" ] do
        get_current(joined["active_visit_token"])
        get_current(joined["active_visit_token"])
      end
    end
  end
end
