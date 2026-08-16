module Staff
  # Implements functional-spec.md §6a / api-spec.md "POST /staff/seat" — seat
  # by code, confirmation only, never allocation. By the time this runs, the
  # table decision has already been made (Allocation::Orchestrator, a
  # previous request/read) — this service only validates and activates an
  # existing `pending` SeatingAssignment; it never calls
  # Allocation::DecisionEngine/ReservationService/Orchestrator, never
  # selects/reserves a table, never creates a SeatingAssignment or
  # SeatingAssignmentTable row, and never generates a new seating_code.
  #
  # Per functional-spec.md §6a step 2, this is *also* one of DEC-015's lazy-
  # expiration checkpoints (alongside Guest::CurrentQueueStatusService and,
  # as of Phase 5B.8, Staff::QueueViewService) — if the entry is still
  # `ready` in the database but its reservation is actually overdue (nobody
  # happened to read/write it since the deadline passed), this service must
  # expire it here (via the shared Allocation::LazyExpiration module) rather
  # than blindly confirming a stale hold. The expiration itself, unlike a
  # rejected confirmation attempt, is real and must commit — only the
  # confirmation is refused. This phase's own governing prompt §25 explicitly
  # forbids calling
  # Allocation::Orchestrator anywhere in this service, even from this
  # expiration branch — so the table this frees is NOT synchronously
  # reallocated here; it stays free until the next trigger (a future guest
  # join, or a future guest current-status read) picks it up, exactly as
  # DEC-015's "lazy, no delivery guarantee" model already allows. A
  # deliberate, documented scope boundary (see agent-decisions.md Session
  # 18), not an oversight.
  class ConfirmSeatingService
    Result = Struct.new(:outcome, :queue_entry, :seating_assignment, keyword_init: true)

    def self.call(seating_code:)
      new(seating_code: seating_code).call
    end

    def initialize(seating_code:)
      @seating_code = seating_code
    end

    def call
      return Result.new(outcome: :not_found) if @seating_code.blank?

      outcome = nil
      entry = nil
      assignment = nil

      ActiveRecord::Base.transaction do
        # Deterministic, single-path lock order: the entry (the seating_code
        # lookup key) first, then its own assignment — there is exactly one
        # relationship to traverse here, unlike ReservationService's
        # interchangeable table set, so no "sort by id" ordering question
        # arises.
        entry = QueueEntry.lock.find_by(seating_code: @seating_code)
        if entry.nil?
          outcome = :not_found
          raise ActiveRecord::Rollback
        end

        assignment = entry.current_seating_assignment&.tap(&:lock!)

        if Allocation::LazyExpiration.expire_if_overdue!(entry) # commits — this is real, not a rejected attempt
          outcome = :conflict
        else
          outcome = classify(entry, assignment)
          if outcome == :success
            assignment.update!(status: "active", activated_at: Time.current)
            entry.update!(status: "seated", seated_at: Time.current)
          else
            raise ActiveRecord::Rollback
          end
        end
      end

      Result.new(outcome: outcome, queue_entry: entry, seating_assignment: assignment)
    end

    private

    # A `seating_code` only ever exists on an entry that was, at some point,
    # `ready` (functional-spec.md §1/§6 — generated exactly once, on
    # entering `ready`, never regenerated or cleared). So a code that
    # resolves to `seated`/`left`/`no_show` is, by construction, always "a
    # reservation that WAS valid and is no longer" — api-spec.md's own
    # `conflict` bucket ("the entry's reservation expired... distinct from
    # unknown code") — never the generic `not_found` bucket a `waiting`
    # entry (which can never have a code at all) would fall into. See
    # ai-corrections.md CORR-008 for the full reasoning — api-spec.md's own
    # two error-case bullet lists genuinely disagreed on this before this
    # phase's fix.
    def classify(entry, assignment)
      case entry.status
      when "ready"
        assignment.present? && assignment.status == "pending" ? :success : :conflict
      when "seated"
        :already_confirmed
      when "left", "no_show"
        :conflict
      else # "waiting" — defensively handled; unreachable in practice, see comment above
        :not_found
      end
    end
  end
end
