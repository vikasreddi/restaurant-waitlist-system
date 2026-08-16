# Domain Model (Specification)

Status: specification only — concepts and invariants, not a database schema (see `data-model.md` for the field-level spec, also not yet implemented). **Finalized as of Phase 5B.1 (Session 9)** — this document now reflects `05-specifications/domain-model-proposal.md` (the full analysis, rationale, and alternatives comparison lives there; this document is the concise reference copy, in the same role it always had).

## 1. Entities

| Entity | Represents |
|---|---|
| **Table** | A physical table: id, capacity, adjacency (which other tables it can combine with). No stored occupancy — see §2. |
| **TableAdjacency** | Which tables can combine with which; seed data, static. |
| **QueueEntry** | One group's waitlist record: group size, phone number, status, timestamps, active-visit token, idempotency key, seating code |
| **SeatingAssignment** | A reservation/occupancy record for one `QueueEntry`, covering 1–2 tables; exists from the moment a group becomes `ready` through release |
| **SeatingAssignmentTable** | Which table(s) a `SeatingAssignment` covers; the row that carries the database-level table-exclusivity constraint |
| **StaffUser** | An authenticated staff actor (stub auth, REQ-STAFF-001) |

**Revised from the original Phase 3 draft** (superseded, not merely amended — see `05-specifications/domain-model-proposal.md` §0 for the full reasoning): `TableCombination` is replaced by `SeatingAssignment` + `SeatingAssignmentTable` (generalizes single- and combined-table seating uniformly, and represents the reservation *before* confirmed occupancy, not just the confirmed state). `IdempotencyRecord` and `GuestVisit`/`ActiveVisitToken` are no longer separate entities — both are unique columns directly on `QueueEntry` (`idempotency_key`, `active_visit_token`). `NotificationJob` is dropped from the domain model entirely for now (P1, out of scope until Redis/Sidekiq land).

## 2. State machines

### QueueEntry status

```
waiting ──┬──> ready ──┬──> seated   (terminal)
          │            ├──> left     (terminal, guest-initiated)
          │            └──> no_show  (terminal, staff-initiated OR automatic —
          │                           DEC-015, 5-minute lazy-evaluated expiration
          │                           of an unconfirmed ready reservation)
          ├──> left     (terminal, guest-initiated)
          └──> no_show  (terminal, staff-initiated)
```

- Entry into `waiting` happens on join (idempotent — REQ-IMP-003).
- Entry into `ready` happens when the allocation service selects this entry for a newly-available table configuration — **not** when staff act. A `pending` `SeatingAssignment` is created and a `seating_code` generated at this point; staff's later "seat by code" action confirms an already-reserved assignment, it does not perform allocation itself. (This is a correction to the original Phase 3 draft, which had allocation happen synchronously at "seat by code" time — see `domain-model-proposal.md` §0 item 1.)
- `waiting → seated` directly is **not** a valid transition — seating always requires having passed through `ready` first.
- `ready → waiting` ("un-ready") is **not** modeled in the MVP, including as an outcome of expiration (DEC-015 explicitly chose auto-`no_show` over re-queueing).
- All terminal states (`seated`, `left`, `no_show`) are mutually exclusive and final (INV-011).
- A `seated` entry can later be followed by table release, but release is a `SeatingAssignment` transition, not a further `QueueEntry` state change (the entry stays `seated` as the historical record; the *assignment* and its table(s) transition instead).

### Table occupancy (derived, not stored)

A table has no stored status field. Its occupancy is always derived from whether a non-released `SeatingAssignmentTable` row references it:

```
free  ──(claim row created, parent assignment pending)──▶  held  ──(parent assignment
 ▲                                                           │      activated — no change
 │                                                           │      to the claim row)──▶ occupied
 │                                                           │                              │
 │ (claim row's released_at is set — parent assignment       │                              │
 │  released while still pending: guest left, staff/auto     │                              │
 │  no-show; row itself is retained for history)              │                              │
 └───────────────────────────────────────────────────────────┘                              │
 ▲                                                                                            │
 └────────(claim row's released_at is set — group physically left)───────────────────────────┘
```

