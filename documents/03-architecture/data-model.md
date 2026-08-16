# Data Model (Specification)

Status: conceptual field-level specification only. **Not a migration, not final DDL.** Database is PostgreSQL (DEC-012); types below are indicative, exact column types/constraints are an implementation-phase (migration-writing) decision. **Finalized as of Phase 5B.1 (Session 9)** — this document now reflects `05-specifications/domain-model-proposal.md`, including the CORR-004 constraint correction. See that document for full rationale, alternatives considered, and the concurrency plan; this is the concise reference copy.

**Implemented as of Phase 5B.2 (Session 11)** — migrations, models, seed data, and tests now exist in `backend/`. Three small implementation-phase refinements worth recording here (none are business-rule changes, all are documented in `06-ai-working-record/agent-decisions.md` Session 11):
1. `seating_assignments` gained a stored `expires_at` (set at creation from `SeatingAssignment::READY_TIMEOUT`) — a deliberate, minor deviation from `domain-model-proposal.md` §8's "derive, don't store" stance for the starvation threshold, made because the implementing prompt's own field list asked for it and it's harmless (a frozen deadline for one specific reservation, not a business-rule change).
2. `table_adjacencies` uses **canonical-pair storage**: a DB check constraint (`table_id < adjacent_table_id`) guarantees a pair is never representable as two independent rows. `Table#adjacent_tables` hides this detail behind a symmetric reader.
3. `seating_code` stays on `queue_entries` (as this document already specified), not duplicated onto `seating_assignments` — resolving a wording ambiguity in the Phase 5B.2 implementation prompt in favor of this already-finalized document.

## tables

| Field | Type (indicative) | Notes |
|---|---|---|
| id | identifier | Primary key |
| capacity | integer, `> 0` | Seed data (DEC-001) |

No occupancy field. A table's occupancy is always derived from `seating_assignment_tables` — see below. (Revised from the Phase 3 draft, which had `status`/`current_queue_entry_id`/`combination_id` stored directly on `tables`; removed to eliminate a dual-source-of-truth risk.)

## table_adjacency

| Field | Type | Notes |
|---|---|---|
| table_id | identifier | |
| adjacent_table_id | identifier | Seed data; symmetric pairs (ASM-005) |

Unique on `(table_id, adjacent_table_id)`. Modeled as a separate adjacency relation rather than a fixed field on `tables`, since a table may be adjacent to more than one other table even though only one `SeatingAssignment` can claim it at a time (INV-012 caps combination size at two, not adjacency-graph degree).

## queue_entries

| Field | Type (indicative) | Notes |
|---|---|---|
| id | identifier | Primary key |
| group_size | integer, `> 0` | REQ-GUEST-001 |
| phone_number | string | Not used as an identity/auth/idempotency mechanism (NFR-SEC-003) |
| status | enum(`waiting`, `ready`, `seated`, `left`, `no_show`) | See `domain-model.md` state machine, INV-011. **`ready` added** — revised from the Phase 3 draft, which only had `waiting`/`seated`/`left`/`no_show`. |
| active_visit_token | string (opaque), unique | DEC-006; used to recover an active visit. Column directly here — no separate `GuestVisit`/`ActiveVisitToken` table (revised from Phase 3 draft). |
| idempotency_key | string, unique | Client-generated UUID, reused verbatim across retries of the same join attempt; a new attempt uses a new key. This unique index is the enforcement point for INV-007. Column directly here — no separate `idempotency_records` table (revised from Phase 3 draft; see rationale in `domain-model-proposal.md` §10). |
| seating_code | string, nullable, unique where not null | Set only when entering `ready`; what staff type to confirm seating. Format/strength: `OPEN-005`, still open. |
| joined_at | timestamp | Basis for wait-time aging (Stage 4, `seating-allocation-policy.md`) |
| ready_at | nullable timestamp | Set on entering `ready`; basis for the DEC-015 expiration check |
| seated_at | nullable timestamp | |
| left_at | nullable timestamp | |
| no_show_at | nullable timestamp | Set whether no-show was staff-initiated or automatic (DEC-015 expiration) — the two triggers are not distinguished in this field; see `domain-model-proposal.md` §2 note |

