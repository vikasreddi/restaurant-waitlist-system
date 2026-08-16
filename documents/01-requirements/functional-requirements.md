# Functional Requirements

Each requirement has a stable ID used elsewhere in `documents/` (specs, tests, decisions). "Source" marks whether the requirement is **Explicit** (stated in the brief), **Implicit** (necessary consequence, not stated), or **Optional** ("show us if you can").

## Guest

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-GUEST-001 | Guest joins the queue by submitting group size and phone number, reached via one shared QR code, no account/password | Explicit | P0 |
| REQ-GUEST-002 | Guest views their current queue position after joining | Explicit | P0 |
| REQ-GUEST-003 | Guest can leave the queue at any time | Explicit | P0 |
| REQ-GUEST-004 | Guest can close the tab and re-scan/reopen the page and recover their active visit | Explicit | P0 |
| REQ-GUEST-005 | Guest sees a seating code when their group reaches the front, for staff to use | Explicit | P0 |
| REQ-GUEST-006 | No guest account or history is retained between separate visits | Explicit | P0 |
| REQ-GUEST-007 | Clicking "Join" twice does not create two queue entries | Explicit | P0 |

## Staff

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-STAFF-001 | Staff log in via email/password (stub auth acceptable) | Explicit | P0 |
| REQ-STAFF-002 | Staff view the live queue | Explicit | P0 |
| REQ-STAFF-003 | Staff view the state of every table | Explicit | P0 |
| REQ-STAFF-004 | Staff seat a waiting group by entering its seating code | Explicit | P0 |
| REQ-STAFF-005 | Staff release a table (or combined pair) once the seated group leaves | Explicit | P0 |
| REQ-STAFF-006 | Staff mark a waiting group as no-show, distinct from a guest-initiated leave | Explicit | P0 |
| REQ-STAFF-007 | No camera-based scanning required; manual code entry is sufficient | Explicit | P0 |
| REQ-STAFF-008 | Single staff UI user assumed; backend writes remain concurrency-safe regardless | Explicit | P0 |

## Tables

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-TABLE-001 | Table layout (id, capacity, adjacency) is fixed seed data; no management screen | Explicit | P0 |
| REQ-TABLE-002 | A table holds at most one group at a time | Explicit | P0 |
| REQ-TABLE-003 | A table does not serve a new group until the current group has left | Explicit | P0 |
| REQ-TABLE-004 | A smaller group may use a larger single table when necessary (no permanent size-to-table binding) | Explicit (approved decision) | P0 |
| REQ-TABLE-005 | A group may combine at most two adjacent tables | Explicit (approved decision) | P0 |
| REQ-TABLE-006 | Combined-table allocation is atomic: both tables or neither | Explicit | P0 |
| REQ-TABLE-007 | A combined pair behaves as a single seating unit while occupied | Explicit | P0 |
| REQ-TABLE-008 | A combined pair separates back into independent tables after the group leaves | Explicit | P0 |

## Queue

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-QUEUE-001 | Seating is not simple FIFO | Explicit | P0 |
| REQ-QUEUE-002 | Position accounts for table availability and configuration, not arrival order alone | Explicit | P0 |
| REQ-QUEUE-003 | No group waits forever; a documented fairness/starvation policy guarantees this | Explicit | P0 |
| REQ-QUEUE-004 | Position is a dynamic rank, not a permanent number promising an exact seating order | Explicit (approved decision) | P0 |

## Infrastructure

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-INFRA-001 | Data is persisted | Explicit | P0 |
| REQ-INFRA-002 | Schema changes are managed via migrations | Explicit | P0 |
| REQ-INFRA-003 | Hard paths (concurrency, idempotency, atomicity, starvation) are covered by tests | Explicit | P0 |
| REQ-INFRA-004 | The application is runnable end-to-end, Docker Compose preferred | Explicit | P0 |

## Frontend

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-FE-001 | Built as React or another modern SPA | Explicit | P0 |
| REQ-FE-002 | Both guest and staff screens implement the flows above | Explicit | P0 |
| REQ-FE-003 | Real loading states are shown, not just final-state UI | Explicit | P0 |
| REQ-FE-004 | Real empty states are shown | Explicit | P0 |
| REQ-FE-005 | Real error states are shown | Explicit | P0 |
| REQ-FE-006 | Double-clicking "Join" does not create duplicate entries (client-side guard, backed by REQ-GUEST-007) | Explicit | P0 |

## Optional ("Show us if you can")

| ID | Requirement | Source | Priority |
|---|---|---|---|
| REQ-SHOW-001 | Guest screen updates live without manual refresh | Optional | P1 |
| REQ-SHOW-002 | Guest read path ("where am I") is cached with sensible invalidation | Optional | P1 |
| REQ-SHOW-003 | "Table ready" notification is sent via a background job, off the request path | Optional | P1 |
| REQ-SHOW-004 | Structured logging and metrics support incident debugging | Optional | P1 |
| REQ-SHOW-005 | The public guest endpoint is rate-limited | Optional | P1 |

## Implicit requirements (necessary consequences, not separately scored features)

| ID | Requirement | Depends on |
|---|---|---|
| REQ-IMP-001 | An anonymous active-visit token identifies and re-identifies a guest's queue entry | REQ-GUEST-004 |
| REQ-IMP-002 | Table/queue-entry allocation is protected at the data layer against concurrent writes | REQ-TABLE-002, REQ-TABLE-006, REQ-STAFF-008 |
| REQ-IMP-003 | Join uses a real idempotency mechanism, not phone number alone | REQ-GUEST-007 (approved decision, see DEC-006) |
| REQ-IMP-004 | Queue entries and tables have an explicit, enforced state machine | REQ-QUEUE-001..004, REQ-TABLE-002..008 |
