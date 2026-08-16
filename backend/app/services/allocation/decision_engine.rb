module Allocation
  # The pure decision-making core of allocation — documents/05-specifications/
  # allocation-algorithm.md, implemented verbatim (formulas and defaults are
  # locked; see Policy for why they live there instead of here). Given the
  # current waiting entries and available table configurations, decides the
  # single best (entry, configuration) pairing, or none.
  #
  # No database reads or writes happen in this class — it never calls save!,
  # update!, create!, destroy!, or touches ActiveRecord at all. See
  # Allocation::ConfigurationGenerator for the separate, non-pure piece that
  # turns live Table/TableAdjacency rows into the TableConfiguration objects
  # this engine consumes; the entries passed in are read-only here too (only
  # #id, #group_size, #joined_at, #status are ever called).
  #
  # Deliberately NOT this class's job (later phase): locking tables, creating
  # SeatingAssignment/SeatingAssignmentTable rows, transitioning a QueueEntry
  # to ready, generating a seating_code, or repeating this decision in a loop
  # after a transaction commits (allocation-algorithm.md §12's
  # `run_allocation_pass` — this class is only its inner "choose one winner"
  # step, called once per #decide).
  class DecisionEngine
    Result = Struct.new(:winner, keyword_init: true) do
      def winner?
        !winner.nil?
      end
    end

    def self.decide(waiting_entries:, configurations:, now:)
      new(waiting_entries: waiting_entries, configurations: configurations, now: now).decide
    end

    def initialize(waiting_entries:, configurations:, now:)
      # Defensive filter, not a trust-the-caller assumption: a ready/seated/
      # left/no_show entry must never enter the candidate pool (this phase's
      # governing prompt §5).
      @waiting_entries = waiting_entries.select { |entry| entry.status == "waiting" }
      @configurations = configurations
      @now = now
    end

    def decide
      candidates = build_candidates
      return Result.new(winner: nil) if candidates.empty?

      pool = starvation_pool(candidates)
      Result.new(winner: pool.max_by { |candidate| ranking_key(candidate) })
    end

    private

    def build_candidates
      candidates = []
      @waiting_entries.each do |entry|
        compatible_configurations = @configurations.select { |configuration| compatible?(entry, configuration) }
        compatible_configurations.each do |configuration|
          candidates << build_candidate(entry, configuration, compatible_configurations.size)
        end
      end
      candidates
    end

    # allocation-algorithm.md §3 — hard gate. No score/weight/aging/starvation
    # value can ever make an incompatible pair eligible.
    def compatible?(entry, configuration)
      configuration.capacity >= entry.group_size
    end

    def build_candidate(entry, configuration, compatible_configuration_count)
      fit = fit_score(entry, configuration)
      scarcity = scarcity_score(compatible_configuration_count)
      aging = aging_score(entry)

      Candidate.new(
        entry: entry,
        configuration: configuration,
        fit_score: fit,
        scarcity_score: scarcity,
        aging_score: aging,
        total_score: total_score(fit, scarcity, aging),
        starvation_protected: starvation_protected?(entry)
      )
    end

    # allocation-algorithm.md §6 — exact fit formula, not to be inverted or
    # given arbitrary bonuses.
    def fit_score(entry, configuration)
      entry.group_size.to_f / configuration.capacity
    end

    # allocation-algorithm.md §7 — per-entry, recomputed every call from the
    # actual configurations passed in this call (never a static assumption).
    def scarcity_score(compatible_configuration_count)
      1.0 / compatible_configuration_count
    end

    # allocation-algorithm.md §8 — linear from 0.0 at join, hard-capped at 1.0.
    def aging_score(entry)
      waiting_seconds = @now - entry.joined_at
      [waiting_seconds / Policy::MAX_AGING_WINDOW_SECONDS, 1.0].min
    end

    def total_score(fit, scarcity, aging)
      (Policy::FIT_WEIGHT * fit) + (Policy::SCARCITY_WEIGHT * scarcity) + (Policy::AGING_WEIGHT * aging)
    end

    # allocation-algorithm.md §9 — derived, never stored; no column, no
    # schedule, no background job.
    def starvation_protected?(entry)
      (@now - entry.joined_at) >= Policy::STARVATION_THRESHOLD_SECONDS
    end

    # allocation-algorithm.md §9/§12 — categorical override, not an additive
    # bonus: if any eligible candidate is starvation-protected, only
    # protected candidates are ranked at all.
    def starvation_pool(candidates)
      protected_candidates = candidates.select(&:starvation_protected)
      protected_candidates.empty? ? candidates : protected_candidates
    end

    # allocation-algorithm.md §14 — lexicographic, highest wins at each
    # level before falling to the next: (1) total_score, (2) fewer tables
    # consumed, (3) earlier joined_at, (4) lower id. No randomness, no
    # phone/token/table-name/insertion-order tie-breakers.
    def ranking_key(candidate)
      [
        candidate.total_score,
        candidate.configuration.table_count == 1 ? 1 : 0,
        -candidate.entry.joined_at.to_f,
        -candidate.entry.id
      ]
    end
  end
end
