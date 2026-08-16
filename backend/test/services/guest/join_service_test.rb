require "test_helper"

module Guest
  class JoinServiceTest < ActiveSupport::TestCase
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
      result = call

      assert_equal "waiting", result.queue_entry.status
      assert_equal 0, result.queue_entry.seating_assignments.count
      assert_equal 0, SeatingAssignmentTable.count
    end
  end
end
