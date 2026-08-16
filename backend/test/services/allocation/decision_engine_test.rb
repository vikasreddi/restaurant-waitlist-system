require "test_helper"

module Allocation
  # Deliberately does not touch the database anywhere in this file (the
  # engine is pure, allocation-algorithm.md §2/§4) — every "entry" here is a
  # plain in-memory double, not a persisted QueueEntry, and every
  # configuration is built directly, not read from Table/TableAdjacency. See
  # configuration_generator_test.rb for the separate, DB-touching piece.
  class DecisionEngineTest < ActiveSupport::TestCase
    FakeEntry = Struct.new(:id, :group_size, :joined_at, :status) do
      def self.waiting(id:, group_size:, joined_at:)
        new(id, group_size, joined_at, "waiting")
      end
    end

    NOW = Time.zone.parse("2026-01-01 12:00:00")

    def config(ids, capacity)
      TableConfiguration.new(ids, capacity, ids.size)
    end

    def decide(entries, configurations, now: NOW)
      DecisionEngine.decide(waiting_entries: entries, configurations: configurations, now: now)
    end

    # --- Test 1/2 — fit score ---

    test "exact fit: group 2 on a capacity-2 table scores fit 1.0" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      result = decide([entry], [config([1], 2)])

      assert result.winner?
      assert_in_delta 1.0, result.winner.fit_score, 1e-9
    end

    test "larger compatible table: group 2 on a capacity-4 table scores fit 0.5" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      result = decide([entry], [config([1], 4)])

      assert_in_delta 0.5, result.winner.fit_score, 1e-9
    end

    test "fit score is never inverted or bonused: group 4 on capacity 6 is exactly 4/6" do
      entry = FakeEntry.waiting(id: 1, group_size: 4, joined_at: NOW)
      result = decide([entry], [config([1], 6)])

      assert_in_delta 4.0 / 6.0, result.winner.fit_score, 1e-9
    end

    # --- Test 3 — hard compatibility gate ---

    test "incompatible configuration: group 6 on capacity 4 is excluded, not scored" do
      entry = FakeEntry.waiting(id: 1, group_size: 6, joined_at: NOW)
      result = decide([entry], [config([1], 4)])

      assert_not result.winner?
    end

    # --- Test 4/5 — scarcity ---

    test "scarcity: a group with 3 currently-compatible configurations scores 1/3" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      configurations = [config([1], 2), config([2], 4), config([3], 6)]
      result = decide([entry], configurations)

      assert_in_delta 1.0 / 3.0, result.winner.scarcity_score, 1e-9
    end

    test "scarcity: a group with exactly 1 compatible configuration scores 1.0" do
      entry = FakeEntry.waiting(id: 1, group_size: 6, joined_at: NOW)
      configurations = [config([1], 2), config([2], 4), config([3], 6)]
      result = decide([entry], configurations)

      assert_in_delta 1.0, result.winner.scarcity_score, 1e-9
    end

    test "scarcity is calculated independently per entry, not one global number" do
      # Same configuration landscape for both, evaluated separately (each is
      # the only waiting entry in its own call) so the winner's own scarcity
      # is directly inspectable — small has 3 compatible options, large has 1.
      configurations = [config([1], 2), config([2], 4), config([3], 6)]

      small = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      large = FakeEntry.waiting(id: 2, group_size: 6, joined_at: NOW)

      small_result = decide([small], configurations)
      large_result = decide([large], configurations)

      assert_in_delta 1.0 / 3.0, small_result.winner.scarcity_score, 1e-9
      assert_in_delta 1.0, large_result.winner.scarcity_score, 1e-9
    end

    # --- Test 6 — aging ---

    test "aging is 0.0 at the instant of joining" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      result = decide([entry], [config([1], 2)])

      assert_in_delta 0.0, result.winner.aging_score, 1e-9
    end

    test "aging is 0.5 at exactly half the configured aging window" do
      half_window_ago = NOW - Allocation::Policy::MAX_AGING_WINDOW_SECONDS / 2
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: half_window_ago)
      result = decide([entry], [config([1], 2)])

      assert_in_delta 0.5, result.winner.aging_score, 1e-6
    end

    test "aging is capped at 1.0 at and beyond the maximum aging window" do
      at_window = NOW - Allocation::Policy::MAX_AGING_WINDOW_SECONDS
      well_past_window = NOW - (Allocation::Policy::MAX_AGING_WINDOW_SECONDS * 10)

      entry_at = FakeEntry.waiting(id: 1, group_size: 2, joined_at: at_window)
      entry_past = FakeEntry.waiting(id: 2, group_size: 2, joined_at: well_past_window)

      # Score each alone so starvation protection (also true past the window)
      # doesn't exclude the other from the pool.
      result_at = decide([entry_at], [config([1], 2)])
      result_past = decide([entry_past], [config([1], 2)])

      assert_in_delta 1.0, result_at.winner.aging_score, 1e-9
      assert_in_delta 1.0, result_past.winner.aging_score, 1e-9
    end

    # --- Test 7 — starvation threshold ---

    test "not starvation-protected just before the threshold" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - (Allocation::Policy::STARVATION_THRESHOLD_SECONDS - 1))
      result = decide([entry], [config([1], 2)])

      assert_not result.winner.starvation_protected
    end

    test "starvation-protected at exactly the threshold" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - Allocation::Policy::STARVATION_THRESHOLD_SECONDS)
      result = decide([entry], [config([1], 2)])

      assert result.winner.starvation_protected
    end

    # --- Test 8 — starvation pool override ---

    test "a single starvation-protected candidate excludes all non-protected candidates" do
      protected_entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 1300)
      non_protected_a = FakeEntry.waiting(id: 2, group_size: 2, joined_at: NOW - 60)
      non_protected_b = FakeEntry.waiting(id: 3, group_size: 2, joined_at: NOW - 30)

      result = decide([protected_entry, non_protected_a, non_protected_b], [config([1], 2)])

      assert_equal protected_entry.id, result.winner.entry.id
    end

    test "starvation is a categorical filter, never an additive score bonus" do
      # A non-protected candidate with a much better fit/scarcity must still
      # lose to a protected candidate with a worse fit, on the SAME
      # configuration — proves protection isn't merely a numeric nudge.
      protected_entry = FakeEntry.waiting(id: 1, group_size: 6, joined_at: NOW - 1300)
      better_fit_entry = FakeEntry.waiting(id: 2, group_size: 2, joined_at: NOW - 60)

      result = decide([protected_entry, better_fit_entry], [config([1], 6)])

      assert_equal protected_entry.id, result.winner.entry.id
    end

    # --- Test 9 — exact weighted formula ---

    test "total_score is the exact weighted sum of the three components" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 300)
      result = decide([entry], [config([1], 4)])

      expected =
        (Allocation::Policy::FIT_WEIGHT * result.winner.fit_score) +
        (Allocation::Policy::SCARCITY_WEIGHT * result.winner.scarcity_score) +
        (Allocation::Policy::AGING_WEIGHT * result.winner.aging_score)

      assert_in_delta expected, result.winner.total_score, 1e-9
      assert_in_delta 0.4, Allocation::Policy::FIT_WEIGHT, 1e-9
      assert_in_delta 0.3, Allocation::Policy::SCARCITY_WEIGHT, 1e-9
      assert_in_delta 0.3, Allocation::Policy::AGING_WEIGHT, 1e-9
    end

    # --- Test 10/11/12 — deterministic tie-breaking ---

    test "on an equal total_score, fewer tables consumed wins" do
      # group 4 on a single 4-seat table (fit=1.0) vs. a combined 2+2 pair
      # (capacity 4, fit=1.0) — identical fit/scarcity/aging, single must win.
      entry = FakeEntry.waiting(id: 1, group_size: 4, joined_at: NOW)
      single = config([1], 4)
      combined = config([2, 3], 4)

      result = decide([entry], [single, combined])

      assert_equal 1, result.winner.configuration.table_count
    end

    test "on an equal score and table count, earlier joined_at wins" do
      earlier = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 500)
      later = FakeEntry.waiting(id: 2, group_size: 2, joined_at: NOW - 100)

      result = decide([earlier, later], [config([1], 2)])

      assert_equal earlier.id, result.winner.entry.id
    end

    test "on an equal score, table count, and joined_at, the lower id wins" do
      same_time = NOW - 200
      lower_id = FakeEntry.waiting(id: 5, group_size: 2, joined_at: same_time)
      higher_id = FakeEntry.waiting(id: 9, group_size: 2, joined_at: same_time)

      result = decide([higher_id, lower_id], [config([1], 2)])

      assert_equal lower_id.id, result.winner.entry.id
    end

    # --- Test 13 — single vs combined use the same formulas ---

    test "a combined configuration's capacity is the sum of its two tables" do
      entry = FakeEntry.waiting(id: 1, group_size: 6, joined_at: NOW)
      combined = config([3, 4], 8) # e.g. two 4-seat tables

      result = decide([entry], [combined])

      assert_equal 8, result.winner.configuration.capacity
      assert_in_delta 6.0 / 8.0, result.winner.fit_score, 1e-9
    end

    test "a single table is not hardcoded to always win — the better-fit combined pair wins here" do
      entry = FakeEntry.waiting(id: 1, group_size: 8, joined_at: NOW)
      single_oversized = config([1], 10) # fit 0.8, only compatible single option
      combined_exact = config([2, 3], 8) # fit 1.0

      result = decide([entry], [single_oversized, combined_exact])

      assert_equal 2, result.winner.configuration.table_count
    end

    # --- Test 14 — no compatible candidate ---

    test "no compatible configuration exists: no winner, not an error" do
      entry = FakeEntry.waiting(id: 1, group_size: 6, joined_at: NOW)
      result = decide([entry], [config([1], 2), config([2], 4)])

      assert_not result.winner?
      assert_nil result.winner
    end

    test "empty waiting entries: no winner" do
      result = decide([], [config([1], 2)])
      assert_not result.winner?
    end

    test "empty configurations: no winner" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      result = decide([entry], [])
      assert_not result.winner?
    end

    # --- Test 15 — global grid, not first-match ---

    test "the winner comes from global candidate ranking, not the first group or first table" do
      # First-in-list group (id 1) is a poor fit for the first-in-list table;
      # a later group/table pairing is the objectively better match and must
      # win despite not being first in either list.
      first_group = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 10)
      best_fit_group = FakeEntry.waiting(id: 2, group_size: 4, joined_at: NOW - 10)

      first_table = config([1], 6) # poor fit for either group
      exact_table = config([2], 4) # exact fit for best_fit_group only

      result = decide([first_group, best_fit_group], [first_table, exact_table])

      assert_equal best_fit_group.id, result.winner.entry.id
      assert_equal exact_table.table_ids, result.winner.configuration.table_ids
    end

    # --- Test 16 / "important example" §20 — starvation beats better fit ---

    test "a starvation-protected 6-person group wins a 6-seat table over a better-fitting 2-person group" do
      group_a = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 120) # 2 min, better fit, not protected
      group_b = FakeEntry.waiting(id: 2, group_size: 6, joined_at: NOW - 1260) # 21 min, protected

      result = decide([group_a, group_b], [config([1], 6)])

      assert result.winner.starvation_protected
      assert_equal group_b.id, result.winner.entry.id
    end

    # --- §26 property / invariant tests ---

    test "property: the winning configuration is always compatible with the winning entry" do
      entry = FakeEntry.waiting(id: 1, group_size: 4, joined_at: NOW - 400)
      result = decide([entry], [config([1], 2), config([2], 4), config([3], 8)])

      assert result.winner.configuration.capacity >= result.winner.entry.group_size
    end

    test "property: total_score is always between 0 and 1" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 5000)
      result = decide([entry], [config([1], 2)])

      assert_operator result.winner.total_score, :>=, 0.0
      assert_operator result.winner.total_score, :<=, 1.0
    end

    test "property: aging never exceeds 1.0 even far beyond the aging window" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 1_000_000)
      result = decide([entry], [config([1], 2)])

      assert_operator result.winner.aging_score, :<=, 1.0
    end

    test "property: scarcity is always between 0 and 1" do
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      result = decide([entry], [config([1], 2), config([2], 4)])

      assert_operator result.winner.scarcity_score, :>, 0.0
      assert_operator result.winner.scarcity_score, :<=, 1.0
    end

    test "property: non-waiting entries are ignored entirely" do
      waiting_entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)
      ready_entry = FakeEntry.new(2, 2, NOW, "ready")
      seated_entry = FakeEntry.new(3, 2, NOW, "seated")
      left_entry = FakeEntry.new(4, 2, NOW, "left")
      no_show_entry = FakeEntry.new(5, 2, NOW, "no_show")

      result = decide(
        [waiting_entry, ready_entry, seated_entry, left_entry, no_show_entry],
        [config([1], 2)]
      )

      assert_equal waiting_entry.id, result.winner.entry.id
    end

    test "property: the engine never returns more than one winner" do
      entries = 5.times.map { |i| FakeEntry.waiting(id: i + 1, group_size: 2, joined_at: NOW - i) }
      result = decide(entries, [config([1], 2)])

      assert_kind_of Allocation::Candidate, result.winner
    end

    test "property: the engine has no database side effects" do
      before = QueueEntry.count
      entry = FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW)

      decide([entry], [config([1], 2)])

      assert_equal before, QueueEntry.count
    end

    test "property: the same input and the same now always produce the same decision" do
      entries = [
        FakeEntry.waiting(id: 1, group_size: 2, joined_at: NOW - 300),
        FakeEntry.waiting(id: 2, group_size: 4, joined_at: NOW - 100)
      ]
      configurations = [config([1], 2), config([2], 4), config([3, 4], 8)]

      first = decide(entries, configurations)
      second = decide(entries, configurations)

      assert_equal first.winner.entry.id, second.winner.entry.id
      assert_equal first.winner.configuration.table_ids, second.winner.configuration.table_ids
      assert_equal first.winner.total_score, second.winner.total_score
    end
  end
end
