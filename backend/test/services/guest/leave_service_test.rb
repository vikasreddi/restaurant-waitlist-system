require "test_helper"

module Guest
  class LeaveServiceTest < ActiveSupport::TestCase
    def waiting_entry(phone: "555-0100")
      QueueEntry.create!(group_size: 2, phone_number: phone, idempotency_key: SecureRandom.uuid)
    end

    def build_ready_entry(phone: "555-0100", table_count: 1)
      entry = waiting_entry(phone: phone)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      tables = Array.new(table_count) { Table.create!(name: "LV-#{SecureRandom.hex(4)}", capacity: 2) }
      tables.each { |t| SeatingAssignmentTable.create!(seating_assignment: assignment, table: t) }
      [entry, assignment, tables]
    end

    def call(token)
      LeaveService.call(active_visit_token: token)
    end

    # --- Test 1: WAITING -> LEFT ---

    test "a waiting entry transitions to left" do
      entry = waiting_entry

      result = call(entry.active_visit_token)

      assert_equal :success, result.outcome
      assert_equal "left", entry.reload.status
      assert entry.left_at.present?
    end

    # --- Test 2: READY -> LEFT, releases assignment ---

    test "a ready entry transitions to left and releases its pending assignment" do
      entry, assignment, tables = build_ready_entry

      result = call(entry.active_visit_token)

      assert_equal :success, result.outcome
      assert_equal "left", entry.reload.status
      assert_equal "released", assignment.reload.status
      assert tables.first.reload.free?
      claim = SeatingAssignmentTable.find_by(seating_assignment_id: assignment.id)
      assert claim.released_at.present?
    end

    # --- Test 8/9: table release, combined reservation releases both tables ---

    test "a combined 2-table reservation releases both tables on leave" do
      entry, assignment, tables = build_ready_entry(table_count: 2)

      call(entry.active_visit_token)

      claims = SeatingAssignmentTable.where(seating_assignment_id: assignment.id)
      assert_equal 2, claims.count
      assert claims.all? { |c| c.released_at.present? }
      assert tables.all? { |t| t.reload.free? }
    end

    # --- Test 3/4: invalid/missing token ---

    test "an unknown token returns not_found" do
      assert_equal :not_found, call(SecureRandom.urlsafe_base64(32)).outcome
    end

    test "a blank token returns not_found" do
      assert_equal :not_found, call(nil).outcome
      assert_equal :not_found, call("").outcome
    end

    # --- Test 5: cross-guest isolation ---

    test "leaving with guest A's token never affects guest B's entry" do
      guest_a = waiting_entry(phone: "555-1111")
      guest_b = waiting_entry(phone: "555-2222")

      call(guest_a.active_visit_token)

      assert_equal "left", guest_a.reload.status
      assert_equal "waiting", guest_b.reload.status
    end

    # --- Test 6/7: repeated leave, terminal-state leave ---

    test "repeated leave requests are a safe no-op and never re-trigger side effects" do
      entry, assignment, = build_ready_entry
      first = call(entry.active_visit_token)
      assert_equal "left", first.queue_entry.status

      second = call(entry.active_visit_token)
      third = call(entry.active_visit_token)

      assert_equal :success, second.outcome
      assert_equal "left", second.queue_entry.status
      assert_equal :success, third.outcome
      assert_equal "left", entry.reload.status
      assert_equal "released", assignment.reload.status
      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id).count
    end

    test "leaving an already-seated entry is a safe no-op and reports the real status, not left" do
      entry = waiting_entry
      entry.update!(status: "seated", seated_at: Time.current)

      result = call(entry.active_visit_token)

      assert_equal :success, result.outcome
      assert_equal "seated", result.queue_entry.status
      assert_equal "seated", entry.reload.status
    end

    test "leaving an already-no_show entry is a safe no-op and reports no_show, not left" do
      entry = waiting_entry
      entry.update!(status: "no_show", no_show_at: Time.current)

      result = call(entry.active_visit_token)

      assert_equal :success, result.outcome
      assert_equal "no_show", result.queue_entry.status
    end

    # --- Test 11: allocation can use a table released by leave ---

    test "leaving a ready entry allows another waiting group to be allocated the freed table" do
      leaving_entry, assignment, tables = build_ready_entry(phone: "555-3001")
      waiting_elsewhere = waiting_entry(phone: "555-3002")

      call(leaving_entry.active_visit_token)

      assert_equal "ready", waiting_elsewhere.reload.status
      new_assignment = SeatingAssignment.find_by(queue_entry_id: waiting_elsewhere.id)
      assert_equal [tables.first.id], new_assignment.seating_assignment_tables.map(&:table_id)
    end

    test "a waiting-only leave does not trigger allocation (no table was ever released)" do
      leaving_entry = waiting_entry(phone: "555-4001")
      Table.create!(name: "LV-NOALLOC", capacity: 2)
      other_waiting = waiting_entry(phone: "555-4002")

      call(leaving_entry.active_visit_token)

      # If leaving a WAITING entry incorrectly triggered allocation, this
      # otherwise-eligible group would have been allocated too — verifying
      # it wasn't is really a check that #call's `released` gating works,
      # not that allocation itself is broken (it would be equally correct
      # either way, but the governing prompt's own Step 4 ties the trigger
      # specifically to table release).
      other_waiting.reload
      # Either behavior is "correct" for the guest (nothing is broken if it
      # did also allocate), so this test only documents the actual
      # implemented behavior: no allocation runs when nothing was released.
      assert_equal "waiting", other_waiting.status
    end

    # --- Test 12/13: unrelated entries/tables untouched ---

    test "leaving one entry does not modify unrelated entries or release unrelated tables" do
      entry, = build_ready_entry(phone: "555-5001")
      other_entry, other_assignment, other_tables = build_ready_entry(phone: "555-5002")

      call(entry.active_visit_token)

      assert_equal "ready", other_entry.reload.status
      assert_equal "pending", other_assignment.reload.status
      assert_not other_tables.first.reload.free?
    end

    # --- Test 10: atomic rollback ---

    test "a forced failure during release leaves QueueEntry ready and SeatingAssignment pending" do
      entry, assignment, tables = build_ready_entry

      original_update = SeatingAssignment.instance_method(:update!)
      SeatingAssignment.define_method(:update!) { |*| raise "forced failure" }

      begin
        assert_raises(RuntimeError) { call(entry.active_visit_token) }
      ensure
        SeatingAssignment.define_method(:update!, original_update)
      end

      assert_equal "ready", entry.reload.status
      assert_equal "pending", assignment.reload.status
      assert_nil entry.left_at
      assert tables.first.reload.free? == false # still held, never released
    end
  end
end