Indexes: unique `active_visit_token`; unique `idempotency_key`; partial unique `seating_code WHERE seating_code IS NOT NULL`; `(status, joined_at)` composite (drives both "find active entries" and the DEC-015 lazy-expiration check — no separate index needed for the latter).

**Not stored:** any position, rank, "weight," or starvation-protection flag — all computed at read time from `group_size`, `status`, `joined_at`, current table availability, and `table_adjacency` (DEC-005; `domain-model-proposal.md` §7–8).

## seating_assignments

| Field | Type (indicative) | Notes |
|---|---|---|
| id | identifier | Primary key |
| queue_entry_id | identifier, unique where `status != 'released'` | The one group this assignment is/was for. Partial unique index — valid, `status` is this table's own column. |
| status | enum(`pending`, `active`, `released`) | `pending` = reserved while `QueueEntry.status = ready`; `active` = confirmed (`QueueEntry.status = seated`); `released` = terminal |
| created_at | timestamp | |
| activated_at | nullable timestamp | Set when `pending → active` (staff confirm) |
| released_at | nullable timestamp | Set when `→ released` (group leaves, or DEC-015 expiration) |

Revised from the Phase 3 draft's `table_combinations` — generalizes to both single- and combined-table seating (not just the 2-table case), and represents the reservation *before* confirmed occupancy (`pending`), which `table_combinations` never modeled.

## seating_assignment_tables

| Field | Type (indicative) | Notes |
|---|---|---|
| id | identifier | Primary key |
| seating_assignment_id | identifier | FK |
| table_id | identifier | FK |
| released_at | nullable timestamp | **NULL while claimed; set (never deleted) when the parent assignment releases** |

**The core constraint of this entire schema:** `UNIQUE (table_id) WHERE released_at IS NULL`.

This is the database-level enforcement of "one group per table" (INV-001/002/003) — and it is deliberately shaped this way after a real, caught mistake (see `06-ai-working-record/ai-corrections.md` CORR-004, and `domain-model-proposal.md` §0 items 6–7): an earlier draft of this table carried its own `status` column, denormalized from the parent `seating_assignments.status`, with a partial unique index predicated on it — but PostgreSQL partial-index predicates cannot reference another table's column, so that design's correctness depended on an application promise to keep the copy in sync, not on the database. The `released_at` design fixes this: the predicate references only this table's own column (INV-016), and — as a second-order benefit — because rows are never deleted, historical seating assignments remain queryable (which the *first* attempted fix, deleting rows on release, would have lost).

**Lifecycle:** 1 or 2 rows created (in the same transaction as the parent `seating_assignments` row) when an assignment is formed; `released_at` set (both rows together, if combined) when the parent is released, in the same transaction as the parent's `status → released`. Activating an assignment (`pending → active`) touches **only** the parent row — these rows are untouched, since "claimed" (which they express) doesn't change when a hold becomes a confirmed seating.

Application-level (not DB-enforced) constraint: at most 2 rows per `seating_assignment_id` (DEC-002) — enforced by the allocation service, the sole writer of this table; not worth a DB trigger for a fixed, unchanging business rule.

## staff_users

| Field | Type | Notes |
|---|---|---|
| id | identifier | |
| email | string, unique | |
| password_hash | string | Stub-strength acceptable (REQ-STAFF-001) |

## Relationships (summary)

```
Table (1) ── (0..*) TableAdjacency ── (*) Table                [symmetric, seed data]
Table (1) ── (0..*) SeatingAssignmentTable                     [historical; at most one with released_at IS NULL]
SeatingAssignment (1) ── (1..2) SeatingAssignmentTable
QueueEntry (1) ── (0..1) SeatingAssignment [current]
```

`QueueEntry` never references `Table` directly — always through `SeatingAssignment` → `SeatingAssignmentTable` → `Table`, so "which table(s) does this group have" and "is this table free" resolve through the same join, with no risk of two code paths disagreeing.

## Explicitly not modeled in this phase (Future, not built)

- `NotificationJob` / any table for the async "table ready" message — deferred with Redis/Sidekiq (P1).
- Any `fairness_debt` or `missed_opportunity` tracking table (`07-future-evolution/fairness-debt.md`, `missed-opportunities.md`).
- Any `shared_table_consent` concept (`07-future-evolution/shared-tables.md`).
