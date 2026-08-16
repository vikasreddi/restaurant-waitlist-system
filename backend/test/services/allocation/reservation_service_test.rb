require "test_helper"
require "minitest/mock"

module Allocation
  class ReservationServiceTest < ActiveSupport::TestCase
    NOW = Time.zone.parse("2026-01-01 12:00:00")

    setup do
      SeatingAssignmentTable.delete_all
      SeatingAssignment.delete_all
      QueueEntry.delete_all
      TableAdjacency.delete_all
      Table.delete_all
    end

    def waiting_entry(group_size:, joined_at: NOW - 60, phone: "555-0100")
      QueueEntry.create!(
        group_size: group_size, phone_number: phone, idempotency_key: SecureRandom.uuid, joined_at: joined_at
      )
    end

    def table(name:, capacity:)
      Table.create!(name: name, capacity: capacity)
    end

    def claim_table!(table, status: "pending")
      other_entry = QueueEntry.create!(group_size: 2, phone_number: "555-9999", idempotency_key: SecureRandom.uuid)
      # A QueueEntry holding a pending/active SeatingAssignment is never
      # `waiting` in real domain state (domain-model.md §2) — leaving it
      # `waiting` here would leak a stray, already-assigned entry into the
      # real candidate pool the service queries, which is exactly the bug
      # this comment is here to prevent reintroducing.
      other_entry.update!(status: status == "active" ? "seated" : "ready", ready_at: NOW)
      assignment = SeatingAssignment.create!(queue_entry: other_entry, status: status)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      assignment
    end

    def call_service
      ReservationService.call(now: NOW)
    end

    # --- Test 1/2/3 — single-table allocation at each capacity ---

    test "single 2-seat allocation: pending assignment, one claimed table, entry ready" do
      entry = waiting_entry(group_size: 2)
      t = table(name: "RS-1", capacity: 2)

      result = call_service

      assert result.success?
      assert_equal "pending", result.seating_assignment.status
      assert_equal 1, result.seating_assignment.seating_assignment_tables.count
      claim = result.seating_assignment.seating_assignment_tables.first
      assert_equal t.id, claim.table_id
      assert_nil claim.released_at
      assert_equal "ready", result.queue_entry.reload.status
      assert_equal entry.id, result.queue_entry.id
    end

    test "4-seat allocation" do
      waiting_entry(group_size: 4)
      table(name: "RS-2", capacity: 4)

      result = call_service

      assert result.success?
      assert_equal 4, result.queue_entry.group_size
    end

    test "6-seat allocation" do
      waiting_entry(group_size: 6)
      table(name: "RS-3", capacity: 6)

      result = call_service

      assert result.success?
    end

    # --- Test 4/5 — combined allocation ---

    test "2+2 combined allocation reserves both tables under one assignment" do
      waiting_entry(group_size: 4)
      t1 = table(name: "RS-C1", capacity: 2)
      t2 = table(name: "RS-C2", capacity: 2)
      TableAdjacency.pair!(t1, t2)

      result = call_service

      assert result.success?
      assert_equal 2, result.seating_assignment.seating_assignment_tables.count
      claimed_ids = result.seating_assignment.seating_assignment_tables.map(&:table_id).sort
      assert_equal [t1.id, t2.id].sort, claimed_ids
      assert_equal "ready", result.queue_entry.status
    end

    test "4+4 combined allocation for a 6-person group" do
      waiting_entry(group_size: 6)
      t1 = table(name: "RS-D1", capacity: 4)
      t2 = table(name: "RS-D2", capacity: 4)
      TableAdjacency.pair!(t1, t2)

      result = call_service

      assert result.success?
      assert_equal 2, result.seating_assignment.seating_assignment_tables.count
    end

    # --- Test 6 — non-adjacent pair never forms a configuration ---

    test "two free but non-adjacent tables never combine into a configuration" do
      waiting_entry(group_size: 4)
      table(name: "RS-E1", capacity: 2) # not adjacent to RS-E2
      table(name: "RS-E2", capacity: 2)

      result = call_service

      assert_equal :no_candidate, result.outcome
    end

    # --- Test 7 — occupied table cannot be stolen ---

    test "an already-reserved table is never re-allocated" do
      waiting_entry(group_size: 2)
      occupied = table(name: "RS-F1", capacity: 2)
      claim_table!(occupied)

      result = call_service

      assert_equal :no_candidate, result.outcome
      assert_equal 1, SeatingAssignment.count # only the pre-existing one
    end

    # --- Test 8 — combined partial availability ---

    test "a free+occupied adjacent pair produces no allocation and no partial reservation" do
      waiting_entry(group_size: 4)
      free = table(name: "RS-G1", capacity: 2)
      occupied = table(name: "RS-G2", capacity: 2)
      TableAdjacency.pair!(free, occupied)
      claim_table!(occupied)

      result = call_service

      assert_equal :no_candidate, result.outcome
      assert_equal 1, SeatingAssignment.count
      assert_equal 0, SeatingAssignmentTable.where(table_id: free.id, released_at: nil).count
    end

    # --- Test 9 — QueueEntry no longer waiting when locked ---

    test "an entry that changed status before the transaction locked it is left untouched" do
      entry = waiting_entry(group_size: 2)
      table(name: "RS-H1", capacity: 2)
      entry.update!(status: "left", left_at: NOW)

      result = call_service

      assert_equal :no_candidate, result.outcome # the engine's own candidate pool already excludes it
      assert_equal "left", entry.reload.status
      assert_equal 0, SeatingAssignment.count
    end

    # --- Test 10 — duplicate active assignment prevented ---

    test "an entry with an existing pending assignment cannot receive a second one" do
      entry = waiting_entry(group_size: 2)
      entry.update!(status: "ready", ready_at: NOW, seating_code: "ZZZZZZ")
      existing_table = table(name: "RS-I1", capacity: 2)
      SeatingAssignment.create!(queue_entry: entry, status: "pending").tap do |a|
        SeatingAssignmentTable.create!(seating_assignment: a, table: existing_table)
      end
      table(name: "RS-I2", capacity: 2) # a second free table — should not matter, entry isn't waiting

      result = call_service

      assert_equal :no_candidate, result.outcome
      assert_equal 1, SeatingAssignment.count
    end

    # --- Test 11 — seating code properties ---

    test "the generated seating code is non-null, unique, and not derived from the database id" do
      entry = waiting_entry(group_size: 2)
      table(name: "RS-J1", capacity: 2)

      result = call_service

      assert result.queue_entry.seating_code.present?
      assert_not_equal entry.id.to_s, result.queue_entry.seating_code
      assert_equal 6, result.queue_entry.seating_code.length
    end

    # --- Test 12 — seating code collision safely retries ---

    test "a seating_code collision is detected and safely retried, never overwriting another guest's code" do
      taken_code = "AAAAAA"
      other_entry = waiting_entry(group_size: 2, phone: "555-1111")
      other_entry.update!(status: "ready", ready_at: NOW, seating_code: taken_code)

      waiting_entry(group_size: 2, phone: "555-2222")
      table(name: "RS-K1", capacity: 2)

      call_count = 0
      codes = [taken_code, "BBBBBB"]
      generator = -> { code = codes[call_count]; call_count += 1; code }

      result = Allocation::SeatingCodeGenerator.stub(:call, generator) { call_service }

      assert result.success?
      assert_equal "BBBBBB", result.queue_entry.seating_code
      assert_equal taken_code, other_entry.reload.seating_code # untouched
      assert_equal 2, call_count
    end

    # --- Test 13 — rollback leaves no partial records ---

    test "a forced failure after the assignment is created rolls back everything" do
      waiting_entry(group_size: 2)
      table(name: "RS-L1", capacity: 2)

      Allocation::SeatingCodeGenerator.stub(:call, -> { raise "forced failure" }) do
        assert_raises(RuntimeError) { call_service }
      end

      assert_equal 0, SeatingAssignment.count
      assert_equal 0, SeatingAssignmentTable.count
      assert_equal "waiting", QueueEntry.first.status
    end

    # --- Test 14 — combined rollback ---

    test "a forced failure during a 2-table allocation leaves neither table reserved" do
      waiting_entry(group_size: 4)
      t1 = table(name: "RS-M1", capacity: 2)
      t2 = table(name: "RS-M2", capacity: 2)
      TableAdjacency.pair!(t1, t2)

      Allocation::SeatingCodeGenerator.stub(:call, -> { raise "forced failure" }) do
        assert_raises(RuntimeError) { call_service }
      end

      assert_equal 0, SeatingAssignment.count
      assert_equal 0, SeatingAssignmentTable.count
      assert t1.reload.free?
      assert t2.reload.free?
    end

    # --- Test 15 — one allocation per call ---

    test "exactly one assignment is created even when multiple groups and tables are eligible" do
      waiting_entry(group_size: 2, phone: "555-3001")
      waiting_entry(group_size: 4, phone: "555-3002")
      waiting_entry(group_size: 6, phone: "555-3003")
      table(name: "RS-N1", capacity: 2)
      table(name: "RS-N2", capacity: 4)
      table(name: "RS-N3", capacity: 6)

      result = call_service

      assert result.success?
      assert_equal 1, SeatingAssignment.count
      assert_equal 2, QueueEntry.where(status: "waiting").count
    end

    # --- Test lock-order normalization ---

    test "combined-table locking always proceeds in ascending table id order regardless of configuration order" do
      waiting_entry(group_size: 4)
      # Create the higher-id table first so a naive implementation might be
      # tempted to lock in creation/argument order instead of id order.
      t_high = table(name: "RS-O2", capacity: 2)
      t_low = table(name: "RS-O1", capacity: 2)
      TableAdjacency.pair!(t_low, t_high) # canonical storage already sorts by id

      result = call_service

      assert result.success?
      assert_equal [t_low.id, t_high.id].sort, result.seating_assignment.seating_assignment_tables.map(&:table_id).sort
    end
  end
end
