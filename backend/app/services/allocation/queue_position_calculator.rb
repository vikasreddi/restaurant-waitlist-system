module Allocation
  # DEC-005 / functional-spec.md §9 / seating-allocation-policy.md "Relation-
  # ship to position": the guest-facing (and Staff Queue) `position` is a
  # rank derived from the SAME policy that governs real allocation — never a
  # simple `joined_at` count, and never a second, invented ranking formula
  # (this phase's own governing prompt §1/§2/§4).
  #
  # Reuses Allocation::DecisionEngine.decide, unmodified, as the sole scoring
  # authority — simulated purely in memory, entirely read-only (never calls
  # Allocation::ReservationService/Allocation::Orchestrator, never writes to
  # the database): allocation-algorithm.md §12's own `run_allocation_pass`
  # repeat-until-exhausted loop (Allocation::Orchestrator's real,
  # database-writing counterpart) is mirrored here in memory only — each
  # simulated round asks "who would win right now, given what's already
  # been simulated as taken," removes that entry and its configuration's
  # table(s) from the pool, and repeats. This is the direct generalization
  # of "pick the one best candidate" (what DecisionEngine already does) to
  # "produce the full priority order" — not a new algorithm.
  #
  # Table/configuration state and the waiting-entry list are each snapshotted
  # exactly once (this phase's own governing prompt §8: "one snapshot... no
  # N+1") — every simulated round after the first operates purely on
  # in-memory Ruby arrays, no further database queries.
  #
  # An entry that never wins any simulated round — no free configuration is
  # ever compatible with it, either directly or because higher-priority
  # entries consume every compatible configuration first — is ranked after
  # every entry that does win a round. allocation-algorithm.md §9 is
  # explicit that starvation protection only applies "once the complete
  # configuration is available"; an entry with no available configuration at
  # all has no live starvation guarantee to assert here. Among themselves,
  # such leftover entries are ordered by starvation status then `joined_at`
  # — the only two factors that remain meaningful without a configuration to
  # score fit/scarcity against (documented judgment call, agent-decisions.md
  # Session 27 — the specification does not fully resolve this sub-case).
  class QueuePositionCalculator
    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now:)
      @now = now
    end

    # Returns { queue_entry_id => 1-based position }, for every currently
    # `waiting` entry. Never mutates a QueueEntry, never creates a
    # SeatingAssignment/SeatingAssignmentTable, never touches Table rows.
    def call
      remaining_entries = QueueEntry.where(status: "waiting").to_a
      remaining_configurations = ConfigurationGenerator.call

      ranked_ids = []

      loop do
        result = DecisionEngine.decide(
          waiting_entries: remaining_entries,
          configurations: remaining_configurations,
          now: @now
        )
        break unless result.winner?

        winner = result.winner
        ranked_ids << winner.entry.id
        remaining_entries = remaining_entries.reject { |entry| entry.id == winner.entry.id }
        claimed_table_ids = winner.configuration.table_ids
        remaining_configurations = remaining_configurations.reject do |configuration|
          (configuration.table_ids & claimed_table_ids).any?
        end
      end

      leftover_ids = remaining_entries.sort_by do |entry|
        [starvation_protected?(entry) ? 0 : 1, entry.joined_at.to_f, entry.id]
      end.map(&:id)

      (ranked_ids + leftover_ids).each_with_index.to_h { |id, index| [id, index + 1] }
    end

    private

    # Same formula as Allocation::DecisionEngine#starvation_protected? and
    # Staff::QueueViewService#starvation_protected? — a two-line comparison
    # against the shared Policy constant, not a second implementation of any
    # scoring logic (the same duplication this project already accepted for
    # the identical formula in Staff::QueueViewService, agent-decisions.md
    # Session 22).
    def starvation_protected?(entry)
      (@now - entry.joined_at) >= Policy::STARVATION_THRESHOLD_SECONDS
    end
  end
end
