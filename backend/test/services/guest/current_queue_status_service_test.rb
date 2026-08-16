require "test_helper"

module Guest
  class CurrentQueueStatusServiceTest < ActiveSupport::TestCase
    def call(token)
      CurrentQueueStatusService.call(active_visit_token: token)
    end

    def create_waiting_entry(joined_at: Time.current)
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update_column(:joined_at, joined_at)
      entry
    end

    def create_ready_entry(expires_at: 10.minutes.from_now)
      entry = create_waiting_entry
      table = Table.create!(name: "TEST-#{SecureRandom.hex(4)}", capacity: 2)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, expires_at: expires_at)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      [entry, assignment, table]
    end

    # --- Token resolution ---

    test "a blank token is not found" do
      assert_equal :not_found, call(nil).outcome
      assert_equal :not_found, call("").outcome
    end

    test "an unknown token is not found" do
      assert_equal :not_found, call(SecureRandom.urlsafe_base64(32)).outcome
    end

    test "a valid token resolves the correct entry, not some other guest's" do
      other = create_waiting_entry
      mine = create_waiting_entry

      result = call(mine.active_visit_token)

      assert_equal :found, result.outcome
      assert_equal mine.id, result.queue_entry.id
      assert_not_equal other.id, result.queue_entry.id
    end

    # --- Waiting state / position ---

    test "a waiting entry returns status waiting with a position" do
      entry = create_waiting_entry
      result = call(entry.active_visit_token)

      assert_equal :found, result.outcome
      assert_equal "waiting", result.queue_entry.status
      assert_equal 1, result.position
    end

    test "position reflects chronological rank among currently-waiting entries only" do
      a = create_waiting_entry(joined_at: 3.minutes.ago)
      b = create_waiting_entry(joined_at: 2.minutes.ago)
      c = create_waiting_entry(joined_at: 1.minute.ago)

      assert_equal 1, call(a.active_visit_token).position
      assert_equal 2, call(b.active_visit_token).position
      assert_equal 3, call(c.active_visit_token).position
    end

    test "a non-waiting entry does not count toward another entry's position" do
      earlier = create_waiting_entry(joined_at: 5.minutes.ago)
      earlier.update!(status: "left", left_at: Time.current)
      later = create_waiting_entry(joined_at: 1.minute.ago)

      assert_equal 1, call(later.active_visit_token).position
    end

    # --- Ready state ---

    test "a ready entry (not expired) returns status ready with a seating_code and no position" do
      entry, = create_ready_entry(expires_at: 10.minutes.from_now)

      result = call(entry.active_visit_token)

      assert_equal :found, result.outcome
      assert_equal "ready", result.queue_entry.status
      assert_equal entry.seating_code, result.queue_entry.seating_code
      assert_nil result.position
    end

    # --- DEC-015 lazy expiration ---

    test "an overdue ready entry is expired to no_show on read, and its table is released" do
      entry, assignment, table = create_ready_entry(expires_at: 1.minute.ago)

      result = call(entry.active_visit_token)

      assert_equal :found, result.outcome
      assert_equal "no_show", result.queue_entry.status
      assert result.queue_entry.no_show_at.present?
      assert_equal "released", assignment.reload.status
      assert assignment.seating_assignment_tables.first.released_at.present?
      assert table.reload.free?
    end

    test "expiration is persisted, not just reflected in the in-memory result" do
      entry, = create_ready_entry(expires_at: 1.minute.ago)

      call(entry.active_visit_token)

      assert_equal "no_show", entry.reload.status
    end

    test "a ready entry within its expiration window is left untouched" do
      entry, assignment, = create_ready_entry(expires_at: 10.minutes.from_now)

      call(entry.active_visit_token)

      assert_equal "ready", entry.reload.status
      assert_equal "pending", assignment.reload.status
    end

    # --- Terminal states ---

    test "a seated entry returns only its status" do
      entry = create_waiting_entry
      entry.update!(status: "seated", seated_at: Time.current)

      result = call(entry.active_visit_token)

      assert_equal :found, result.outcome
      assert_equal "seated", result.queue_entry.status
      assert_nil result.position
    end

    test "a left entry returns only its status" do
      entry = create_waiting_entry
      entry.update!(status: "left", left_at: Time.current)

      result = call(entry.active_visit_token)

      assert_equal "left", result.queue_entry.status
      assert_nil result.position
    end

    test "a no_show entry returns only its status" do
      entry = create_waiting_entry
      entry.update!(status: "no_show", no_show_at: Time.current)

      result = call(entry.active_visit_token)

      assert_equal "no_show", result.queue_entry.status
      assert_nil result.position
    end

    # --- No allocation side effects from an ordinary read ---

    test "reading a waiting entry's status creates no SeatingAssignment or SeatingAssignmentTable" do
      entry = create_waiting_entry

      call(entry.active_visit_token)

      assert_equal 0, SeatingAssignment.count
      assert_equal 0, SeatingAssignmentTable.count
    end
  end
end
