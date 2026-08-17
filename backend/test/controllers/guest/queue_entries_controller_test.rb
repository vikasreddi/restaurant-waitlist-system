require "test_helper"

module Guest
  class QueueEntriesControllerTest < ActionDispatch::IntegrationTest
    # DEC-011 (Phase 5B.12): every group_size used below (max 6) must be
    # seatable by some valid configuration. Claimed (non-free) so the
    # allocation-boundary assertions below are unaffected.
    setup do
      table = Table.create!(name: "QC-#{SecureRandom.hex(4)}", capacity: 10)
      claimer = QueueEntry.create!(group_size: 2, phone_number: "555-0199", idempotency_key: SecureRandom.uuid)
      claimer.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: claimer, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
    end

    def post_join(overrides = {})
      body = { group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid }.merge(overrides)
      post "/guest/queue-entries", params: body, as: :json
    end

    test "a valid join returns 201 with the entry, token, and waiting status" do
      post_join

      assert_response :created
      body = JSON.parse(response.body)
      assert body["entry_id"].present?
      assert body["active_visit_token"].present?
      assert_equal "waiting", body["status"]
    end

    test "the 201 response does not include position, seating code, or table information" do
      post_join

      body = JSON.parse(response.body)
      assert_not body.key?("position")
      assert_not body.key?("seating_code")
      assert_not body.key?("table_id")
    end

    test "invalid group_size returns 422 with a validation_error" do
      post_join(group_size: 0)

      assert_response :unprocessable_content
      body = JSON.parse(response.body)
      assert_equal "validation_error", body["error"]["type"]
    end

    test "missing phone_number returns 422" do
      post_join(phone_number: "")
      assert_response :unprocessable_content
    end

    test "missing idempotency_key returns 422" do
      post_join(idempotency_key: "")
      assert_response :unprocessable_content
    end

    test "a retried join with the same idempotency_key returns 200 with the same token, no duplicate" do
      key = SecureRandom.uuid
      post_join(idempotency_key: key)
      first_token = JSON.parse(response.body)["active_visit_token"]

      post_join(idempotency_key: key)

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal first_token, body["active_visit_token"]
      assert_equal 1, QueueEntry.where(idempotency_key: key).count
    end

    test "a conflicting retry (same key, different data) returns 409 and does not mutate the original" do
      key = SecureRandom.uuid
      post_join(group_size: 2, phone_number: "111-1111", idempotency_key: key)

      post_join(group_size: 6, phone_number: "222-2222", idempotency_key: key)

      assert_response :conflict
      body = JSON.parse(response.body)
      assert_equal "conflict", body["error"]["type"]
      assert_equal 2, QueueEntry.find_by!(idempotency_key: key).group_size
    end

    test "a successful join creates no SeatingAssignment" do
      post_join
      entry_id = JSON.parse(response.body)["entry_id"]

      assert_equal 0, QueueEntry.find(entry_id).seating_assignments.count
    end

    # --- DEC-011: oversized-group rejection over real HTTP (Phase 5B.12) ---
    # This file's own setup claims a capacity-10 table, so the maximum valid
    # group size is exactly 10 for every test below.

    test "a group size beyond the maximum valid configuration returns 422 validation_error" do
      post_join(group_size: 11)

      assert_response :unprocessable_content
      body = JSON.parse(response.body)
      assert_equal "validation_error", body["error"]["type"]
      assert body["error"]["message"].present?
    end

    test "an impossible group size creates no QueueEntry" do
      assert_no_difference "QueueEntry.count" do
        post_join(group_size: 11)
      end
    end

    test "a much larger impossible group size is also rejected with no QueueEntry created" do
      assert_no_difference "QueueEntry.count" do
        post_join(group_size: 500)
      end
      assert_response :unprocessable_content
    end
  end
end
