# API Overview (Specification)

Status: specification only — resource/operation inventory. Full request/response shapes, status codes, and error contracts are in `05-specifications/api-spec.md`. No endpoints are implemented yet.

## Guest-facing (public, unauthenticated)

| Operation | Purpose | Requirement(s) |
|---|---|---|
| Join queue | Create a `QueueEntry`, idempotently | REQ-GUEST-001, REQ-GUEST-007, REQ-IMP-003 |
| Get current visit | Return position/state for the caller's active-visit token | REQ-GUEST-002, REQ-GUEST-004, REQ-QUEUE-004 |
| Leave queue | Transition the caller's entry to `left` | REQ-GUEST-003 |

All guest operations are scoped by the active-visit token (DEC-006) — a guest can only read/act on the entry their token maps to (NFR-SEC-002).

## Staff-facing (behind stub auth)

| Operation | Purpose | Requirement(s) |
|---|---|---|
| Login | Establish a staff session | REQ-STAFF-001 |
| List queue | View all waiting entries with computed position | REQ-STAFF-002 |
| List tables | View every table's current state | REQ-STAFF-003 |
| Seat by code | Resolve a seating code to a `QueueEntry`, run allocation, commit atomically | REQ-STAFF-004, REQ-TABLE-006 |
| Release seating assignment | Identified by `queue_entry_id`; frees the entry's complete table assignment (single table or combined pair) atomically — never a directly-supplied `table_id` that could reference only part of a combination | REQ-STAFF-005, INV-006, INV-015 (DEC-014) |
| Mark no-show | Transition an entry to `no_show` | REQ-STAFF-006 |

All staff operations require an authenticated session (NFR-SEC-001).

## Cross-cutting behavior expected of every write endpoint

- Executes inside a transaction that upholds the invariants in `03-architecture/domain-model.md`.
- Returns errors distinctly for: validation failure, not-found, conflict/already-processed, and internal failure — exact status-code mapping is `05-specifications/api-spec.md`'s concern.
- Join, seat, release, and no-show are all safe to retry (NFR-IDEM-001/002).

## P1-only surface (not built until P0 is stable)

- Live-update channel for guest position (mechanism per OPEN-002).
- Metrics/health endpoints for observability (REQ-SHOW-004).

## Explicitly not exposed

- No table-management endpoints (layout is seed data, REQ-TABLE-001).
- No guest account/history endpoints (REQ-GUEST-006).
- No endpoint lets a guest query another guest's entry.
