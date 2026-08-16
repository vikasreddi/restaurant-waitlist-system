require "test_helper"

module Staff
  class ConfirmSeatingServiceTest < ActiveSupport::TestCase
    def create_table(capacity: 2)
      Table.create!(name: "CS-#{SecureRandom.hex(4)}", capacity: capacity)
    end

    def build_ready_entry(group_size: 2, table_count: 1, code: SecureRandom.hex(4), expires_at: 10.minutes.from_now)
      entry = QueueEntry.create!(group_size: group_size, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: code)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending", expires_at: expires_at)
      tables = Array.new(table_count) { create_table }
      tables.each { |t| SeatingAssignmentTable.create!(seating_assignment: assignment, table: t) }
      [entry, assignment, tables]
    end

    def call(code)
      ConfirmSeatingService.call(seating_code: code)
    end

    # --- Test 1/2 — successful transition ---

    test "a valid ready/pending reservation transitions to seated/active" do
      entry, assignment, = build_ready_entry(code: "ABCD01")

      result = call("ABCD01")

      assert_equal :success, result.outcome
      assert_equal "seated", entry.reload.status
      assert entry.seated_at.present?
      assert_equal "active", assignment.reload.status
      assert assignment.activated_at.present?
    end

    # --- DEC-015: confirmation is also a lazy-expiration checkpoint (functional-spec.md §6a step 2) ---

    test "a ready entry that is actually overdue is expired to no_show at confirmation time, not confirmed" do
      entry, assignment, tables = build_ready_entry(code: "EXPD001", expires_at: 1.minute.ago)

      result = call("EXPD001")

      assert_equal :conflict, result.outcome
      assert_equal "no_show", entry.reload.status
      assert_equal "released", assignment.reload.status
      assert tables.first.reload.free?
    end

    test "the expiration triggered by an overdue confirmation attempt actually commits, not just reports conflict" do
      entry, assignment, = build_ready_entry(code: "EXPD002", expires_at: 1.minute.ago)

      call("EXPD002")

      # Persisted, independent of the in-memory Result — a fresh query, not
      # the same objects the service already touched.
      assert_equal "no_show", QueueEntry.find(entry.id).status
      assert_equal "released", SeatingAssignment.find(assignment.id).status
    end

    test "confirmation does not trigger Allocation::Orchestrator even when it expires the reservation" do
      entry, = build_ready_entry(code: "EXPD003", expires_at: 1.minute.ago)
      other_waiting = QueueEntry.create!(group_size: 2, phone_number: "555-0400", idempotency_key: SecureRandom.uuid)

      call("EXPD003")

      # The table this expiration just freed is NOT synchronously
      # reallocated by this service (§25 of this phase's governing prompt)
      # — it stays free until some other trigger picks it up.
      assert_equal "waiting", other_waiting.reload.status
    end

    # --- Test 3 — unknown code ---

    test "an unknown seating code returns not_found" do
      result = call("NOPE99")
      assert_equal :not_found, result.outcome
    end

    test "a blank seating code returns not_found" do
      assert_equal :not_found, call(nil).outcome
      assert_equal :not_found, call("").outcome
    end

    # --- Test 4 — WAITING cannot be confirmed (defensive; codes don't exist for waiting entries) ---

    test "a waiting entry (defensively, no code should ever exist for one) cannot be confirmed" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update_column(:seating_code, "WAIT01") # bypasses normal invariants deliberately, hard-path test

      result = call("WAIT01")

      assert_equal :not_found, result.outcome
      assert_equal "waiting", entry.reload.status
    end

    # --- Test 5/9 — already SEATED / already ACTIVE cannot be confirmed again ---

    test "an already-seated entry cannot be confirmed again" do
      entry, assignment, = build_ready_entry(code: "SEAT01")
      first = call("SEAT01")
      assert_equal :success, first.outcome

      second = call("SEAT01")

      assert_equal :already_confirmed, second.outcome
      assert_equal "seated", entry.reload.status
      assert_equal "active", assignment.reload.status
      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id).count
    end

    # --- Test 6 — LEFT cannot be confirmed ---

    test "a left entry cannot be confirmed" do
      entry, assignment, = build_ready_entry(code: "LEFT01")
      assignment.seating_assignment_tables.update_all(released_at: Time.current)
      assignment.update!(status: "released")
      entry.update!(status: "left", left_at: Time.current)

      result = call("LEFT01")

      assert_equal :conflict, result.outcome
      assert_equal "left", entry.reload.status
    end

    # --- Test 7 — NO_SHOW cannot be confirmed ---

    test "a no_show (expired) entry cannot be confirmed" do
      entry, assignment, = build_ready_entry(code: "NOSHOW1")
      assignment.seating_assignment_tables.update_all(released_at: Time.current)
      assignment.update!(status: "released")
      entry.update!(status: "no_show", no_show_at: Time.current)

      result = call("NOSHOW1")

      assert_equal :conflict, result.outcome
      assert_equal "no_show", entry.reload.status
    end

    # --- Test 8 — RELEASED assignment (inconsistent state, defensive) cannot be confirmed ---

    test "a ready entry whose assignment was released out from under it (inconsistent state) cannot be confirmed" do
      entry, assignment, = build_ready_entry(code: "REL0001")
      # Force the inconsistency directly, bypassing the normal domain
      # transition — hard-path test of the service's own defensive check,
      # not a state reachable via any real code path.
      assignment.update_column(:status, "released")

      result = call("REL0001")

      assert_equal :conflict, result.outcome
      assert_equal "ready", entry.reload.status # confirmation did not force it forward
    end

    # --- Test 10 — repeated confirmation does not duplicate state ---

    test "repeated confirmation with the same code never creates duplicate assignments or table rows" do
      entry, = build_ready_entry(code: "DUP0001")
      3.times { call("DUP0001") }

      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id).count
      assert_equal 1, SeatingAssignmentTable.where(seating_assignment_id: SeatingAssignment.where(queue_entry_id: entry.id).select(:id)).count
    end

    # --- Test 11 — atomic transition ---

    test "the QueueEntry and SeatingAssignment transitions are atomic: never seated+pending or ready+active" do
      entry, assignment, = build_ready_entry(code: "ATOM001")

      call("ATOM001")

      entry.reload
      assignment.reload
      valid_pairs = [%w[ready pending], %w[seated active]]
      assert_includes valid_pairs, [entry.status, assignment.status]
    end

    # --- Test 12 — forced rollback leaves no partial state ---

    test "a forced failure after locking leaves QueueEntry ready and SeatingAssignment pending" do
      entry, assignment, = build_ready_entry(code: "ROLL001")

      # No mocha/any_instance in this project's plain minitest setup — force
      # the failure between the assignment update and the entry update via a
      # temporary method patch on the class, restored in ensure so no other
      # test in the suite is affected.
      original_update = SeatingAssignment.instance_method(:update!)
      SeatingAssignment.define_method(:update!) { |*| raise "forced failure" }

      begin
        assert_raises(RuntimeError) { call("ROLL001") }
      ensure
        SeatingAssignment.define_method(:update!, original_update)
      end

      assert_equal "ready", entry.reload.status
      assert_equal "pending", assignment.reload.status
      assert_nil entry.seated_at
      assert_nil assignment.activated_at
    end

    # --- Test 14 — combined 2-table confirmation ---

    test "a combined 2-table reservation confirms both tables under the same active assignment" do
      entry, assignment, tables = build_ready_entry(group_size: 4, table_count: 2, code: "COMB001")

      result = call("COMB001")

      assert_equal :success, result.outcome
      assert_equal "active", assignment.reload.status
      claimed = assignment.seating_assignment_tables.reload
      assert_equal 2, claimed.count
      assert_equal tables.map(&:id).sort, claimed.map(&:table_id).sort
      assert claimed.all? { |c| c.released_at.nil? }
    end

    # --- Test 16/17 — no additional assignment/assignment-table rows ---

    test "confirmation never creates another SeatingAssignment or SeatingAssignmentTable row" do
      entry, = build_ready_entry(code: "NOADD01")
      before_assignments = SeatingAssignment.count
      before_tables = SeatingAssignmentTable.count

      call("NOADD01")

      assert_equal before_assignments, SeatingAssignment.count
      assert_equal before_tables, SeatingAssignmentTable.count
    end

    # --- Test 13 — seating_code is never regenerated ---

    test "confirmation never changes the seating_code" do
      entry, = build_ready_entry(code: "KEEP001")

      call("KEEP001")

      assert_equal "KEEP001", entry.reload.seating_code
    end

    # --- Test 18 — Table records are never modified ---

    test "confirmation does not modify Table records, occupancy remains derived" do
      entry, assignment, tables = build_ready_entry(code: "TBL0001")
      table = tables.first
      original_attributes = table.reload.attributes

      call("TBL0001")

      assert_equal original_attributes, table.reload.attributes
      assert_not table.free? # derived: occupied now, via the active assignment's claim row
    end

    # --- Test 25 — no allocation side effect ---

    test "confirmation never triggers Allocation::Orchestrator, DecisionEngine, or ReservationService" do
      entry, = build_ready_entry(code: "NOALLOC")
      waiting_elsewhere = QueueEntry.create!(group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid)
      Table.create!(name: "CS-EXTRA-#{SecureRandom.hex(4)}", capacity: 2)

      call("NOALLOC")

      # If confirmation had (incorrectly) triggered allocation, this
      # otherwise-eligible waiting entry would have been allocated too.
      assert_equal "waiting", waiting_elsewhere.reload.status
    end
  end
end
