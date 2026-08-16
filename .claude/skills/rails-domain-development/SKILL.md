---
name: rails-domain-development
description: Use when implementing Rails backend domain/service logic for this project — seating allocation, table/queue state transitions, transactions, and locking. Load before writing Rails models or services that touch table or queue-entry state. This is project-specific guidance, not a general Rails tutorial — triggers on "seating allocator," "table locking," "queue entry model," "allocation service," "Rails transaction for this project."
---

# Rails Domain Development — Restaurant Waitlist

Project-specific guidance for implementing the domain logic specified in `documents/05-specifications/allocation-spec.md` and `documents/03-architecture/domain-model.md` in Rails. This is not a general Rails how-to — assume Rails competence; this covers only what's specific to this project's correctness requirements.

## Service/domain boundaries

- Controllers stay thin: parse/validate input, call a domain service, render the result. The allocation decision (`compatible_configurations`, `eligible_groups`, `select_group_for` — `allocation-spec.md` §1–3) belongs in a plain Ruby service object or a model concern, not inline in a controller action, so it can be unit-tested without going through the HTTP stack.
- One service per domain operation maps cleanly to the spec's pseudocode functions: something like a seating allocator (join validation + Stage 0–6), a release handler (queue-entry-scoped, DEC-014), and a starvation-protection updater (Stage 4 trigger). Keep these separately testable rather than one large "QueueService god object."

## Transactions and locking

- Every write that must uphold an atomicity invariant (INV-005 combined allocation, INV-007 idempotent join, INV-009 seat-once) needs an explicit `ActiveRecord::Base.transaction do ... end` block — do not rely on Rails' implicit per-statement transactions.
- Use row-level locking inside the transaction for anything reading table state before writing it: `table.lock!` (pessimistic, `SELECT ... FOR UPDATE`) is the straightforward choice for the seat/release paths given this project's scale (~40 tables) and two-day timeline; an optimistic `lock_version` column is a reasonable alternative if a specific task calls for it, but don't mix strategies within the same code path without a documented reason.
- For combined-table allocation, lock *both* member tables (in a consistent order, e.g., by primary key, to avoid deadlocks between two allocation attempts locking the same pair in opposite order) before checking free/occupied status — checking then locking reopens the race the lock exists to prevent.
- The idempotency-key uniqueness check (INV-007) should rely on a real database unique index/constraint on `idempotency_key`, not an application-level "check then insert" — that reintroduces exactly the race the constraint is meant to close. Handle the resulting `ActiveRecord::RecordNotUnique` (or equivalent) as the "retry" branch, not as an unexpected error.

## Model validations vs. domain invariants

- Rails model validations (`validates :group_size, numericality: ...`) are for input shape/presence — use them for that.
- Cross-entity invariants (a table can't be assigned to two groups, a combination is exactly two tables) are **not** expressible as a single-model validation and must live in the transactional service logic, backed by a real database constraint where feasible (unique index, check constraint) — see `documents/02-product-decisions/decision-log.md` DEC-013/DEC-014 for why the database, not Ruby-level validation alone, is the actual source of truth.
- Never rely on a `validates_uniqueness_of`-style check alone for the idempotency key or the one-table-one-group invariant — Rails-level uniqueness validations are not race-safe by themselves; pair them with (or replace them with) a database-level unique constraint.

## Testing

- Domain services should have model/service-level tests that don't go through the full request stack for the majority of cases (faster feedback, clearer failure attribution) — reserve request specs for verifying the HTTP contract (`documents/05-specifications/api-spec.md`), and use the `hard-path-testing` skill for anything concurrency/atomicity/idempotency-related regardless of which test layer it's written at.
- Use real parallel execution (threads or parallel connections against the test database) for concurrency tests — Rails' transactional test fixtures can hide real-world locking behavior if not set up carefully; if a concurrency test needs `use_transactional_tests = false` or an equivalent to see real lock contention, that's expected for this category of test, not a mistake to "fix" by removing it.

## Redis/Sidekiq (P1 — only once P0 is stable)

- Redis, if/when built, is read-through cache for the guest position endpoint only — never write the allocation decision path to read from Redis (DEC-013). Cache invalidation happens on the same write paths that already exist for the domain events (join, seat, release, no-show, combination formed/dissolved) — hook into those, don't build a parallel invalidation mechanism.
- Sidekiq jobs should re-fetch their subject (e.g., the queue entry) from PostgreSQL at execution time rather than serializing full state into the job payload, so a delayed job never acts on stale data.
