# API Specification

Status: specification only. Exact route paths/verbs are illustrative for a Rails API-mode backend (DEC-012); the contract (inputs, outputs, error semantics) is the binding part of this document.

## Conventions

- All write endpoints return a distinguishable error shape for: `validation_error`, `not_found`, `conflict`, `internal_error`.
- All timestamps are server-generated, never client-supplied.
- Guest endpoints authenticate via the active-visit token (transport — header, cookie, or path — is an implementation-phase detail, not yet fixed); staff endpoints authenticate via the staff session established at login.

## Guest endpoints

### `POST /guest/queue-entries` — Join

**Request:** `{ group_size, phone_number, idempotency_key }`. `idempotency_key` is a client-generated UUID; the client reuses the same value verbatim when retrying a failed/uncertain attempt, and generates a new one for a genuinely new join (`04-diagrams/06-guest-join-idempotency.md`).

**Response 201 (new entry):** `{ entry_id, active_visit_token, position, status: "waiting" }`

**Response 200 (idempotent replay):** same shape, referencing the pre-existing entry — not a new one (REQ-GUEST-007).

**Errors:**
- `validation_error` — invalid group size / phone number format, **or** group size exceeds every seatable configuration (no single table or adjacent combination can hold it) — rejected outright per DEC-011, with a message directing the group to speak to staff.
- `internal_error` — should never surface a partial entry.

### `GET /guest/queue-entries/current` — View position / recover visit

**Auth:** active-visit token.

**Response 200 (non-terminal entry):** `{ entry_id, status: "waiting", position, seating_code (if allocated) }`

**Response 200 (terminal entry):** `{ status: "seated" | "left" | "no_show" }` — no live position field, since it no longer represents an active session (DEC-006).

**Response 404 / equivalent "no active visit":** when the token is missing/unknown — treated as "start a new join," not a server error.

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

**Response 200:** list of waiting entries with `{ entry_id, group_size, joined_at, position, is_starvation_protected }`.

### `GET /staff/tables`

**Auth:** staff session.

**Response 200:** list of tables with `{ table_id, capacity, status, current_queue_entry_id (if occupied), combination_id (if combined) }`.

### `POST /staff/seat` — Seat by code

**Request:** `{ seating_code }`

**Response 200 (success):** `{ entry_id, status: "seated", table_ids: [...] }`

**Response `conflict`:** required table(s) no longer available at commit time — no partial allocation ever occurs (INV-005).

**Response `not_found` / `validation_error`:** unknown, already-used, or non-waiting code.

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
