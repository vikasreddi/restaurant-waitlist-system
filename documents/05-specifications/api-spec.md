# API Specification

Status: specification only. Exact route paths/verbs are illustrative for a Rails API-mode backend (DEC-012); the contract (inputs, outputs, error semantics) is the binding part of this document.

## Conventions

- All write endpoints return a distinguishable error shape for: `validation_error`, `not_found`, `conflict`, `internal_error`.
- All timestamps are server-generated, never client-supplied.
- Guest endpoints authenticate via the active-visit token, presented as `Authorization: Bearer <active_visit_token>` (fixed as of Phase 5B.4 — chosen over a query string or path segment specifically so the token never ends up in server/proxy access logs or browser history); staff endpoints authenticate via the staff session established at login.

## Guest endpoints

### `POST /guest/queue-entries` — Join

**Request:** `{ group_size, phone_number, idempotency_key }`. `idempotency_key` is a client-generated UUID; the client reuses the same value verbatim when retrying a failed/uncertain attempt, and generates a new one for a genuinely new join (`04-diagrams/06-guest-join-idempotency.md`).

**Response 201 (new entry):** `{ entry_id, active_visit_token, position, status: "waiting" }`

**Response 200 (idempotent replay):** same shape, referencing the pre-existing entry — not a new one (REQ-GUEST-007).

**Errors:**
- `validation_error` — invalid group size / phone number format, **or** group size exceeds every seatable configuration (no single table or adjacent combination can hold it) — rejected outright per DEC-011, with a message directing the group to speak to staff.
- `conflict` — the same `idempotency_key` was reused for a request with different `group_size`/`phone_number` than the original (not a valid retry — never silently updates the existing entry).
- `internal_error` — should never surface a partial entry.

**Implementation status (Phase 5B.3, `Guest::JoinService` / `Guest::QueueEntriesController`):**
- Implemented now: entry creation, `active_visit_token` generation, the full idempotency contract above (201 create / 200 replay / 409 conflict, including under real concurrency — the DB unique index on `idempotency_key` is the sole authority, not a Rails-level validation, per CORR-005), and `group_size > 0` / `phone_number` presence validation.
- **`position` is deliberately omitted from the 201/200 response body in this phase.** Position is a function of current queue/table state (DEC-005), which doesn't exist yet — no allocation service, no table-compatibility logic, and no `SeatingAssignment` creation exist as of Phase 5B.3 (explicitly out of scope for this phase). Returning a fabricated or hardcoded `position` would be worse than omitting it. It will be added once the allocation/position service (a later phase) exists.
- **The DEC-011 "group size exceeds every seatable configuration" rejection is also deferred**, for the same reason: evaluating it requires knowing which table configurations exist and are seatable, which is allocation-adjacent logic not yet built. Today, `validation_error` only fires for `group_size <= 0` or a blank `phone_number`.
- No `SeatingAssignment` or `SeatingAssignmentTable` row is ever created by this endpoint — a join always leaves the entry in `waiting` with zero associated seating assignments.

### `GET /guest/queue-entries/current` — View position / recover visit

**Auth:** active-visit token, `Authorization: Bearer <active_visit_token>`.

**Response 200 (`waiting`):** `{ entry_id, status: "waiting", position }`

**Response 200 (`ready`):** `{ entry_id, status: "ready", seating_code }` — no `position` field; the group has already been allocated a configuration and is waiting on staff confirmation, not on other groups. This read is itself a DEC-015 lazy-expiration checkpoint — if this entry's reservation is overdue, it's expired (→ `no_show`) before the response is built.

**Response 200 (terminal entry):** `{ status: "seated" | "left" | "no_show" }` — no live position field, since it no longer represents an active session (DEC-006).

**Response 404 / equivalent "no active visit":** when the token is missing/unknown — treated as "start a new join," not a server error. Deliberately identical for "missing," "malformed," and "doesn't match any entry" — there is no separate "token exists but belongs to someone else" response to leak, since lookup is solely by exact token match.

**Position semantics (Phase 5B.4, `Guest::CurrentQueueStatusService`):** `position` is a **chronological rank among currently-`waiting` entries only** — how many other groups are currently waiting and joined before this one, plus one. This is a deliberate, documented simplification for this phase, not the position model's final form. `functional-spec.md` §9 and DEC-005 define the *eventual* position as reflecting current table availability, compatibility, wait-time aging, and starvation-protection state (`seating-allocation-policy.md`, formalized with explicit formulas in `allocation-algorithm.md`, Phase 5B.5.1) — none of that is wired into this read yet (Phase 5B.5.2, the allocation service implementation). Returning a richer number now would mean fabricating allocation-priority data that hasn't actually been computed. **`position` is informational only and is never a guarantee of final seating order** — a later-joined but starvation-protected or better-fitting group can and will be seated ahead of a numerically "lower position" group once the allocation service exists, exactly as `seating-allocation-policy.md`/`starvation-policy.md`/`allocation-algorithm.md` describe. This will be replaced with the full DEC-005 computation in Phase 5B.5.2, not layered on top of the chronological number.

**Implementation status (Phase 5B.4, `Guest::CurrentQueueStatusService` / `Guest::QueueEntriesController#current`):**
- Implemented now: token-based lookup (indexed on `active_visit_token`, never phone/id/idempotency-key), all four response shapes above, the DEC-015 lazy-expiration checkpoint (an overdue `ready` entry is expired to `no_show` and its table(s) released, in the same transaction, before the response is built — via `SELECT ... FOR UPDATE` on the entry row, matching `domain-model-proposal.md` §11's existing concurrency plan; no background job), and the chronological-rank `position` described above.
- Deferred to Phase 5B.5: the full DEC-005 position computation (table availability/compatibility/aging/starvation-aware rank).

### `POST /guest/queue-entries/current/leave` — Leave

**Auth:** active-visit token, entry must be non-terminal.

**Response 200:** `{ status: "left" }`. Idempotent — repeat calls return the same terminal state without error.

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

**Response `not_found` / `validation_error`:**
- Unknown code.
- Code belongs to an entry that isn't currently `ready` — already `seated` (code already used), already terminal (`left`/`no_show`), or still `waiting` (shouldn't be possible if codes are only ever generated on entering `ready`, but validated defensively).

**Response `conflict`:**
- The entry's reservation expired (DEC-015) in the narrow window between the code being shown and staff submitting it — the request lands after the lazy-expiration check has already converted the entry to `no_show`. The entry is **not** silently returned to `waiting`; staff see a clear "reservation expired" message, distinct from "unknown code."
- The reservation was released by a concurrent operation for some other reason before this request's transaction committed — no partial allocation ever occurs (INV-005), and this endpoint never performs a *new* allocation attempt on conflict (unlike the old synchronous-allocation design) — it simply reports the conflict.

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
