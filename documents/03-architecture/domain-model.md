# Domain Model (Specification)

Status: specification only — concepts and invariants, not a database schema (see `data-model.md` for the field-level spec, also not yet implemented).

## 1. Entities

| Entity | Represents |
|---|---|
| **Table** | A physical table: id, capacity, adjacency (which other tables it can combine with), current occupancy state |
| **TableCombination** | An active grouping of exactly two adjacent tables acting as one seating unit for one `QueueEntry`; exists only while that group occupies it |
| **QueueEntry** | One group's waitlist record: group size, phone number, status, timestamps, active-visit token, assigned seating configuration once seated |
| **GuestVisit / ActiveVisitToken** | The anonymous token tying a browser session to its current `QueueEntry` (DEC-006) |
| **StaffUser** | An authenticated staff actor (stub auth, REQ-STAFF-001) |
| **IdempotencyRecord** | Tracks a join request's idempotency key to guarantee REQ-IMP-003 / NFR-IDEM-001 |
| **NotificationJob** (P1 only) | Represents the async "table ready" message dispatch (REQ-SHOW-003) |

Whether `TableCombination` is a distinct row/table or a field on `Table` (e.g., a nullable `combination_id`) is a `data-model.md` concern, not decided here.

## 2. State machines

### QueueEntry status

```
waiting ──┬──> seated   (terminal)
          ├──> left     (terminal, guest-initiated)
          └──> no_show  (terminal, staff-initiated)
```

- Entry into `waiting` happens on join (idempotent — REQ-IMP-003).
- All three terminal states are mutually exclusive and final (INV-011).
- A `seated` entry can later be followed by table release, but release is a `Table`/`TableCombination` transition, not a further `QueueEntry` state (the entry stays `seated` as the historical record; the *table* becomes free).

### Table occupancy state

```
free ──> occupied (single group) ──> free
free ──> combined (part of a TableCombination, occupied) ──> free
```

- A table is never in `occupied`/`combined` for more than one group at a time (INV-001).
- A table only leaves `occupied`/`combined` via an explicit staff release (REQ-STAFF-005), not automatically.

### TableCombination lifecycle

```
formed (atomic, both member tables → combined) ──> active (one QueueEntry) ──> dissolved (both member tables → free)
```

- `formed` only succeeds if both member tables are acquired in the same atomic operation (INV-005); otherwise no `TableCombination` is created and neither table's state changes (INV-008).
- `dissolved` happens only via staff release of the combined group (INV-006).

## 3. Domain invariants

Carried forward from the Phase 1 analysis and reconciled with approved decisions.

| ID | Invariant |
|---|---|
| INV-001 | A table is assigned to at most one active group at any instant |
| INV-002 | A table does not accept a new group while occupied or part of an active combination |
| INV-003 | An occupied table cannot be allocated to a second group until explicitly released |
| INV-004 | While combined, member tables are treated as a single allocatable unit — neither is independently assignable |
| INV-005 | Combined-table allocation is all-or-nothing: a seating operation acquires every table in the combination or none |
| INV-006 | After a combined group leaves, the combination dissolves and each member table becomes independently available |
| INV-007 | A duplicate/retried join request for the same logical request never produces a second `QueueEntry` |
| INV-008 | At any instant, the set of table→group assignments contains no conflicts |
| INV-009 | A `QueueEntry` can be seated at most once; being seated is a one-way, non-repeatable transition |
| INV-010 | Once a group's tables are released, that group holds no further claim on them — they are immediately eligible for the next allocation |
| INV-011 | `QueueEntry` terminal states (`seated`, `left`, `no_show`) are mutually exclusive and final |
| INV-012 | A `TableCombination` never contains more than two tables (DEC-002) |
| INV-013 | Starvation protection (once granted) applies to a group's complete required configuration, never to a single member table in isolation (DEC-004); it guarantees priority once that configuration is available, not an absolute maximum total wait time |
| INV-014 | PostgreSQL is the sole source of truth for table/queue-entry state; a cache (Redis, P1) is never consulted to decide whether a table is actually free (DEC-013) |
| INV-015 | A seated `QueueEntry`'s table(s) are released as one atomic unit, identified by the entry itself — never by an independently-supplied `table_id` that could reference only part of a combination (DEC-014) |

## 4. Domain events (informative — for observability, `05-specifications`)

`guest_joined`, `guest_left`, `guest_no_show`, `group_seated`, `tables_combined`, `tables_released`, `group_became_starvation_protected`, `notification_sent` (P1). These map directly to invariants above and are the natural basis for both the audit trail and observability instrumentation (`05-specifications/test-strategy.md`, `06-ai-working-record`).
