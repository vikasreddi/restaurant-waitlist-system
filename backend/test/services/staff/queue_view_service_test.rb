require "test_helper"

module Staff
  class QueueViewServiceTest < ActiveSupport::TestCase
    def create_waiting(joined_at:, group_size: 2)
      entry = QueueEntry.create!(group_size: group_size, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(joined_at: joined_at)
      entry
    end

    def create_ready(code:, ready_at: Time.current, expires_at: 5.minutes.from_now, group_size: 2)
      entry = QueueEntry.create!(group_size: group_size, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: ready_at, seating_code: code)
      table = Table.create!(name: "QV-#{SecureRandom.hex(4)}", capacity: group_size)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending", expires_at: expires_at)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      [entry, assignment]
    end

    test "an empty queue returns empty lists" do
      result = QueueViewService.call
      assert_empty result.waiting
      assert_empty result.ready
    end

    test "one waiting entry is returned with position 1" do
      entry = create_waiting(joined_at: 10.minutes.ago)
      result = QueueViewService.call

      assert_equal 1, result.waiting.size
      assert_equal entry.id, result.waiting.first.entry_id
      assert_equal 1, result.waiting.first.position
    end

    test "multiple waiting entries are ordered chronologically with sequential positions" do
      older = create_waiting(joined_at: 20.minutes.ago)
      middle = create_waiting(joined_at: 10.minutes.ago)
      newer = create_waiting(joined_at: 1.minute.ago)

      result = QueueViewService.call

      assert_equal [older.id, middle.id, newer.id], result.waiting.map(&:entry_id)
      assert_equal [1, 2, 3], result.waiting.map(&:position)
    end

    test "a ready entry is returned with its seating_code and no allocation side effects" do
      entry, assignment = create_ready(code: "QV0001")

      result = QueueViewService.call

      assert_empty result.waiting
      assert_equal 1, result.ready.size
      ready = result.ready.first
      assert_equal entry.id, ready.entry_id
      assert_equal "QV0001", ready.seating_code
      assert_equal "pending", assignment.reload.status
    end

    test "mixed waiting and ready entries are separated into their own lists" do
      waiting_entry = create_waiting(joined_at: 5.minutes.ago)
      ready_entry, = create_ready(code: "QV0002")

      result = QueueViewService.call

      assert_equal [waiting_entry.id], result.waiting.map(&:entry_id)
      assert_equal [ready_entry.id], result.ready.map(&:entry_id)
    end

    test "terminal entries (seated/left/no_show) never appear in either list" do
      seated = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid,
        status: "seated", seated_at: Time.current)
      left = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid,
        status: "left", left_at: Time.current)
      no_show = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid,
        status: "no_show", no_show_at: Time.current)

      result = QueueViewService.call

      all_ids = result.waiting.map(&:entry_id) + result.ready.map(&:entry_id)
      refute_includes all_ids, seated.id
      refute_includes all_ids, left.id
      refute_includes all_ids, no_show.id
    end

    test "a waiting entry past the starvation threshold is flagged is_starvation_protected" do
      old_entry = create_waiting(joined_at: (Allocation::Policy::STARVATION_THRESHOLD_SECONDS + 60).seconds.ago)
      fresh_entry = create_waiting(joined_at: 1.minute.ago)

      result = QueueViewService.call

      old_result = result.waiting.find { |e| e.entry_id == old_entry.id }
      fresh_result = result.waiting.find { |e| e.entry_id == fresh_entry.id }
      assert old_result.is_starvation_protected
      refute fresh_result.is_starvation_protected
    end

    test "an overdue ready entry is expired to no_show, excluded from the ready list, and its table released" do
      entry, assignment = create_ready(code: "QV0003", ready_at: 10.minutes.ago, expires_at: 5.minutes.ago)

      result = QueueViewService.call

      assert_empty result.ready
      assert_equal "no_show", entry.reload.status
      assert_equal "released", assignment.reload.status
      assert assignment.seating_assignment_tables.first.released_at.present?
    end

    test "expiring an overdue ready entry does not trigger a new allocation" do
      waiting_entry = create_waiting(joined_at: 5.minutes.ago)
      _entry, assignment = create_ready(code: "QV0004", ready_at: 10.minutes.ago, expires_at: 5.minutes.ago)

      QueueViewService.call

      assert_equal "waiting", waiting_entry.reload.status
      assert_equal "released", assignment.reload.status
    end

    test "a still-valid ready entry is untouched" do
      entry, assignment = create_ready(code: "QV0005", ready_at: 1.minute.ago, expires_at: 4.minutes.from_now)

      result = QueueViewService.call

      assert_equal 1, result.ready.size
      assert_equal "ready", entry.reload.status
      assert_equal "pending", assignment.reload.status
    end

    test "no QueueEntry, SeatingAssignment, or SeatingAssignmentTable row is created by a plain read" do
      create_waiting(joined_at: 5.minutes.ago)
      create_ready(code: "QV0006")

      assert_no_difference [ "QueueEntry.count", "SeatingAssignment.count", "SeatingAssignmentTable.count" ] do
        QueueViewService.call
      end
    end
  end
end
