module Guest
  # Thin controller: HTTP in, HTTP out. All idempotency/creation logic lives in
  # Guest::JoinService (functional-spec.md §1, api-spec.md).
  class QueueEntriesController < ApplicationController
    def create
      result = JoinService.call(
        group_size: join_params[:group_size],
        phone_number: join_params[:phone_number],
        idempotency_key: join_params[:idempotency_key]
      )

      case result.outcome
      when :created
        render json: entry_json(result.queue_entry), status: :created
      when :idempotent_replay
        render json: entry_json(result.queue_entry), status: :ok
      when :conflict
        render json: error_json(
          "conflict",
          "This idempotency key was already used for a different request."
        ), status: :conflict
      when :validation_error
        render json: error_json(
          "validation_error",
          "Invalid join request.",
          result.errors.to_hash(true)
        ), status: :unprocessable_content
      end
    end

    # GET /guest/queue-entries/current (functional-spec.md §2, api-spec.md).
    # Identifies the visit solely via the active_visit_token — never by phone
    # number, database id, or idempotency key (this phase's governing prompt
    # §7). A missing or unknown token is treated identically as "no active
    # visit" (404) — deliberately not distinguished from "token belongs to
    # someone else," since there is no ownership concept beyond exact token
    # match to leak in the first place.
    def current
      result = CurrentQueueStatusService.call(active_visit_token: bearer_token)

      if result.outcome == :not_found
        render json: error_json("not_found", "No active visit found for this token."), status: :not_found
        return
      end

      render json: current_status_json(result), status: :ok
    end

    # POST /guest/queue-entries/current/leave (functional-spec.md §3,
    # api-spec.md). Same token-only identification rule as #current. Always
    # 200 on a resolvable token — leaving is idempotent/safe-no-op by design,
    # never an error for an already-terminal entry (LeaveService itself
    # decides whether anything actually changes).
    def leave
      result = LeaveService.call(active_visit_token: bearer_token)

      if result.outcome == :not_found
        render json: error_json("not_found", "No active visit found for this token."), status: :not_found
        return
      end

      render json: { status: result.queue_entry.status }, status: :ok
    end

    private

    def join_params
      params.permit(:group_size, :phone_number, :idempotency_key)
    end

    # No position (not implemented until the allocation service exists — this
    # phase's governing prompt §18 explicitly defers it), no table/seating
    # information (none exists yet), no internal fields beyond the entry's own
    # id (which is not usable to access anyone else's entry — lookups are only
    # ever by active_visit_token, never by entry_id).
    def entry_json(entry)
      { entry_id: entry.id, active_visit_token: entry.active_visit_token, status: entry.status }
    end

    # Transport fixed as of Phase 5B.4 (api-spec.md previously left this an
    # "implementation-phase detail, not yet fixed"): `Authorization: Bearer
    # <active_visit_token>` — never the query string or a path segment, so the
    # token doesn't end up in server/proxy access logs or browser history.
    def bearer_token
      header = request.headers["Authorization"].to_s
      match = header.match(/\ABearer\s+(.+)\z/i)
      match && match[1]
    end

    # Response shape follows api-spec.md's `GET /guest/queue-entries/current`
    # exactly: `waiting` gets a position, `ready` gets a seating_code instead
    # (no position — it's no longer competing against other waiting groups),
    # and every terminal status (`seated`/`left`/`no_show`) returns only its
    # status, deliberately with no entry_id and no live position field (the
    # visit is no longer an active session, DEC-006). Never table ids,
    # SeatingAssignment ids, or any other guest's data.
    def current_status_json(result)
      entry = result.queue_entry
      case entry.status
      when "waiting"
        { entry_id: entry.id, status: "waiting", position: result.position }
      when "ready"
        { entry_id: entry.id, status: "ready", seating_code: entry.seating_code }
      else
        { status: entry.status }
      end
    end

    def error_json(type, message, details = nil)
      { error: { type: type, message: message, details: details }.compact }
    end
  end
end
