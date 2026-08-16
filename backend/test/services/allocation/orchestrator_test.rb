require "test_helper"

module Allocation
  class OrchestratorTest < ActiveSupport::TestCase
    NOW = Time.zone.parse("2026-01-01 12:00:00")

    setup do
      SeatingAssignmentTable.delete_all
      SeatingAssignment.delete_all
      QueueEntry.delete_all
      TableAdjacency.delete_all
      Table.delete_all
    end

    def waiting_entry(group_size:, joined_at: NOW - 60, phone: "555-0100")
      QueueEntry.create!(group_size: group_size, phone_number: phone, idempotency_key: SecureRandom.uuid, joined_at: joined_at)
    end

    def table(name:, capacity:)
      Table.create!(name: name, capacity: capacity)
    end

    # --- No candidate is a normal result ---

    test "an empty database orchestrates zero allocations, not an error" do
      summary = Orchestrator.call(now: NOW)

      assert_equal 0, summary.allocations_count
      assert_equal [], summary.allocated_queue_entry_ids
      assert_equal [], summary.assignment_ids
    end

    test "waiting entries with no compatible table orchestrate zero allocations" do
      waiting_entry(group_size: 6)
      table(name: "OR-1", capacity: 2)

      summary = Orchestrator.call(now: NOW)

      assert_equal 0, summary.allocations_count
    end

    # --- §26: multi-allocation, exact 1:1:1 matching by capacity ---

    test "three groups with three exactly-matching tables all become ready in one orchestration call" do
      a = waiting_entry(group_size: 2, phone: "555-3001")
      b = waiting_entry(group_size: 4, phone: "555-3002")
      c = waiting_entry(group_size: 6, phone: "555-3003")
      table(name: "OR-2", capacity: 2)
      table(name: "OR-4", capacity: 4)
      table(name: "OR-6", capacity: 6)

      summary = Orchestrator.call(now: NOW)

      assert_equal 3, summary.allocations_count
      assert_equal [a.id, b.id, c.id].sort, summary.allocated_queue_entry_ids.sort
      assert_equal "ready", a.reload.status
      assert_equal "ready", b.reload.status
      assert_equal "ready", c.reload.status
      assert_equal 3, SeatingAssignment.where(status: "pending").count

      # No table double-booked: each assignment claims exactly one table, and
      # the three claimed tables are all different.
      claimed_table_ids = SeatingAssignmentTable.where(released_at: nil).pluck(:table_id)
      assert_equal 3, claimed_table_ids.uniq.length

      # No compatible candidate remains.
      assert_not DecisionEngine.decide(
        waiting_entries: QueueEntry.where(status: "waiting").to_a,
        configurations: ConfigurationGenerator.call,
        now: NOW
      ).winner?
    end

    # --- §27: scarcity is recomputed, not cached, between passes ---

    test "scarcity for a remaining group changes after the first allocation consumes a table" do
      g1 = waiting_entry(group_size: 2, phone: "555-4001")
      g2 = waiting_entry(group_size: 2, phone: "555-4002", joined_at: NOW - 30)
      table(name: "OR-A", capacity: 2)
      table(name: "OR-B", capacity: 2)
      table(name: "OR-C", capacity: 4)

      configs_before = ConfigurationGenerator.call
      decision_before = DecisionEngine.decide(waiting_entries: [g1, g2], configurations: configs_before, now: NOW)
      assert_in_delta 1.0 / 3, decision_before.winner.scarcity_score, 1e-9

      result1 = ReservationService.call(now: NOW)
      assert result1.success?

      remaining = (result1.queue_entry.id == g1.id) ? g2 : g1
      configs_after = ConfigurationGenerator.call
      decision_after = DecisionEngine.decide(waiting_entries: [remaining.reload], configurations: configs_after, now: NOW)

      assert_in_delta 1.0 / 2, decision_after.winner.scarcity_score, 1e-9
    end

    # --- §28: combined-configuration availability is regenerated, not reused stale ---

    test "after a group consumes the last table making up a combined pair, that pair is never re-offered" do
      g8 = waiting_entry(group_size: 8, phone: "555-5001", joined_at: NOW - 60)
      g4 = waiting_entry(group_size: 4, phone: "555-5002", joined_at: NOW - 60)
      t1 = table(name: "OR-STANDALONE", capacity: 4)
      t2 = table(name: "OR-PAIR-A", capacity: 4)
      t3 = table(name: "OR-PAIR-B", capacity: 4)
      TableAdjacency.pair!(t2, t3)

      summary = Orchestrator.call(now: NOW)

      assert_equal 2, summary.allocations_count
      assert_equal "ready", g8.reload.status
      assert_equal "ready", g4.reload.status

      g8_assignment = SeatingAssignment.find_by(queue_entry_id: g8.id)
      g4_assignment = SeatingAssignment.find_by(queue_entry_id: g4.id)

      # G8 can ONLY be satisfied by the combined pair — verify it actually
      # got both, not a stale/partial view of it.
      assert_equal [t2.id, t3.id].sort, g8_assignment.seating_assignment_tables.map(&:table_id).sort
      # G4 falls back to the standalone table, since the pair is gone.
      assert_equal [t1.id], g4_assignment.seating_assignment_tables.map(&:table_id)

      # The pair is never left half-claimed or double-claimed.
      assert_equal 3, SeatingAssignmentTable.where(released_at: nil).count
    end

    # --- §29: starvation override remains effective across orchestration ---

    test "a starvation-protected group wins its only compatible table over a non-protected group, via the orchestrator" do
      protected_entry = waiting_entry(group_size: 2, phone: "555-6001", joined_at: NOW - 1300) # > 20 min
      normal_entry = waiting_entry(group_size: 2, phone: "555-6002", joined_at: NOW - 60)
      table(name: "OR-7", capacity: 2)

      summary = Orchestrator.call(now: NOW)

      assert_equal 1, summary.allocations_count
      assert_equal [protected_entry.id], summary.allocated_queue_entry_ids
      assert_equal "ready", protected_entry.reload.status
      assert_equal "waiting", normal_entry.reload.status
    end

    # --- Termination guarantee ---

    test "orchestration always terminates and returns a summary, never loops forever" do
      # A large-ish but finite scenario — the orchestrator must still return.
      10.times { |i| waiting_entry(group_size: 2, phone: "555-700#{i}") }
      5.times { |i| table(name: "OR-BULK-#{i}", capacity: 2) }

      summary = Orchestrator.call(now: NOW)

      assert_equal 5, summary.allocations_count
      assert_equal 5, QueueEntry.where(status: "waiting").count
    end
  end
end
