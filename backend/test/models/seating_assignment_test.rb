require "test_helper"

class SeatingAssignmentTest < ActiveSupport::TestCase
  setup do
    @entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
  end

  test "defaults to pending status" do
    assignment = SeatingAssignment.create!(queue_entry: @entry)
    assert_equal "pending", assignment.status
  end

  test "an invalid status is rejected" do
    assignment = SeatingAssignment.new(queue_entry: @entry, status: "bogus")
    assert_not assignment.valid?
  end

  test "invalid status is rejected at the database level" do
    assignment = SeatingAssignment.create!(queue_entry: @entry)

    assert_raises(ActiveRecord::StatementInvalid) do
      SeatingAssignment.connection.execute("UPDATE seating_assignments SET status = 'bogus' WHERE id = #{assignment.id}")
    end
  end

  test "requires a queue entry" do
    assignment = SeatingAssignment.new
    assert_not assignment.valid?
  end

  test "expires_at is set automatically at creation, READY_TIMEOUT in the future" do
    assignment = SeatingAssignment.create!(queue_entry: @entry)
    assert assignment.expires_at.present?
    assert_in_delta(
      (Time.current + SeatingAssignment::READY_TIMEOUT).to_i,
      assignment.expires_at.to_i,
      2 # seconds of slack for test execution time
    )
  end

  test "a queue entry can have at most one current (non-released) assignment" do
    SeatingAssignment.create!(queue_entry: @entry)
    second = SeatingAssignment.new(queue_entry: @entry)

    assert_not second.valid?
  end

  test "current-assignment uniqueness is enforced at the database level" do
    SeatingAssignment.create!(queue_entry: @entry)

    assert_raises(ActiveRecord::RecordNotUnique) do
      SeatingAssignment.connection.execute(
        "INSERT INTO seating_assignments (queue_entry_id, status, created_at, updated_at) " \
        "VALUES (#{@entry.id}, 'pending', now(), now())"
      )
    end
  end

  test "a second assignment IS allowed once the first is released (historical, not current)" do
    first = SeatingAssignment.create!(queue_entry: @entry)
    first.update!(status: "released", released_at: Time.current)

    second = SeatingAssignment.new(queue_entry: @entry)
    assert second.valid?
  end

  test "pending -> active -> released is a valid lifecycle" do
    assignment = SeatingAssignment.create!(queue_entry: @entry)
    assert_equal "pending", assignment.status

    assignment.update!(status: "active", activated_at: Time.current)
    assert_equal "active", assignment.status

    assignment.update!(status: "released", released_at: Time.current)
    assert_equal "released", assignment.status
  end
end
