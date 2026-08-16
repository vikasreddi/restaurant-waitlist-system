require "test_helper"

module Staff
  class TableViewServiceTest < ActiveSupport::TestCase
    def build_entry(status: "waiting", group_size: 2)
      entry = QueueEntry.create!(group_size: group_size, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: status)
      entry
    end

    def claim_table(table, status: "pending", ready_at: Time.current, expires_at: 5.minutes.from_now)
      entry = build_entry(status: "ready", group_size: table.capacity)
      entry.update!(ready_at: ready_at, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: status, expires_at: expires_at)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      if status == "active"
        entry.update!(status: "seated", seated_at: Time.current)
        assignment.update!(activated_at: Time.current)
      end
      [entry, assignment]
    end

    test "all seeded tables are returned with correct ids and capacities" do
      result = TableViewService.call

      assert_equal Table.count, result.tables.size
      Table.find_each do |table|
        state = result.tables.find { |t| t.table_id == table.id }
        assert state, "expected table #{table.id} to be present"
        assert_equal table.capacity, state.capacity
      end
    end

    test "a table with no claim is free" do
      table = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      result = TableViewService.call

      state = result.tables.find { |t| t.table_id == table.id }
      assert_equal "free", state.status
      assert_nil state.current_queue_entry_id
      assert_nil state.seating_assignment_id
    end

    test "a table claimed by a pending assignment is held" do
      table = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      entry, assignment = claim_table(table, status: "pending")

      result = TableViewService.call

      state = result.tables.find { |t| t.table_id == table.id }
      assert_equal "held", state.status
      assert_equal entry.id, state.current_queue_entry_id
      assert_equal assignment.id, state.seating_assignment_id
    end

    test "a table claimed by an active assignment is occupied" do
      table = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      entry, assignment = claim_table(table, status: "active")

      result = TableViewService.call

      state = result.tables.find { |t| t.table_id == table.id }
      assert_equal "occupied", state.status
      assert_equal entry.id, state.current_queue_entry_id
      assert_equal assignment.id, state.seating_assignment_id
    end

    test "a table whose only assignment is released historically is free, not occupied" do
      table = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      entry, assignment = claim_table(table, status: "active")
      assignment.seating_assignment_tables.update_all(released_at: Time.current)
      assignment.update!(status: "released")
      entry.update!(status: "left", left_at: Time.current)

      result = TableViewService.call

      state = result.tables.find { |t| t.table_id == table.id }
      assert_equal "free", state.status
      assert_nil state.current_queue_entry_id
    end

    test "a combined two-table assignment shows both tables consistently" do
      table_a = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      table_b = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      entry = build_entry(status: "ready", group_size: 4)
      entry.update!(ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table_a)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table_b)

      result = TableViewService.call

      state_a = result.tables.find { |t| t.table_id == table_a.id }
      state_b = result.tables.find { |t| t.table_id == table_b.id }
      assert_equal "held", state_a.status
      assert_equal "held", state_b.status
      assert_equal assignment.id, state_a.seating_assignment_id
      assert_equal assignment.id, state_b.seating_assignment_id
      assert_equal entry.id, state_a.current_queue_entry_id
      assert_equal entry.id, state_b.current_queue_entry_id
    end

    test "no duplicate table records appear in the response" do
      result = TableViewService.call
      assert_equal result.tables.map(&:table_id).uniq.size, result.tables.size
    end

    test "an overdue held table is expired to free, and its entry becomes no_show" do
      table = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      entry, assignment = claim_table(table, status: "pending", ready_at: 10.minutes.ago, expires_at: 5.minutes.ago)

      result = TableViewService.call

      state = result.tables.find { |t| t.table_id == table.id }
      assert_equal "free", state.status
      assert_equal "no_show", entry.reload.status
      assert_equal "released", assignment.reload.status
    end

    test "expiring an overdue table does not trigger a new allocation" do
      waiting = build_entry(status: "waiting", group_size: 2)
      table = Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      claim_table(table, status: "pending", ready_at: 10.minutes.ago, expires_at: 5.minutes.ago)

      TableViewService.call

      assert_equal "waiting", waiting.reload.status
    end

    test "no database mutation other than the DEC-015 expiration side effect is caused by a plain read" do
      Table.create!(name: "TV-#{SecureRandom.hex(4)}", capacity: 2)
      build_entry(status: "waiting")

      assert_no_difference [ "QueueEntry.count", "SeatingAssignment.count", "SeatingAssignmentTable.count", "Table.count" ] do
        TableViewService.call
      end
    end
  end
end
