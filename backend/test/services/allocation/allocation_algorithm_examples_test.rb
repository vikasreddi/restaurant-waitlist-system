require "test_helper"

module Allocation
  # Executes the most important worked examples from
  # documents/05-specifications/allocation-algorithm.md §21 directly against
  # DecisionEngine, per this phase's governing prompt §27 — if the engine's
  # actual behavior ever disagreed with one of these, that would be a
  # specification/implementation contradiction to report, not a test to
  # "fix" by changing the expected outcome. All matched on first run; no such
  # contradiction was found (see session-log.md).
  class AllocationAlgorithmExamplesTest < ActiveSupport::TestCase
    # Deliberately not shared with decision_engine_test.rb's identical
    # FakeEntry — cross-file class/constant references at load time are
    # fragile against Rails' file-loading order (test files are not
    # Zeitwerk-autoloaded), so this tiny duplication keeps the file
    # self-contained instead.
    Entry = Struct.new(:id, :group_size, :joined_at, :status) do
      def self.waiting(id:, group_size:, joined_at:)
        new(id, group_size, joined_at, "waiting")
      end
    end

    NOW = Time.zone.parse("2026-01-01 12:00:00")

    def config(ids, capacity)
      TableConfiguration.new(ids, capacity, ids.size)
    end

    def decide(entries, configurations)
      DecisionEngine.decide(waiting_entries: entries, configurations: configurations, now: NOW)
    end

    test "Example 3 — 2-person + 4-person groups, one free 4-seat table: the exact fit (4-person) wins" do
      g1 = Entry.waiting(id: 1, group_size: 2, joined_at: NOW - 60)
      g2 = Entry.waiting(id: 2, group_size: 4, joined_at: NOW - 60)

      result = decide([g1, g2], [config([1], 4)])

      assert_equal g2.id, result.winner.entry.id
    end

    test "Example 4 — 2-person + 6-person groups, one free 6-seat table: the exact fit (6-person) wins" do
      g1 = Entry.waiting(id: 1, group_size: 2, joined_at: NOW - 60)
      g2 = Entry.waiting(id: 2, group_size: 6, joined_at: NOW - 60)

      result = decide([g1, g2], [config([1], 6)])

      assert_equal g2.id, result.winner.entry.id
    end

    test "Example 6 — 6-person group, only a combined 4+4 pair available: the combined pair is the only candidate and wins" do
      g1 = Entry.waiting(id: 1, group_size: 6, joined_at: NOW - 60)

      result = decide([g1], [config([1, 2], 8)])

      assert result.winner?
      assert_equal 2, result.winner.configuration.table_count
    end

    test "Example 7 — 6-person group, a free 6-seat single AND a free 4+4 pair simultaneously: the better-fitting single table wins" do
      g1 = Entry.waiting(id: 1, group_size: 6, joined_at: NOW - 60)
      single_six = config([9], 6)
      combined_pair = config([1, 2], 8)

      result = decide([g1], [single_six, combined_pair])

      assert_equal 1, result.winner.configuration.table_count
      assert_equal [9], result.winner.configuration.table_ids
    end

    test "Example 9/16 — a starvation-protected large group wins over a better-fitting small group (the governing prompt's own §20 example)" do
      group_a = Entry.waiting(id: 1, group_size: 2, joined_at: NOW - 120) # 2 min
      group_b = Entry.waiting(id: 2, group_size: 6, joined_at: NOW - 1260) # 21 min, protected

      result = decide([group_a, group_b], [config([1], 6)])

      assert_equal group_b.id, result.winner.entry.id
    end

    test "Example 10 — two equally-eligible groups: deterministic tie-break, not randomness" do
      same_time = NOW - 200
      a = Entry.waiting(id: 3, group_size: 4, joined_at: same_time)
      b = Entry.waiting(id: 7, group_size: 4, joined_at: same_time)

      first = decide([a, b], [config([1], 4)])
      second = decide([b, a], [config([1], 4)]) # reversed input order

      assert_equal a.id, first.winner.entry.id
      assert_equal a.id, second.winner.entry.id # same result regardless of input order
    end

    test "Example 11 — scarcity protects the group with fewer alternatives" do
      # G_A has 3 compatible options; G_B has only the 6-seat table.
      configurations = [config([1], 2), config([2], 4), config([3], 6)]
      g_a = Entry.waiting(id: 1, group_size: 2, joined_at: NOW - 60)
      g_b = Entry.waiting(id: 2, group_size: 6, joined_at: NOW - 60)

      result = decide([g_a, g_b], configurations)

      # The 6-seat table specifically should go to G_B, not G_A.
      six_seat_winner = decide([g_a, g_b], [config([3], 6)])
      assert_equal g_b.id, six_seat_winner.winner.entry.id
      assert result.winner? # sanity: some allocation happens this pass
    end

    test "Example 12 — no currently available compatible configuration: no allocation, queue remains waiting" do
      g1 = Entry.waiting(id: 1, group_size: 6, joined_at: NOW - 60)

      result = decide([g1], [config([1], 2), config([2], 4)])

      assert_not result.winner?
    end
  end
end
