require "test_helper"

module Staff
  class ReleaseServiceTest < ActiveSupport::TestCase
    def build_seated_entry(phone: "555-0100", table_count: 1)
      entry = QueueEntry.create!(group_size: 2, phone_number: phone, idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      tables = Array.new(table_count) { Table.create!(name: "RL-#{SecureRandom.hex(4)}", capacity: 2) }
      tables.each { |t| SeatingAssignmentTable.create!(seating_assignment: assignment, table: t) }
      assignment.update!(status: "active", activated_at: Time.current)
      entry.update!(status: "seated", seated_at: Time.current)
      [entry, assignment, tables]
    end

    def call(entry_id)
      ReleaseService.call(entry_id: entry_id)
    end

    test "a seated entry releases successfully and its table becomes free" do
      entry, assignment, tables = build_seated_entry

      result = call(entry.id)

      assert_equal :success, result.outcome
      assert_equal [ tables.first.id ], result.table_ids_released
      assert_equal "released", assignment.reload.status
      assert tables.first.reload.free?
    end

    test "QueueEntry.status stays seated after release (historical record, not a new terminal state)" do
      entry, = build_seated_entry

      call(entry.id)

      assert_equal "seated", entry.reload.status
    end

    test "release triggers Allocation::Orchestrator so a freed table can be reused" do
      waiting = QueueEntry.create!(group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid)
      entry, = build_seated_entry

      call(entry.id)

      assert_equal "ready", waiting.reload.status
    end

    test "a combined 2-table assignment releases both tables atomically" do
      entry, assignment, tables = build_seated_entry(table_count: 2)

      result = call(entry.id)

      assert_equal 2, result.table_ids_released.size
      claims = SeatingAssignmentTable.where(seating_assignment_id: assignment.id)
      assert_equal 2, claims.count
      assert claims.all? { |c| c.released_at.present? }
      assert tables.all? { |t| t.reload.free? }
    end

    test "no partial combined release: both claim rows are released in the same call" do
      entry, assignment, tables = build_seated_entry(table_count: 2)

      call(entry.id)

      released_count = SeatingAssignmentTable.where(seating_assignment_id: assignment.id).where.not(released_at: nil).count
      assert_equal 2, released_count
      assert tables.all?(&:free?)
    end

    test "historical SeatingAssignmentTable rows remain after release (never deleted)" do
      entry, assignment, = build_seated_entry

      call(entry.id)

      assert_equal 1, SeatingAssignmentTable.where(seating_assignment_id: assignment.id).count
    end

    test "releasing an already-released entry is a safe idempotent no-op" do
      entry, assignment, = build_seated_entry
      call(entry.id)

      result = call(entry.id)

      assert_equal :success, result.outcome
      assert_equal [], result.table_ids_released
      assert_equal "released", assignment.reload.status
    end

    test "releasing an unknown entry_id returns not_found" do
      result = call(-1)
      assert_equal :not_found, result.outcome
    end

    test "releasing a waiting entry (never seated) is rejected as invalid_target" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)

      result = call(entry.id)

      assert_equal :invalid_target, result.outcome
      assert_equal "waiting", entry.reload.status
    end

    test "releasing a ready (not yet seated) entry is rejected as invalid_target, and does not release its table" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      table = Table.create!(name: "RL-#{SecureRandom.hex(4)}", capacity: 2)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      result = call(entry.id)

      assert_equal :invalid_target, result.outcome
      assert_equal "pending", assignment.reload.status
      refute table.reload.free?
    end

    test "release never creates a second SeatingAssignment or SeatingAssignmentTable row" do
      entry, = build_seated_entry

      assert_no_difference [ "SeatingAssignment.count", "SeatingAssignmentTable.count" ] do
        call(entry.id)
      end
    end
  end
end