- A table is never `held`/`occupied` for more than one group at a time (INV-001) — enforced at the database level by a partial unique index on `SeatingAssignmentTable.table_id WHERE released_at IS NULL` (see `data-model.md`).
- A table only leaves `held`/`occupied` via an explicit release (staff, guest-leave-while-ready, or DEC-015's automatic expiration), never silently.
- `held` vs. `occupied` is a read-time distinction (join to the parent `SeatingAssignment.status`), not stored per-table or per-claim-row.

### SeatingAssignment lifecycle

```
pending (atomic, all member tables claimed at once) ──> active (staff confirm via seating code)
   │                                                        │
   └──> released (guest left / no-show / DEC-015 expiration, before ever being active)
                                                             └──> released (staff release, group has left)
```

- `pending` only succeeds if all member tables (1 or 2) are claimed in the same atomic operation (INV-005); otherwise no `SeatingAssignment` is created and no partial claim exists (INV-008).
- `released` happens via staff release (after the group leaves), via the guest leaving/being marked no-show while still `pending`, or automatically via DEC-015's lazy-evaluated expiration — all three set the member `SeatingAssignmentTable` row(s)' `released_at`, never deleting them (history is preserved).

## 3. Domain invariants

Carried forward from the Phase 1 analysis and reconciled with approved decisions; revised this session to reflect the finalized Phase 5B.1 model.

| ID | Invariant |
|---|---|
| INV-001 | A table is claimed by at most one active (non-released) `SeatingAssignment` at any instant |
| INV-002 | A table does not accept a new claim while held or occupied by a non-released assignment |
| INV-003 | A held/occupied table cannot be claimed by a second group until its assignment is explicitly released |
| INV-004 | While part of a 2-table `SeatingAssignment`, member tables are treated as a single allocatable unit — neither is independently assignable |
| INV-005 | Combined-table allocation is all-or-nothing: a `SeatingAssignment` claims every table it needs or none |
| INV-006 | After a `SeatingAssignment` is released, each member table becomes independently available again |
| INV-007 | A duplicate/retried join request for the same logical request never produces a second `QueueEntry` |
| INV-008 | At any instant, the set of table→assignment claims contains no conflicts |
| INV-009 | A `QueueEntry` can be seated at most once; being seated is a one-way, non-repeatable transition |
| INV-010 | Once a `SeatingAssignment` is released, that group holds no further claim on its former tables — they are immediately eligible for the next allocation |
| INV-011 | `QueueEntry` terminal states (`seated`, `left`, `no_show`) are mutually exclusive and final; `ready` is **not** terminal (revised — the original draft had only `waiting`/`seated`/`left`/`no_show`; `ready` was added, see `domain-model-proposal.md` §0) |
| INV-012 | A `SeatingAssignment` never claims more than two tables (DEC-002) |
| INV-013 | Starvation protection (once granted) applies to a group's complete required configuration, never to a single member table in isolation (DEC-004); it guarantees priority once that configuration is available, not an absolute maximum total wait time |
| INV-014 | PostgreSQL is the sole source of truth for table/queue-entry state; a cache (Redis, P1) is never consulted to decide whether a table is actually free (DEC-013) |
| INV-015 | A seated `QueueEntry`'s `SeatingAssignment` is released as one atomic unit, identified by the entry itself — never by an independently-supplied `table_id` that could reference only part of a combination (DEC-014) |
| INV-016 | A `SeatingAssignment`'s table-exclusivity constraint is expressed entirely within `SeatingAssignmentTable`'s own columns (`table_id`, `released_at`) — never dependent on a value copied from another table staying in sync (added this session; the concrete lesson of CORR-004, see `06-ai-working-record/ai-corrections.md`) |
| INV-017 | A `ready` `SeatingAssignment` that is not confirmed within the configured timeout (5 minutes, tunable) auto-releases via `no_show`, evaluated lazily — never by a background scheduler (DEC-015) |

## 4. Domain events (informative — for observability, `05-specifications`)

`guest_joined`, `guest_left`, `guest_no_show` (staff-initiated or automatic-expiration, DEC-015), `group_became_ready`, `group_seated`, `assignment_released`, `group_became_starvation_protected`, `notification_sent` (P1). These map directly to invariants above and are the natural basis for both the audit trail and observability instrumentation (`05-specifications/test-strategy.md`, `06-ai-working-record`).
