# Architecture (Specification)

Status: specification only — nothing in this document is implemented yet. Technology stack is **approved** (`02-product-decisions/decision-log.md` DEC-012); the live-update mechanism (OPEN-002), seating-code format (OPEN-005), and guest-abandonment behavior (OPEN-007) remain open, tracked in the decision log.

## 1. Approved technology stack (DEC-012)

| Layer | Choice |
|---|---|
| Frontend | React + TypeScript |
| Backend | Ruby on Rails (API mode) |
| Database | PostgreSQL |
| Cache (P1) | Redis |
| Background jobs (P1) | Sidekiq + Redis |
| Containerization | Docker Compose |

Evaluated against the assignment's concurrency, atomicity, and idempotency requirements and approved without modification — full evaluation in `02-product-decisions/decision-log.md` DEC-012. No message broker (e.g., Kafka) is used; Sidekiq + Redis is proportionate to the single "table ready" async job this assignment calls for.

## 2. Components

```
Guest Browser (React SPA)   Staff Browser (React SPA)
        |                          |
        └───────────┬──────────────┘
                     |  HTTPS
              Rails API (backend)
        (guest endpoints, staff endpoints)
                     |
        ┌────────────┼─────────────────┐
        |            |                 |
  PostgreSQL      Redis (P1)      Sidekiq worker (P1)
 (source of        (guest read     (async "table ready"
  truth, migrated)  path cache      notification, via Redis
                     only)          as the job backend)
```

- **Guest SPA (React + TypeScript)** — public, unauthenticated. Talks only to guest-facing API endpoints (join, view position, leave).
- **Staff SPA (React + TypeScript)** — behind stub auth. Talks to staff-facing API endpoints (queue/table view, seat, release, no-show) plus login.
- **Rails API** — single service for P0. Owns all domain logic: allocation, idempotency, state transitions, atomicity. No separate microservices — the scale (~40 tables, ~400 groups/evening) does not justify splitting services (see `02-product-decisions/scope-and-tradeoffs.md` on avoiding overengineering).
- **PostgreSQL** — system of record for tables, queue entries, table combinations, staff users, idempotency records. Migrated via Rails migrations, never hand-edited.
- **Redis (P1 only)** — sits in front of the guest read path ("where am I") only. **Never the source of truth for table availability** (DEC-013) — invalidated on every relevant write.
- **Sidekiq + Redis (P1 only)** — carries the "table ready" notification off the synchronous seat-request path, backed by a durable `notification_jobs` record (`03-architecture/data-model.md`) so a crash between commit and dispatch doesn't silently drop the message.

## 3. Request flow (P0, synchronous)

1. Guest joins → API validates group size against seatable capacity (reject if oversized, DEC-011), applies the idempotency check, creates a `QueueEntry` in a transaction, returns position + active-visit token.
2. Guest polls/reconnects (mechanism per OPEN-002) → API computes current position from **current** PostgreSQL state and returns it — never a prediction of when a table will next free (DEC-005).
3. Staff seats by code → API resolves the code to a `QueueEntry`, determines its allocated configuration under the seating policy (`02-product-decisions/seating-allocation-policy.md`), attempts atomic allocation, commits or fails cleanly.
4. Staff releases → API resolves the seated `QueueEntry`'s complete seating assignment (single table or combined pair) and releases it atomically as one unit — never a raw, independently-specified `table_id` (DEC-014).
5. Staff marks no-show → API transitions the entry to a terminal no-show state.

All writes in steps 1, 3, 4, 5 execute inside PostgreSQL transactions using row-level locking (`SELECT ... FOR UPDATE` via ActiveRecord's `.lock!`, or an equivalent optimistic-concurrency check) to uphold `03-architecture/domain-model.md` invariants under concurrent requests.

## 4. Why a single backend service (not microservices)

The domain is small and tightly coupled (allocation logic touches tables, queue entries, and combinations together in one transaction). Splitting into services would introduce distributed-transaction problems for exactly the atomicity guarantee the brief cares most about (atomic combined-table allocation), with no scale justification at ~40 tables / ~400 groups per evening. This is a deliberate anti-overengineering choice, consistent with the Phase 1 analysis's flagged AI-agent risk of overengineering the architecture.

## 5. Concurrency / consistency principle (DEC-013)

> **PostgreSQL is the source of truth for table allocation. Redis must never be used to determine whether a table is actually free.**

If Redis (P1) is built, it caches guest-facing read responses only and is invalidated on every write event (`04-diagrams/07-architecture-data-flow.md`). Every allocation decision (seat, release, no-show, combined-table acquisition) reads and writes PostgreSQL directly inside a transaction, regardless of Redis's current contents. This bounds the blast radius of a stale cache to momentary display staleness — it can never cause a double-booked table, because Redis is never consulted by the allocation path itself.

The same discipline applies to Sidekiq: job payloads reference IDs to re-read from PostgreSQL at execution time, not stale embedded state, so a delayed job never acts on out-of-date table/queue data.

## 6. Deployment

- `docker compose up` brings up the React frontend, Rails API, PostgreSQL, and (once P1 items are built) Redis and a Sidekiq worker process — REQ-INFRA-004.
- Configuration (starvation threshold, max combination size, etc.) is environment-driven, not hardcoded, so it can be tuned without a code change — though the *values* themselves (e.g., 20-minute threshold) remain take-home assumptions, not tunable-in-production claims.

## 7. Remaining open decisions

Not decided in this document — see `02-product-decisions/decision-log.md` §Open decisions.

| Decision | Candidate options | Constraint from requirements |
|---|---|---|
| Live-update mechanism | Polling / SSE / WebSockets | REQ-SHOW-001 (P1); trade-offs discussed in Phase 1 analysis §12, not re-decided here |
| Seating-code format/strength | Short numeric / longer opaque token | `05-specifications/api-spec.md` |
| Guest abandonment/expiration behavior | No timeout / idle timeout / staff-only | No explicit brief requirement; tracked as OPEN-007 |
