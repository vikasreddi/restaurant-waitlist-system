module Allocation
  # Centralized, ENV-tunable configuration for the allocation decision engine
  # (documents/05-specifications/allocation-algorithm.md §19) — mirrors the
  # existing SeatingAssignment::READY_TIMEOUT idiom (Phase 5B.2) rather than
  # introducing a second configuration mechanism.
  #
  # These defaults are locked by allocation-algorithm.md. Do not change them
  # here to "improve" the algorithm — a genuine disagreement with the
  # specification is a BLOCKED/human-review case (this phase's governing
  # prompt §3/§33), not a code-time judgment call.
  module Policy
    FIT_WEIGHT = ENV.fetch("ALLOCATION_FIT_WEIGHT", "0.4").to_f
    SCARCITY_WEIGHT = ENV.fetch("ALLOCATION_SCARCITY_WEIGHT", "0.3").to_f
    AGING_WEIGHT = ENV.fetch("ALLOCATION_AGING_WEIGHT", "0.3").to_f

    # Plain integer seconds, not an ActiveSupport::Duration (unlike
    # SeatingAssignment::READY_TIMEOUT) — these are divided against a raw
    # elapsed-seconds Float in DecisionEngine#aging_score, so a plain numeric
    # is the more direct fit here than a Duration.
    STARVATION_THRESHOLD_SECONDS = ENV.fetch("STARVATION_THRESHOLD_SECONDS", 1200).to_i
    MAX_AGING_WINDOW_SECONDS = ENV.fetch("MAX_AGING_WINDOW_SECONDS", 1200).to_i
  end
end
