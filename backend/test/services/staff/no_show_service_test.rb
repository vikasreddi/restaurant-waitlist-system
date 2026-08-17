require "test_helper"

module Staff
  class NoShowServiceTest < ActiveSupport::TestCase
    def waiting_entry(phone: "555-0100")
      QueueEntry.create!(group_size: 2, phone_number: phone, idempotency_key: SecureRandom.uuid)
    end

    def build_ready_entry(phone: "555-0100", table_count: 1)
      entry = waiting_entry(phone: phone)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      tables = Array.new(table_count) { Table.create!(name: "NS-#{SecureRandom.hex(4)}", capacity: 2) }
      tables.each { |t| SeatingAssignmentTable.create!(seating_assignment: assignment, table: t) }
      [entry, assignment, tables]
    end

    def call(entry_id)
      NoShowService.call(entry_id: entry_id)
    end

    test "a waiting entry transitions to no_show" do
      entry = waiting_entry

      result = call(entry.id)

      assert_equal :success, result.outcome
      assert_equal "no_show", entry.reload.status
      assert entry.no_show_at.present?
    end

    test "a ready entry transitions to no_show and releases its assignment" do
      entry, assignment, tables = build_ready_entry

      result = call(entry.id)

      assert_equal :success, result.outcome
      assert_equal "no_show", entry.reload.status
      assert_equal "released", assignment.reload.status
      assert tables.first.reload.free?
    end

    test "a ready no-show triggers Allocation::Orchestrator so its freed table can be reused" do
      other_waiting = QueueEntry.create!(group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid)
      entry, = build_ready_entry

      call(entry.id)

      assert_equal "ready", other_waiting.reload.status
    end

    test "a waiting no-show does not trigger a spurious allocation attempt result change" do
      entry = waiting_entry

      result = call(entry.id)

      assert_equal :success, result.outcome
    end

    test "a combined ready assignment releases both tables on no-show" do
      entry, assignment, tables = build_ready_entry(table_count: 2)

      call(entry.id)

      claims = SeatingAssignmentTable.where(seating_assignment_id: assignment.id)
      assert_equal 2, claims.count
      assert claims.all? { |c| c.released_at.present? }
      assert tables.all?(&:free?)
    end

    test "no_show is terminal: repeated no-show calls are a safe idempotent no-op" do
      entry = waiting_entry
      call(entry.id)
      first_no_show_at = entry.reload.no_show_at

      result = call(entry.id)

      assert_equal :success, result.outcome
      assert_equal "no_show", entry.reload.status
      assert_equal first_no_show_at, entry.no_show_at
    end

    test "a no_show entry cannot later be seated (via the existing seat confirmation path)" do
      entry, = build_ready_entry
      code = entry.seating_code
      call(entry.id)

      seat_result = Staff::ConfirmSeatingService.call(seating_code: code)

      assert_equal :conflict, seat_result.outcome
      assert_equal "no_show", entry.reload.status
    end

    test "marking an unknown entry_id no-show returns not_found" do
      result = call(-1)
      assert_equal :not_found, result.outcome
    end

    test "marking a seated entry no-show is rejected as invalid_target" do
      entry, assignment, = build_ready_entry
      assignment.update!(status: "active", activated_at: Time.current)
      entry.update!(status: "seated", seated_at: Time.current)

      result = call(entry.id)

      assert_equal :invalid_target, result.outcome
      assert_equal "seated", entry.reload.status
    end

    test "marking a left entry no-show is rejected as invalid_target" do
      entry = waiting_entry
      entry.update!(status: "left", left_at: Time.current)

      result = call(entry.id)

      assert_equal :invalid_target, result.outcome
      assert_equal "left", entry.reload.status
    end

    test "no-show never creates a second SeatingAssignment or SeatingAssignmentTable row" do
      entry, = build_ready_entry

      assert_no_difference [ "SeatingAssignment.count", "SeatingAssignmentTable.count" ] do
        call(entry.id)
      end
    end
  end
end
