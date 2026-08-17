require "test_helper"

module Guest
  class JoinServiceTest < ActiveSupport::TestCase
    # DEC-011 (Phase 5B.12): every group_size used by this file's tests (max
    # 6) must be seatable by SOME valid configuration, or the new too-large
    # check would reject them before ever reaching the behavior under test.
    # This table is immediately claimed (non-free) rather than left free, so
    # Allocation::Orchestrator still can never actually allocate it —
    # preserving every existing "stays waiting / no SeatingAssignment
    # created" assertion below exactly as before. Mirrors
    # allocation/configuration_generator_test.rb's own claim_table! helper.
    setup do
      table = Table.create!(name: "JS-#{SecureRandom.hex(4)}", capacity: 10)
      claimer = QueueEntry.create!(group_size: 2, phone_number: "555-0199", idempotency_key: SecureRandom.uuid)
      claimer.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: claimer, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
    end

    def call(overrides = {})
      defaults = { group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid }
      JoinService.call(**defaults.merge(overrides))
    end

    # --- Happy path ---

    test "a valid join creates a QueueEntry in waiting status" do
      result = call

      assert_equal :created, result.outcome
      assert result.queue_entry.persisted?
      assert_equal "waiting", result.queue_entry.status
    end

    test "a valid join generates and returns an active_visit_token" do
      result = call
      assert result.queue_entry.active_visit_token.present?
    end

    # --- Validation ---

    test "group_size of 0 is rejected" do
      result = call(group_size: 0)

      assert_equal :validation_error, result.outcome
      assert_includes result.errors[:group_size], "must be greater than 0"
    end

    test "negative group_size is rejected" do
      result = call(group_size: -1)
      assert_equal :validation_error, result.outcome
    end

    test "missing phone_number is rejected" do
      result = call(phone_number: nil)

      assert_equal :validation_error, result.outcome
      assert_includes result.errors[:phone_number], "can't be blank"
    end

    test "missing idempotency_key is rejected" do
      result = call(idempotency_key: nil)

      assert_equal :validation_error, result.outcome
      assert_includes result.errors[:idempotency_key], "can't be blank"
    end

    # --- Idempotency: same key twice ---

    test "a retried join with the same idempotency_key does not create a second QueueEntry" do
      key = SecureRandom.uuid
      first = call(idempotency_key: key)
      second = call(idempotency_key: key)

      assert_equal :idempotent_replay, second.outcome
      assert_equal first.queue_entry.id, second.queue_entry.id
      assert_equal 1, QueueEntry.where(idempotency_key: key).count
    end

    test "a retried join returns the SAME active_visit_token, not a new one" do
      key = SecureRandom.uuid
      first = call(idempotency_key: key)
      second = call(idempotency_key: key)

      assert_equal first.queue_entry.active_visit_token, second.queue_entry.active_visit_token
    end

    # --- Conflicting retry: same key, different data ---

    test "the same idempotency_key with a different group_size is a conflict, not a silent update" do
      key = SecureRandom.uuid
      original = call(group_size: 2, phone_number: "111-1111", idempotency_key: key)
      conflicting = call(group_size: 6, phone_number: "222-2222", idempotency_key: key)

      assert_equal :conflict, conflicting.outcome
      # The original entry must be completely untouched.
      assert_equal 2, original.queue_entry.reload.group_size
      assert_equal "111-1111", original.queue_entry.phone_number
    end

    test "a conflicting retry does not create a second QueueEntry" do
      key = SecureRandom.uuid
      call(group_size: 2, phone_number: "111-1111", idempotency_key: key)
      call(group_size: 6, phone_number: "222-2222", idempotency_key: key)

      assert_equal 1, QueueEntry.where(idempotency_key: key).count
    end

    # --- Same phone number, different keys: NOT the same logical entry ---

    test "the same phone number with different idempotency keys creates two separate entries" do
      a = call(group_size: 2, phone_number: "555-9999", idempotency_key: SecureRandom.uuid)
      b = call(group_size: 4, phone_number: "555-9999", idempotency_key: SecureRandom.uuid)

      assert_equal :created, a.outcome
      assert_equal :created, b.outcome
      assert_not_equal a.queue_entry.id, b.queue_entry.id
    end

    # --- Multiple visits ---

    test "a new idempotency key always creates a new visit with a new token" do
      first = call(idempotency_key: SecureRandom.uuid)
      second = call(idempotency_key: SecureRandom.uuid)

      assert_equal :created, second.outcome
      assert_not_equal first.queue_entry.id, second.queue_entry.id
      assert_not_equal first.queue_entry.active_visit_token, second.queue_entry.active_visit_token
    end

    # --- Anonymous token properties ---

    test "the token is not the database id" do
      result = call
      assert_not_equal result.queue_entry.id.to_s, result.queue_entry.active_visit_token
    end

    test "two new entries never receive the same token" do
      a = call(idempotency_key: SecureRandom.uuid)
      b = call(idempotency_key: SecureRandom.uuid)
      assert_not_equal a.queue_entry.active_visit_token, b.queue_entry.active_visit_token
    end

    # --- No allocation happens here (this phase's core boundary) ---

    test "a successful join creates no SeatingAssignment and no SeatingAssignmentTable" do
      # Delta-based, not an absolute 0 — this file's own setup already
      # claims one table (non-free, so the join itself still can't
      # allocate), so a bare global count is no longer a valid assumption.
      result = nil
      assert_no_difference [ "SeatingAssignment.count", "SeatingAssignmentTable.count" ] do
        result = call
      end

      assert_equal "waiting", result.queue_entry.status
      assert_equal 0, result.queue_entry.seating_assignments.count
    end

    # --- DEC-011: oversized-group rejection (Phase 5B.12) ---
    # This file's own setup claims a single capacity-10 table (non-free) —
    # so Allocation::ConfigurationGenerator.maximum_seatable_group_size is
    # exactly 10 for every test below, and that table can never itself
    # satisfy a real allocation (it's occupied), which is exactly what makes
    # the "valid but currently unavailable" test below meaningful.

    test "a group at the exact maximum valid size is accepted" do
      result = call(group_size: 10)

      assert_equal :created, result.outcome
      assert_equal "waiting", result.queue_entry.status
    end

    test "a group one larger than the maximum valid size is rejected" do
      result = call(group_size: 11)
      assert_equal :group_size_too_large, result.outcome
    end

    test "an impossible group creates no QueueEntry" do
      assert_no_difference "QueueEntry.count" do
        call(group_size: 11)
      end
    end

    test "an impossible group creates no SeatingAssignment or SeatingAssignmentTable" do
      assert_no_difference [ "SeatingAssignment.count", "SeatingAssignmentTable.count" ] do
        call(group_size: 11)
      end
    end

    test "an impossible group does not trigger allocation for anyone else waiting" do
      other_waiting = QueueEntry.create!(group_size: 2, phone_number: "555-0300", idempotency_key: SecureRandom.uuid)

      call(group_size: 11)

      assert_equal "waiting", other_waiting.reload.status
    end

    test "a valid-sized group with no currently-available table is NOT rejected as impossible" do
      # group_size: 10 exactly matches the maximum, but the only capacity-10
      # table in this file's fixture is claimed (non-free) — this must stay
      # a normal waiting join, never the impossible-group rejection.
      result = call(group_size: 10)

      assert_equal :created, result.outcome
      refute_equal :group_size_too_large, result.outcome
    end

    test "an impossible request remains rejected on retry with the same idempotency_key" do
      key = SecureRandom.uuid

      first = call(group_size: 11, idempotency_key: key)
      second = call(group_size: 11, idempotency_key: key)

      assert_equal :group_size_too_large, first.outcome
      assert_equal :group_size_too_large, second.outcome
      assert_equal 0, QueueEntry.where(idempotency_key: key).count
    end

    test "an impossible request never becomes a successful idempotent replay on retry" do
      key = SecureRandom.uuid

      call(group_size: 11, idempotency_key: key)
      retry_result = call(group_size: 11, idempotency_key: key)

      assert_not_equal :idempotent_replay, retry_result.outcome
      assert_nil retry_result.queue_entry
    end

    test "a malformed (zero) group_size is still a plain validation_error, not the impossible-group outcome" do
      result = call(group_size: 0)
      assert_equal :validation_error, result.outcome
    end

    test "a negative group_size is still a plain validation_error, not the impossible-group outcome" do
      result = call(group_size: -5)
      assert_equal :validation_error, result.outcome
    end
  end
end
