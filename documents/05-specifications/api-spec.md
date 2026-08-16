# API Specification

Status: specification only. Exact route paths/verbs are illustrative for a Rails API-mode backend (DEC-012); the contract (inputs, outputs, error semantics) is the binding part of this document.

## Conventions

- All write endpoints return a distinguishable error shape for: `validation_error`, `not_found`, `conflict`, `internal_error`.
- All timestamps are server-generated, never client-supplied.
- Guest endpoints authenticate via the active-visit token, presented as `Authorization: Bearer <active_visit_token>` (fixed as of Phase 5B.4 — chosen over a query string or path segment specifically so the token never ends up in server/proxy access logs or browser history); staff endpoints authenticate via the staff session established at login.

## Guest endpoints

### `POST /guest/queue-entries` — Join

**Request:** `{ group_size, phone_number, idempotency_key }`. `idempotency_key` is a client-generated UUID; the client reuses the same value verbatim when retrying a failed/uncertain attempt, and generates a new one for a genuinely new join (`04-diagrams/06-guest-join-idempotency.md`).

**Response 201 (new entry):** `{ entry_id, active_visit_token, position, status }` — `status` reflects the entry's actual live state at the moment the response is built, not a fixed `"waiting"`: as of Phase 5B.5.4, a new join can synchronously trigger allocation (see "Implementation status" below), so `status` may be `"ready"` in the same response if a compatible table configuration was already available. The response shape itself is unchanged — no `seating_code` or table information is added to this endpoint even when `status` is `"ready"`; a guest whose join synchronously became `ready` gets their `seating_code` the same way any other `ready` guest does, via `GET /guest/queue-entries/current`.

**Response 200 (idempotent replay):** same shape, referencing the pre-existing entry — not a new one (REQ-GUEST-007). Reflects whatever the entry's current status already is; a replay never re-triggers allocation (see "Implementation status" below).

**Errors:**
- `validation_error` — invalid group size / phone number format, **or** group size exceeds every seatable configuration (no single table or adjacent combination can hold it) — rejected outright per DEC-011, with a message directing the group to speak to staff.
- `conflict` — the same `idempotency_key` was reused for a request with different `group_size`/`phone_number` than the original (not a valid retry — never silently updates the existing entry).
- `internal_error` — should never surface a partial entry.

**Implementation status (Phase 5B.3, `Guest::JoinService` / `Guest::QueueEntriesController`):**
- Implemented now: entry creation, `active_visit_token` generation, the full idempotency contract above (201 create / 200 replay / 409 conflict, including under real concurrency — the DB unique index on `idempotency_key` is the sole authority, not a Rails-level validation, per CORR-005), and `group_size > 0` / `phone_number` presence validation.
- **`position` is deliberately omitted from the 201/200 response body in this phase.** Position is a function of current queue/table state (DEC-005), which doesn't exist yet — no allocation service, no table-compatibility logic, and no `SeatingAssignment` creation exist as of Phase 5B.3 (explicitly out of scope for this phase). Returning a fabricated or hardcoded `position` would be worse than omitting it. It will be added once the allocation/position service (a later phase) exists.
- **The DEC-011 "group size exceeds every seatable configuration" rejection is also deferred**, for the same reason: evaluating it requires knowing which table configurations exist and are seatable, which is allocation-adjacent logic not yet built. Today, `validation_error` only fires for `group_size <= 0` or a blank `phone_number`.
- No `SeatingAssignment` or `SeatingAssignmentTable` row is ever created by this endpoint — a join always leaves the entry in `waiting` with zero associated seating assignments.

**Implementation status (Phase 5B.5.4, `Allocation::Orchestrator` integration):** a genuinely NEW join (never an idempotent replay or conflict) now triggers `Allocation::Orchestrator` immediately after the entry's creation commits — if a compatible table configuration is currently available, the entry may synchronously become `ready` (a `pending` `SeatingAssignment` created, `seating_code` generated) before this endpoint returns; `Allocation::Orchestrator` returning `:no_candidate` (nothing available) is the normal, non-error case, and the entry simply stays `waiting`. An idempotent replay never re-triggers the orchestrator — the response reflects whatever the entry's current status already is, never a second allocation attempt.

### `GET /guest/queue-entries/current` — View position / recover visit

**Auth:** active-visit token, `Authorization: Bearer <active_visit_token>`.

**Response 200 (`waiting`):** `{ entry_id, status: "waiting", position }`

**Response 200 (`ready`):** `{ entry_id, status: "ready", seating_code }` — no `position` field; the group has already been allocated a configuration and is waiting on staff confirmation, not on other groups. This read is itself a DEC-015 lazy-expiration checkpoint — if this entry's reservation is overdue, it's expired (→ `no_show`) before the response is built.

**Response 200 (terminal entry):** `{ status: "seated" | "left" | "no_show" }` — no live position field, since it no longer represents an active session (DEC-006).

**Response 404 / equivalent "no active visit":** when the token is missing/unknown — treated as "start a new join," not a server error. Deliberately identical for "missing," "malformed," and "doesn't match any entry" — there is no separate "token exists but belongs to someone else" response to leak, since lookup is solely by exact token match.

