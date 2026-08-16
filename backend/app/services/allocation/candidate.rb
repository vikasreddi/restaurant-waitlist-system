module Allocation
  # One (entry, configuration) pairing with its computed scores
  # (allocation-algorithm.md §6-§11). Built and ranked by DecisionEngine;
  # never mutated after construction.
  Candidate = Struct.new(
    :entry, :configuration, :fit_score, :scarcity_score, :aging_score,
    :total_score, :starvation_protected,
    keyword_init: true
  )
end
