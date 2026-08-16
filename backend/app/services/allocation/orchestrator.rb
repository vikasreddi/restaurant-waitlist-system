module Allocation
  # Repeats Allocation::ReservationService (unchanged, unmodified) until no
  # further allocation is possible — allocation-algorithm.md §12's
  # `run_allocation_pass` loop, implemented as thin composition over the
  # already-tested components (this phase's own governing prompt §4: "Do NOT
  # put scoring logic into the orchestrator. Do NOT put database reservation
  # logic into the orchestrator. It should compose existing components.").
  #
  # Every pass calls ReservationService.call fresh — since ReservationService
  # itself already re-queries waiting entries and available configurations
  # from the database on every single call (no candidate list is ever cached
  # anywhere, in this class or in ReservationService), each pass necessarily
  # sees post-previous-pass state: newly-consumed tables, newly-changed
  # scarcity, newly-changed starvation status. There is no separate "refresh"
  # step to get wrong — freshness is structural, not a manual re-fetch this
  # class has to remember to perform.
  class Orchestrator
    # Not a business rule — a defensive bound against a busy-loop under
    # genuine external concurrency (a different request's own orchestrator
    # or lazy-expiration racing for the same resources at the same time).
    # Resets to zero on every real success, so it never limits ordinary
    # multi-allocation behavior — only repeated, progress-free contention.
    MAX_CONSECUTIVE_STALE_RESULTS = 5

    Summary = Struct.new(:allocations_count, :allocated_queue_entry_ids, :assignment_ids, keyword_init: true)

    def self.call(now: Time.current)
      new(now: now).call
    end

    # `now` is captured once and reused for every pass within this single
    # orchestration run (not re-read via Time.current per pass) — a single
    # run is expected to complete in a handful of fast DB round-trips, and a
    # fixed `now` avoids a group's starvation-protected/aging status flipping
    # mid-run purely from wall-clock drift, which would be a non-reproducible
    # artifact nothing in seating-allocation-policy.md/starvation-policy.md
    # asks for. See 06-ai-working-record/agent-decisions.md, Session 17, for
    # the full reasoning — this is a documented implementation choice, not a
    # new starvation policy.
    def initialize(now:)
      @now = now
    end

    def call
      allocated_queue_entry_ids = []
      assignment_ids = []
      consecutive_stale = 0

      loop do
        result = ReservationService.call(now: @now)

        case result.outcome
        when :success
          allocated_queue_entry_ids << result.queue_entry.id
          assignment_ids << result.seating_assignment.id
          consecutive_stale = 0
        when :no_candidate
          break
        when :stale_candidate
          consecutive_stale += 1
          break if consecutive_stale >= MAX_CONSECUTIVE_STALE_RESULTS
        else
          # ReservationService only ever returns :success/:no_candidate/
          # :stale_candidate (genuinely unexpected DB errors already
          # propagate as raised exceptions, not as a Result variant) — this
          # branch exists purely so an unrecognized outcome fails loudly
          # (this phase's own §5/§20: "do not hide unexpected failures")
          # rather than being silently treated as "done."
          raise "Unexpected Allocation::ReservationService outcome: #{result.outcome.inspect}"
        end
      end

      Summary.new(
        allocations_count: allocated_queue_entry_ids.size,
        allocated_queue_entry_ids: allocated_queue_entry_ids,
        assignment_ids: assignment_ids
      )
    end
  end
end
