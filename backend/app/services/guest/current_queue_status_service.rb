module Guest
  # Implements functional-spec.md §2 (view position / recover visit). Resolves
  # an active_visit_token to its QueueEntry and, per §2/§8a (DEC-015), applies
  # the lazy READY-expiration check inline before building the response — this
  # read is one of DEC-015's explicit lazy-expiration checkpoints, not a
  # background job. The check itself is Allocation::LazyExpiration (extracted
  # in Phase 5B.8 once Staff::QueueViewService became a third call site — see
  # that module's own comment for the full history).
  #
  # As of Phase 5B.5.4: when this check actually fires (an overdue `ready`
  # entry expires to `no_show` and its table(s) are released), that release
  # is one of the four approved allocation triggers (this phase's governing
  # prompt §9/§15/§17 — "READY expiration... after that committed release:
  # allocation may run"). Allocation::Orchestrator is invoked strictly AFTER
  # the expiration transaction below has committed, in its own separate
  # transaction(s), never nested inside it (§10/§11) — and only when
  # expiration actually happened, never on an ordinary read of a still-valid
  # `ready`/`waiting`/terminal entry.
  #
  # Explicitly NOT this service's job (Phase 5B.5): compatibility scoring,
  # weighted aging, starvation scoring, table matching, or any other
  # allocation-priority computation. `position` here is a simple chronological
  # rank among currently-waiting entries — see #position_for below and
  # api-spec.md's "Position semantics" note for why that's a deliberate,
  # documented simplification, not the final allocation priority.
  class CurrentQueueStatusService
    Result = Struct.new(:outcome, :queue_entry, :position, keyword_init: true)

    def self.call(active_visit_token:)
      new(active_visit_token: active_visit_token).call
    end

    def initialize(active_visit_token:)
      @active_visit_token = active_visit_token
    end

    def call
      return Result.new(outcome: :not_found) if @active_visit_token.blank?

      entry = nil
      expired = false

      QueueEntry.transaction do
        entry = QueueEntry.lock.find_by(active_visit_token: @active_visit_token)
        expired = Allocation::LazyExpiration.expire_if_overdue!(entry) if entry
      end

      return Result.new(outcome: :not_found) if entry.nil?

      Allocation::Orchestrator.call(now: Time.current) if expired

      Result.new(
        outcome: :found,
        queue_entry: entry,
        position: entry.status == "waiting" ? position_for(entry) : nil
      )
    end

    private

    # Deliberately simple (Phase 5B.4 boundary): a chronological rank among
    # entries currently `waiting`, using the existing [status, joined_at]
    # index. Informational only — does not account for table compatibility,
    # availability, wait-time aging weighting, or starvation protection (all
    # deferred to the allocation service, seating-allocation-policy.md,
    # Phase 5B.5). Never presented as a guarantee of final seating order.
    def position_for(entry)
      QueueEntry.where(status: "waiting").where("joined_at < ?", entry.joined_at).count + 1
    end
  end
end
