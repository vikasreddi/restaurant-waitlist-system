# Data Model (Specification)

Status: conceptual field-level specification only. **Not a migration, not final DDL.** Database is PostgreSQL (DEC-012); types below are indicative, exact column types/constraints are an implementation-phase (migration-writing) decision.

## tables

| Field | Type (indicative) | Notes |
|---|---|---|
| id | identifier | Primary key |
| capacity | integer | Seed data (DEC-001) |
| status | enum(`free`, `occupied`, `combined`) | See `domain-model.md` state machine |
| current_queue_entry_id | nullable identifier | Set when `occupied`/`combined`; null when `free` |
| combination_id | nullable identifier | Set when part of an active `TableCombination`; null otherwise |
| version / lock token | integer or timestamp | For optimistic-concurrency protection (NFR-CONC-002); exact mechanism TBD |

## table_adjacency

| Field | Type | Notes |
|---|---|---|
| table_id | identifier | |
| adjacent_table_id | identifier | Seed data; symmetric pairs (ASM-005) |

Modeled as a separate adjacency relation rather than a fixed field on `tables`, since a table may be adjacent to more than one other table even though only one combination can be *active* at a time (INV-012 caps active combination size at two, not adjacency-graph degree).

## table_combinations

| Field | Type | Notes |
|---|---|---|
| id | identifier | Primary key |
| queue_entry_id | identifier | The one group occupying this combination |
| table_ids | pair of identifiers | Exactly two, per DEC-002 |
| formed_at | timestamp | |
| dissolved_at | nullable timestamp | Null while active |

## queue_entries

| Field | Type (indicative) | Notes |
|---|---|---|
| id | identifier | Primary key |
| group_size | integer | REQ-GUEST-001 |
| phone_number | string | Not used as an identity/auth mechanism (NFR-SEC-003) |
| status | enum(`waiting`, `seated`, `left`, `no_show`) | See `domain-model.md` state machine, INV-011 |
| active_visit_token | string (opaque) | DEC-006; used to recover an active visit |
| idempotency_key | string | See `idempotency_records`; may be denormalized here or kept only in that table |
| joined_at | timestamp | Basis for wait-time aging (Stage 4, `seating-allocation-policy.md`) |
| starvation_protected_since | nullable timestamp | Set when the group crosses the maximum-wait threshold (DEC-004) |
| seated_at | nullable timestamp | |
| left_at | nullable timestamp | |
| no_show_at | nullable timestamp | |
| assigned_table_id | nullable identifier | Set on seating if a single table |
| assigned_combination_id | nullable identifier | Set on seating if a combined pair |

Exactly one of `assigned_table_id` / `assigned_combination_id` is set once `status = seated`, never both — this is a data-integrity rule to enforce in the implementation phase (e.g., a PostgreSQL check constraint). Release (staff-facing) is always invoked by `queue_entry_id`, never by directly naming a `table_id`/`combination_id` — the backend resolves which one applies and releases it atomically (DEC-014, INV-015). Raw table/combination identifiers exist in this schema for internal bookkeeping and staff read views only, not as release input.

## idempotency_records

| Field | Type | Notes |
|---|---|---|
| idempotency_key | string | Client-generated UUID, reused verbatim across retries of the same join attempt; a new attempt uses a new key. Unique constraint — the enforcement point for INV-007 |
| queue_entry_id | identifier | The entry produced by the first successful request bearing this key |
| created_at | timestamp | |

A unique constraint on `idempotency_key` is the concrete mechanism by which "a retried request never creates a second entry" (REQ-GUEST-007) becomes a database-enforced guarantee rather than an application-level assumption (IMP-002/REQ-IMP-002).

## staff_users

| Field | Type | Notes |
|---|---|---|
| id | identifier | |
| email | string | |
| password_hash | string | Stub-strength acceptable (REQ-STAFF-001) |

## notification_jobs (P1 only)

| Field | Type | Notes |
|---|---|---|
| id | identifier | |
| queue_entry_id | identifier | |
| status | enum(`pending`, `sent`, `failed`) | |
| attempts | integer | Retry bookkeeping |
| created_at / sent_at | timestamp | |

Durable record (not purely in-memory) so a process crash between the seating transaction committing and the notification firing doesn't silently drop the message (Phase 1 analysis §14).

## Relationships (summary)

```
Table (1) ── (0..1 active) TableCombination
TableCombination (1) ── (1) QueueEntry
QueueEntry (1) ── (0..1) assigned Table  [if single-table seating]
QueueEntry (1) ── (0..1) assigned TableCombination  [if combined seating]
QueueEntry (1) ── (0..1) IdempotencyRecord
QueueEntry (1) ── (0..1) NotificationJob  [P1]
```

## Explicitly deferred fields/tables (Future, not built)

- Any `fairness_debt` or `missed_opportunity` tracking table (`07-future-evolution/fairness-debt.md`, `missed-opportunities.md`).
- Any `shared_table_consent` concept (`07-future-evolution/shared-tables.md`).
