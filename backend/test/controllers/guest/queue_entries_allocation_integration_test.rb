require "test_helper"

module Guest
  # Phase 5B.5.4 — verifies the Guest Join HTTP endpoint's actual behavior
  # now that a successful join can trigger Allocation::Orchestrator, without
  # changing any existing idempotency/validation contract from Phase 5B.3.
  class QueueEntriesAllocationIntegrationTest < ActionDispatch::IntegrationTest
    def post_join(overrides = {})
      body = { group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid }.merge(overrides)
      post "/guest/queue-entries", params: body, as: :json
    end

    # DEC-011 (Phase 5B.12): "no compatible table right now" (this test) is
    # deliberately distinct from "no configuration could EVER seat this
    # group" — the former stays a normal 201/waiting join; only the latter
    # is rejected (see queue_entries_controller_group_size_test.rb). A
    # capacity-matching but currently-claimed (non-free) table is used here
    # so the join is genuinely valid, just not servable this instant.
    test "join with no currently-available compatible table returns 201 and the entry remains waiting" do
      table = Table.create!(name: "AJ-0", capacity: 2)
      claimer = QueueEntry.create!(group_size: 2, phone_number: "555-0199", idempotency_key: SecureRandom.uuid)
      claimer.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: claimer, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      post_join

      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "waiting", body["status"]
    end

    test "join with a compatible free table returns 201 and the entry synchronously becomes ready" do
      table = Table.create!(name: "AJ-1", capacity: 2)

      post_join

      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "ready", body["status"]

      entry = QueueEntry.find(body["entry_id"])
      assignment = SeatingAssignment.find_by(queue_entry_id: entry.id)
      assert assignment.present?
      assert_equal "pending", assignment.status
      assert_equal [table.id], assignment.seating_assignment_tables.map(&:table_id)
      assert entry.seating_code.present?
    end

    test "the 201 response shape is unchanged: entry_id, active_visit_token, status only" do
      Table.create!(name: "AJ-2", capacity: 2)

      post_join

      body = JSON.parse(response.body)
      assert_equal %w[active_visit_token entry_id status].sort, body.keys.sort
    end

    test "an idempotent retry does not create a second QueueEntry or a second allocation" do
      Table.create!(name: "AJ-3", capacity: 2)
      key = SecureRandom.uuid

      post_join(idempotency_key: key)
      first_body = JSON.parse(response.body)
      assert_equal "ready", first_body["status"]

      post_join(idempotency_key: key)

      assert_response :ok
      second_body = JSON.parse(response.body)
      assert_equal first_body["entry_id"], second_body["entry_id"]
      assert_equal first_body["active_visit_token"], second_body["active_visit_token"]
      assert_equal "ready", second_body["status"] # still ready — not re-processed, not reverted

      assert_equal 1, QueueEntry.where(active_visit_token: first_body["active_visit_token"]).count
      assert_equal 1, SeatingAssignment.count
    end

    test "multiple genuinely new joins never produce duplicate assignments for the same table" do
      Table.create!(name: "AJ-4", capacity: 2)

      post_join(phone_number: "555-1001", idempotency_key: SecureRandom.uuid)
      first_entry_id = JSON.parse(response.body)["entry_id"]

      post_join(phone_number: "555-1002", idempotency_key: SecureRandom.uuid)
      second_body = JSON.parse(response.body)

      # Only one table existed — the second group's join must not have
      # somehow double-claimed it or produced a second pending assignment.
      assert_equal "waiting", second_body["status"]
      assert_equal 1, SeatingAssignment.where(status: "pending").count
      assert_equal "ready", QueueEntry.find(first_entry_id).status
    end
  end
end
