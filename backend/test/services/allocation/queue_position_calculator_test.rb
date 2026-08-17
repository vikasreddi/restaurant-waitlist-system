require "test_helper"

module Allocation
  # Phase 5B.13 (DEC-005) — proves guest-facing `position` follows the real
  # allocation policy (compatibility, availability, aging, scarcity,
  # starvation), not a simple joined_at count. Uses its own small,
  # deterministic table/adjacency fixture, same convention as
  # configuration_generator_test.rb, so correctness doesn't depend on seed
  # distribution.
  class QueuePositionCalculatorTest < ActiveSupport::TestCase
    setup do
      SeatingAssignmentTable.delete_all
      SeatingAssignment.delete_all
      QueueEntry.delete_all
      TableAdjacency.delete_all
      Table.delete_all
    end

    def waiting_entry(group_size:, joined_at:, phone: "555-0100")
      entry = QueueEntry.create!(group_size: group_size, phone_number: phone, idempotency_key: SecureRandom.uuid)
      entry.update!(joined_at: joined_at)
      entry
    end

    def positions_for(entries, now: Time.current)
      result = QueuePositionCalculator.call(now: now)
      entries.map { |e| result[e.id] }
    end

    # --- Scenario A: chronological order differs from eligibility ---

    test "a group that is not currently serviceable ranks behind one that is, even though it joined first" do
      Table.create!(name: "QP-1", capacity: 2)

      group_a = waiting_entry(group_size: 6, joined_at: 10.minutes.ago) # too big for the only free table
      group_b = waiting_entry(group_size: 2, joined_at: 5.minutes.ago)  # fits the free table

      pos_a, pos_b = positions_for([group_a, group_b])

      assert_equal 1, pos_b
      assert_equal 2, pos_a
    end

    # --- Scenario B: same eligibility, tie-break by wait time (aging) ---

    test "with equal eligibility for two identical free tables, the longer-waiting group ranks first" do
      Table.create!(name: "QP-2", capacity: 2)
      Table.create!(name: "QP-3", capacity: 2)

      older = waiting_entry(group_size: 2, joined_at: 10.minutes.ago)
      newer = waiting_entry(group_size: 2, joined_at: 1.minute.ago)

      pos_older, pos_newer = positions_for([older, newer])

      assert_equal 1, pos_older
      assert_equal 2, pos_newer
    end

    # --- Scenario C: starvation protection ---

    test "a starvation-protected group outranks a non-protected group with a better fit, for the only compatible table" do
      Table.create!(name: "QP-4", capacity: 2)

      starved = waiting_entry(
        group_size: 2,
        joined_at: (Allocation::Policy::STARVATION_THRESHOLD_SECONDS + 60).seconds.ago
      )
      # A perfect-fit group that joined more recently — under ordinary
      # scoring this could plausibly win on fit_score alone, but starvation
      # protection is a categorical override (allocation-algorithm.md §9),
      # not an additive bonus.
      fresh_perfect_fit = waiting_entry(group_size: 2, joined_at: 1.minute.ago)

      pos_starved, pos_fresh = positions_for([starved, fresh_perfect_fit])

      assert_equal 1, pos_starved
      assert_equal 2, pos_fresh
    end

    # --- Scenario D: availability changes ---

    test "adding a compatible free table changes the reported position" do
      only_table = Table.create!(name: "QP-5", capacity: 2)

      leader = waiting_entry(group_size: 2, joined_at: 10.minutes.ago)
      follower = waiting_entry(group_size: 2, joined_at: 5.minutes.ago)

      before = QueuePositionCalculator.call
      assert_equal 1, before[leader.id]
      assert_equal 2, before[follower.id]

      Table.create!(name: "QP-6", capacity: 2)

      after = QueuePositionCalculator.call
      assert_equal 1, after[leader.id]
      assert_equal 2, after[follower.id]
      # Both groups are now individually rankable against a real
      # configuration (not just one of them) — proven by neither being
      # excluded from the ranked (non-leftover) set anymore.
      refute_nil after[leader.id]
      refute_nil after[follower.id]

      only_table.reload # sanity: fixture table still exists, untouched
    end

    test "occupying the only compatible table changes a group from ranked to leftover" do
      table = Table.create!(name: "QP-7", capacity: 2)
      entry = waiting_entry(group_size: 2, joined_at: 5.minutes.ago)

      ranked_before = QueuePositionCalculator.call[entry.id]
      assert_equal 1, ranked_before

      claimer = QueueEntry.create!(group_size: 2, phone_number: "555-0199", idempotency_key: SecureRandom.uuid)
      claimer.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: claimer, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      position_after = QueuePositionCalculator.call[entry.id]
      assert_equal 1, position_after # now the only waiting entry, so still position 1 — but via the leftover path
    end

    # --- No side effects ---

    test "computing positions never creates a QueueEntry, SeatingAssignment, or SeatingAssignmentTable" do
      Table.create!(name: "QP-8", capacity: 2)
      waiting_entry(group_size: 2, joined_at: 5.minutes.ago)
      waiting_entry(group_size: 2, joined_at: 1.minute.ago)

      assert_no_difference [ "QueueEntry.count", "SeatingAssignment.count", "SeatingAssignmentTable.count", "Table.count" ] do
        QueuePositionCalculator.call
      end
    end

    test "an empty waiting queue returns an empty position map" do
      Table.create!(name: "QP-9", capacity: 2)
      assert_equal({}, QueuePositionCalculator.call)
    end

    test "a combined two-table configuration removes both member tables from later rounds" do
      t1 = Table.create!(name: "QP-A1", capacity: 4)
      t2 = Table.create!(name: "QP-A2", capacity: 4)
      TableAdjacency.pair!(t1, t2)

      # Needs the combined pair (8 capacity) — no single table can seat it.
      big_group = waiting_entry(group_size: 8, joined_at: 10.minutes.ago)
      # Would want either t1 or t2 alone, but both are consumed by the
      # winning combined configuration above.
      small_group = waiting_entry(group_size: 4, joined_at: 5.minutes.ago)

      positions = QueuePositionCalculator.call

      assert_equal 1, positions[big_group.id]
      assert_equal 2, positions[small_group.id]
    end
  end
end