**Position semantics (Phase 5B.4, `Guest::CurrentQueueStatusService`):** `position` is a **chronological rank among currently-`waiting` entries only** — how many other groups are currently waiting and joined before this one, plus one. This is a deliberate, documented simplification for this phase, not the position model's final form. `functional-spec.md` §9 and DEC-005 define the *eventual* position as reflecting current table availability, compatibility, wait-time aging, and starvation-protection state (`seating-allocation-policy.md`, formalized with explicit formulas in `allocation-algorithm.md`, Phase 5B.5.1) — none of that is wired into this read yet (Phase 5B.5.2, the allocation service implementation). Returning a richer number now would mean fabricating allocation-priority data that hasn't actually been computed. **`position` is informational only and is never a guarantee of final seating order** — a later-joined but starvation-protected or better-fitting group can and will be seated ahead of a numerically "lower position" group once the allocation service exists, exactly as `seating-allocation-policy.md`/`starvation-policy.md`/`allocation-algorithm.md` describe. This will be replaced with the full DEC-005 computation in Phase 5B.5.2, not layered on top of the chronological number.

**Implementation status (Phase 5B.4, `Guest::CurrentQueueStatusService` / `Guest::QueueEntriesController#current`):**
- Implemented now: token-based lookup (indexed on `active_visit_token`, never phone/id/idempotency-key), all four response shapes above, the DEC-015 lazy-expiration checkpoint (an overdue `ready` entry is expired to `no_show` and its table(s) released, in the same transaction, before the response is built — via `SELECT ... FOR UPDATE` on the entry row, matching `domain-model-proposal.md` §11's existing concurrency plan; no background job), and the chronological-rank `position` described above.
- **Phase 5B.5.4:** when the lazy-expiration checkpoint actually fires, `Allocation::Orchestrator` runs immediately afterward (in its own separate transaction, once the expiration's release has committed) to fill the newly-freed table(s) for whichever waiting group is next — this endpoint's own response is unaffected (it always reflects the requesting guest's own now-`no_show` state), but another guest's `waiting` entry may synchronously become `ready` as a side effect of this read. On an ordinary read that doesn't trigger expiration, no allocation runs.
- Deferred to Phase 5B.5: the full DEC-005 position computation (table availability/compatibility/aging/starvation-aware rank).

### `POST /guest/queue-entries/current/leave` — Leave

**Auth:** active-visit token, `Authorization: Bearer <active_visit_token>`, entry must be non-terminal.

**Response 200:** `{ status: "left" }`. Idempotent — repeat calls return the same terminal state without error. Per `functional-spec.md` §3, "idempotent" is deliberately broader than "already left": leaving an entry that reached *any* terminal state (`left`, `seated`, or `no_show`) through any path is a safe no-op — the response reflects that entry's real current status, never force-reporting `"left"` for a guest who was, say, actually already seated.

**Implementation status (Phase 5B.7 — P0 completion mode, `Guest::LeaveService` / `Guest::QueueEntriesController#leave`):**
- Implemented now: token-based lookup (same rule as `current` — never phone/id/idempotency-key), `waiting → left` and `ready → left`, atomic release of the entry's `pending` `SeatingAssignment` (and its `SeatingAssignmentTable` row(s), `released_at` set, never deleted) when leaving from `ready`, and `Allocation::Orchestrator` invoked immediately afterward — but **only when a table was actually released** (a `waiting` leave never touches a table, so triggering allocation for it would be a guaranteed no-op; mirrors the existing conditional lazy no-show trigger, Phase 5B.5.4, rather than calling the orchestrator unconditionally).
- Verified end-to-end: a real waiting guest and a real ready guest (with a real reserved table) both leaving via the actual HTTP endpoint against the real database; a second, previously-waiting guest correctly allocated the table the first guest's leave released.
- No DEC-015 lazy-expiration re-check is performed inside this endpoint (unlike `current` and `POST /staff/seat`) — `functional-spec.md` §3 does not name leave as one of DEC-015's checkpoints, unlike §2/§6a's explicit mentions; a guest leaving a `ready` reservation that happens to already be past its deadline is simply recorded as guest-initiated `left` (the table is released correctly either way, only the specific terminal status/timestamp differs from what a lazy-expiration check would have produced).

## Staff endpoints

### `POST /staff/login`

**Request:** `{ email, password }`

**Response 200:** session established (mechanism TBD, e.g., cookie or bearer token — stub-strength per REQ-STAFF-001).

**Response 401:** generic authentication failure, no user enumeration.

### `GET /staff/queue`

**Auth:** staff session.

**Response 200:** list of `waiting` entries (`{ entry_id, group_size, joined_at, position, is_starvation_protected }`) and `ready` entries (`{ entry_id, group_size, ready_at, seating_code }`, no `position`) — staff can see which groups are already reserved and waiting on confirmation, distinct from those still in line. This read is a DEC-015 lazy-expiration checkpoint for any `ready` entries it touches.

### `GET /staff/tables`

**Auth:** staff session.

**Response 200:** list of tables with `{ table_id, capacity, status, current_queue_entry_id (if held/occupied), seating_assignment_id (if held/occupied) }` — `status` (`free`/`held`/`occupied`) is derived at read time (`03-architecture/domain-model.md` §2), not a stored table field. `held` means claimed by a `pending` assignment (a `ready` group awaiting confirmation); `occupied` means claimed by an `active` one (`seated`). `seating_assignment_id` replaces the old `combination_id` and applies uniformly whether the assignment covers one table or two.

### `POST /staff/seat` — Seat by code (confirmation, not allocation)

**Behavior note:** by the time this endpoint is called, the table decision has already been made — the allocation service reserved a configuration and generated the code at `waiting → ready` time (`functional-spec.md` §6). This endpoint only validates and confirms an existing reservation; it never runs the allocation algorithm itself.

**Request:** `{ seating_code }`

**Response 200 (success):** `{ entry_id, status: "seated", table_ids: [...] }`

**Response `not_found`:**
- Unknown code.
- Code belongs to an entry that is still `waiting` (should be unreachable in practice — a `seating_code` is only ever set on entering `ready`, so a `waiting` entry can never have one — validated defensively regardless).

**Response `conflict`:**
- **Already confirmed:** the code belongs to an entry that is already `seated` (this exact code was already used) — a repeated confirmation, not a genuine error; distinct from "unknown code" precisely because the code *did* work, once.
- **No longer valid:** the code belongs to an entry that is now `left` or `no_show`. Since a `seating_code` only ever exists on an entry that was `ready` at some point (never generated for, or cleared from, any other state), any `left`/`no_show` entry found this way is, by construction, always "a reservation that WAS valid and has since ended" (the guest left before staff could confirm, or — DEC-015 — the reservation expired in the narrow window between the code being shown and staff submitting it, converted to `no_show` by the lazy-expiration check). The entry is **not** silently returned to `waiting`; staff see a clear "no longer valid" message, distinct from "unknown code." (Corrected — CORR-008: an earlier version of this section put "already terminal (`left`/`no_show`)" under `not_found`/`validation_error` instead, directly contradicting this same section's own `conflict` bullet for the identical DEC-015 scenario.)
- **Inconsistent/released assignment:** the entry is `ready` but its backing `SeatingAssignment` is not (or no longer) `pending` — released by a concurrent operation before this request's transaction committed. No partial allocation ever occurs (INV-005), and this endpoint never performs a *new* allocation attempt on conflict (unlike the old synchronous-allocation design) — it simply reports the conflict.

**Implementation status (Phase 5B.6, `Staff::ConfirmSeatingService` / `Staff::SeatController`):**
- Implemented now: `seating_code` lookup (via the existing partial unique index, never by `QueueEntry` id/phone/token/idempotency-key), row locking (`QueueEntry` then its own `SeatingAssignment`, a fixed single-path order), the atomic `ready`+`pending → seated`+`active` transition, all documented error cases above, verified under real PostgreSQL concurrency (exactly one of two simultaneous requests for the same code succeeds, the other observes `already_confirmed`).
- **No staff authentication.** No session/login mechanism exists anywhere in this codebase yet (`StaffUser` has `has_secure_password` but no login endpoint — deferred every phase since 5B.2). This endpoint is therefore callable by anyone who can reach it, with no session check. This is a known, explicitly-documented gap for this phase (per this phase's own governing prompt §15: "do NOT create a complete authentication system... clearly report authentication status"), not a silent omission — staff login/session enforcement is deferred to whichever future phase builds `POST /staff/login`.
- Never allocates, never selects/reserves a table, never creates a `SeatingAssignment`/`SeatingAssignmentTable` row, never generates a new `seating_code` — `Allocation::DecisionEngine`/`ReservationService`/`Orchestrator` are never called from this endpoint.

### `POST /staff/seating-assignments/release` — Release seating assignment

**Request:** `{ entry_id }` — the seated `QueueEntry`. There is **no** `table_id` or `combination_id` parameter; the server resolves internally whether the entry holds a single table or a combined pair and releases the complete assignment atomically (DEC-014, INV-015) — a caller cannot release only half of a combined pair.

**Response 200:** `{ entry_id, table_ids_released: [...] }` — table(s) now `free`; if a combination, both members freed and the combination dissolved (INV-006).

**Idempotent:** releasing an already-released entry returns 200 with no state change, not an error.

### `POST /staff/queue/no-show` — Mark no-show

**Request:** `{ entry_id }`

**Response 200:** `{ entry_id, status: "no_show" }`. Idempotent against an already-terminal entry.

## P1-only surface (not built until P0 stable)

- Live-update channel (`GET /guest/queue-entries/current/stream` or polling, per OPEN-002).
- `GET /health`, `GET /metrics` for observability (REQ-SHOW-004).

## Explicitly not exposed

- No endpoint to list/query other guests' entries from the guest side.
- No table-layout mutation endpoints.
