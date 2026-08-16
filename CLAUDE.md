# CLAUDE.md — Restaurant Waitlist

Project-wide engineering rules for any Claude Code session working in this repository. This file is intentionally short — it states rules and points to the authoritative documents, it does not restate them. Full context: `documents/06-ai-working-record/ai-development-approach.md`.

## Current status

Requirements, product decisions, specifications, architecture, and test strategy are reviewed and frozen (Session 1 + Session 2, see `documents/06-ai-working-record/session-log.md`). Session 3 (Phase 4) configured the AI-native development environment (this file, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.claude/settings.json`). **Sessions 4–5 (Phase 5A) completed and verified the runnable bootstrap:** a Rails 7.1 API backend, a React+TypeScript (Vite) frontend, and PostgreSQL, all running under Docker Compose, with a working `GET /health` endpoint and confirmed frontend→backend connectivity. **No domain/business functionality has been implemented yet** — no queue/table/seating models, no allocation logic, no guest/staff APIs, no authentication, no Redis/Sidekiq. That begins in Phase 5B (Domain Model + Migrations + Seed Data), not yet started.

## Source of truth

```
documents/01-requirements/       what must be true
documents/02-product-decisions/  what was decided, and why
documents/03-architecture/       the system/domain/data/API design
documents/04-diagrams/           the key flows, visually
documents/05-specifications/     implementation-ready behavior
documents/06-ai-working-record/  prompts, decisions, corrections, session log
documents/07-future-evolution/   explicitly deferred, not built
```

Read the relevant document before touching related code. Do not duplicate large sections of these documents into code comments or agent output — reference them by path and ID (`REQ-*`, `INV-*`, `DEC-*`, `NFR-*`, `TEST-*`).

**If you find a contradiction between these documents and what the task is asking for, STOP and report it — do not silently resolve it.** See "When scope is exceeded," below.

## Approved technology stack (DEC-012)

React + TypeScript · Ruby on Rails (API mode) · PostgreSQL · Redis (P1) · Sidekiq + Redis (P1) · Docker Compose. No Kafka or other messaging platform. No additional infrastructure unless a requirement genuinely requires it (`documents/02-product-decisions/decision-log.md` DEC-012, DEC-013).

## Core development workflow

```
Requirements → Product decisions → Specifications → Implementation plan
→ Small implementation task → Tests → AI review → Human review
→ Commit/checkpoint → Next task
```

Do not skip from requirements straight to broad implementation. Every implementation task should have: a clear scope, a referenced specification (`documents/05-specifications/`), acceptance criteria (`documents/01-requirements/acceptance-criteria.md`), tests, and verification. One bounded objective per session — see `documents/06-ai-working-record/session-plan.md` for the suggested (not mandatory) session breakdown.

## Product rules (non-negotiable — see `documents/02-product-decisions/` for full rationale)

- One group per table. A table cannot be reassigned until its current group leaves.
- Maximum two-table combination (DEC-002). Combined allocation must be atomic — both tables or neither.
- Combined tables behave as one seating unit while occupied; the combination dissolves after release.
- A group becomes `ready` (table configuration reserved, seating code shown) *before* staff act — staff's "seat by code" confirms an already-made allocation decision, it does not perform allocation itself. Seating always requires having passed through `ready` first; there is no direct `waiting → seated` transition.
- A `ready` reservation that isn't confirmed within the configured timeout (5 minutes, tunable) auto-releases via `no_show`, checked lazily wherever a `ready` entry is already being read — never by a background scheduler or Sidekiq job (DEC-015).
- Release operates on the group's complete seating assignment (by `queue_entry_id`), never a raw `table_id` (DEC-014).
- Position is dynamic, computed from current state only — never a promise of an exact count, never a prediction of when a table will free (DEC-005).
- Seating is not FIFO. Compatibility is evaluated from current state; the smallest suitable available configuration is preferred; wait-time aging applies among tied competitors (`documents/02-product-decisions/seating-allocation-policy.md`).
- Maximum-wait protection applies to a group's *complete* required configuration only. An incomplete configuration must never cause an individual table to be reserved indefinitely. This guarantees priority once the configuration is available — it does **not** guarantee an absolute maximum total wait time (`documents/02-product-decisions/starvation-policy.md`).
- A group whose size exceeds every seatable configuration is rejected at join time with a validation error (DEC-011) — never accepted and left permanently unseatable.
- PostgreSQL is the source of truth for table/queue state. Redis is never authoritative for table availability (DEC-013).
- Guest identity uses an anonymous active-visit token, not an account (DEC-006).
- Join is idempotent (client-generated UUID key, reused on retry). Phone number is never the idempotency key (DEC-007).
- Shared tables (`documents/07-future-evolution/shared-tables.md`) and fairness debt / missed-opportunity tracking (`documents/07-future-evolution/fairness-debt.md`, `missed-opportunities.md`) are future scope — do not implement in P0.

## Engineering rules

- Prefer small changes. Do not make unrelated refactors.
- Follow the specifications before implementation; validate assumptions against them rather than guessing.
- Add tests for hard business rules — see `documents/05-specifications/test-strategy.md`.
- Keep business logic out of controllers where possible; prefer domain/service objects when they make the allocation rules clearer.
- Use database transactions wherever an invariant depends on atomicity (`documents/03-architecture/domain-model.md` INV-001–INV-017).
- A database-level exclusivity constraint must never depend on a value copied from another table staying in sync by application convention alone — express it using only the columns of the table being constrained (INV-016; this is the concrete lesson of a real caught mistake, `documents/06-ai-working-record/ai-corrections.md` CORR-004).
- Do not invent product behavior. Do not silently expand scope.

## AI rules

Agents may: inspect, plan, propose, implement within assigned scope, test, review.

Agents must not: change product decisions silently; invent requirements; implement future features; remove tests to make the suite pass; weaken invariants; replace database correctness with cache behavior; claim completion without verification.

## Requirement traceability

Every significant implementation task should reference requirement IDs (e.g., `REQ-GUEST-001`, `REQ-TABLE-005`, `REQ-QUEUE-003`) and keep `documents/01-requirements/traceability.md` current: Requirement → Specification → Implementation → Test. Use the `requirement-traceability` skill. Keep this lightweight — a Markdown table, not a tracking system.

## Agents, skills, and commands available in this repo

| Type | Name | Use for |
|---|---|---|
| Agent | `spec-reviewer` | Reviewing specs/plans before implementation. Read-only — never writes code. |
| Agent | `backend-domain-agent` | Implementing a specifically-scoped Rails domain task. |
| Agent | `test-engineering-agent` | Designing/implementing hard-path tests. |
| Agent | `code-review-agent` | Reviewing completed implementation against requirements. Read-only — never silently modifies code. |
| Skill | `requirement-traceability` | Mapping requirement → spec → code → test. |
| Skill | `hard-path-testing` | Concurrency/idempotency/atomicity/starvation/state-transition test design. |
| Skill | `rails-domain-development` | Project-specific Rails service/transaction/locking guidance. |
| Command | `/spec-review` | Review current specs before starting implementation. |
| Command | `/test-hard-paths` | Check hard-path test coverage against `test-strategy.md`. |
| Command | `/requirements-check` | Map current implementation against requirement IDs. |

Full definitions: `.claude/agents/`, `.claude/skills/`, `.claude/commands/`. Why each exists and what it can/cannot do: `documents/06-ai-working-record/session-log.md` (Session 3) and `agent-decisions.md`.

## When scope is exceeded

If you discover an architectural contradiction, a missing product decision, a security issue requiring a new product decision, or an ambiguity affecting correctness — **do not invent the answer.** Report:

```
BLOCKED — HUMAN DECISION REQUIRED
Issue:
Affected requirement:
Possible options:
Recommendation:
Trade-off:
```

## Non-negotiable invariants (full list and IDs: `documents/03-architecture/domain-model.md`)

Table invariant (one group per table) · Release invariant (a combined assignment releases as one unit) · Atomicity invariant (combined seating is all-or-nothing) · Idempotency invariant (a retried join never creates a second entry) · Source-of-truth invariant (PostgreSQL determines actual table state) · Compatibility invariant (a group is only assigned a configuration that can seat it) · Starvation invariant (a protected group gets priority once its complete configuration is available) · No-reservation invariant (an incomplete configuration never reserves an individual table indefinitely) · Scope invariant (future features are not introduced into the P0 implementation) · Self-contained-constraint invariant (a DB exclusivity constraint never depends on another table's column staying in sync, INV-016) · Ready-expiration invariant (an unconfirmed `ready` reservation auto-releases after a tunable timeout, checked lazily, INV-017).

## Phase boundary

This file and everything under `.claude/` were created during a documentation/configuration-only session (Phase 4). The Phase 5A bootstrap (Sessions 4–5) added a runnable `backend/` (Rails API), `frontend/` (React+TS), and `docker-compose.yml` — infrastructure only. No business models (queue, table, seating assignment, idempotency record), no allocation/queue services, no guest/staff APIs, no authentication, and no Redis/Sidekiq code exist yet. Phase 5B explicitly authorizes the first domain implementation.
