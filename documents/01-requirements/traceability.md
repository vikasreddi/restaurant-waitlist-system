# Requirement Traceability

Lightweight, living map: **Requirement → Specification → Implementation → Test.** Updated as implementation proceeds (per session, per task) — not a one-time artifact. Kept intentionally simple: a Markdown table, not a tracking system. Use the `requirement-traceability` skill when updating this file.

Status: **Phase 5A = infrastructure/bootstrap only** (Rails/React/PostgreSQL/Docker Compose runnable foundation, no business logic). **Phase 5B.2 = persistence foundation** (models, migrations, constraints, seed data — no business APIs; not yet reflected row-by-row below). **Phase 5B.3 = first real business API**: guest join + idempotency (REQ-GUEST-001, REQ-GUEST-007 below). **Phase 5B.4 = guest current-visit/status + informational position** (REQ-GUEST-002, REQ-GUEST-004 below — the *full* DEC-005 position computation remains deferred to the allocation service). **Phase 5B.5.1 = allocation algorithm locked** (specification/analysis only). **Phase 5B.5.2 = pure allocation decision engine implemented** (`backend/app/services/allocation/decision_engine.rb` and friends — no database mutation). **Phase 5B.5.3 = transactional allocation implemented** (`Allocation::ReservationService` — real table locking, atomic 1–2-table reservation, `seating_code` generation, `waiting → ready`, verified under real PostgreSQL concurrency). **Phase 5B.5.4 = trigger integration + repeated allocation orchestrator** (`Allocation::Orchestrator`) — Guest Join and the lazy READY-expiration no-show path now actually invoke allocation end-to-end; Release and Guest Leave remain unintegrated because neither has an implemented code path to attach to yet (not a specification gap — see `allocation-algorithm.md` §25c). **Phase 5B.6 = staff seating confirmation** (`Staff::ConfirmSeatingService`) — `POST /staff/seat` implemented and verified under real concurrency; deliberately **unauthenticated** (no staff login/session mechanism exists yet, REQ-STAFF-004 row below). All other business requirements remain `—` until their own phase implements them. This file should be updated in the same commit/checkpoint as the code and tests it describes, not after the fact from memory.

## How to use this file

- When starting an implementation task, find the requirement ID(s) it covers below and confirm the "Specification" column points to what you're about to build.
- When the task is done, fill in "Implementation" (file/module) and "Test" (test ID from `05-specifications/test-strategy.md`, or file path) for each requirement it satisfies.
- If a requirement has no realistic test (e.g., a UI copy detail), write `manual` in the Test column with a one-line note, not a blank.
- Never mark a requirement done in this file without a corresponding test or an explicit, noted reason one isn't applicable.

## P0 requirements

| Requirement | Specification | Implementation | Test |
|---|---|---|---|
| REQ-GUEST-001 (join) | `05-specifications/functional-spec.md` §1, `api-spec.md` join | `backend/app/services/guest/join_service.rb`, `backend/app/controllers/guest/queue_entries_controller.rb` — entry creation, `active_visit_token`; **as of Phase 5B.5.4, a new join triggers `Allocation::Orchestrator` and may synchronously return `status: "ready"`** (see `api-spec.md` join "Implementation status"); **`position` still not returned** (deferred) | `backend/test/services/guest/join_service_test.rb`, `backend/test/controllers/guest/queue_entries_controller_test.rb`, `backend/test/controllers/guest/queue_entries_allocation_integration_test.rb` |
| REQ-GUEST-002 (view position) | `functional-spec.md` §9, `api-spec.md` current | `backend/app/services/guest/current_queue_status_service.rb` — implemented as a chronological-rank informational position only; **the full DEC-005 (table-availability/compatibility/aging/starvation-aware) position remains deferred to Phase 5B.5** — see `api-spec.md` current "Position semantics" | `backend/test/services/guest/current_queue_status_service_test.rb`, `backend/test/controllers/guest/current_queue_status_controller_test.rb` |
| REQ-GUEST-003 (leave) | `functional-spec.md` §3 | — | — |
| REQ-GUEST-004 (recover visit) | `functional-spec.md` §2, DEC-006 | `backend/app/services/guest/current_queue_status_service.rb`, `backend/app/controllers/guest/queue_entries_controller.rb#current` — token-based lookup, all four state shapes (`waiting`/`ready`/terminal/unknown) | `backend/test/services/guest/current_queue_status_service_test.rb`, `backend/test/controllers/guest/current_queue_status_controller_test.rb`; TEST-013, TEST-014 |
| REQ-GUEST-005 (seating code) | `api-spec.md` current | — | — |
| REQ-GUEST-006 (no cross-visit history) | DEC-006 | — | — |
| REQ-GUEST-007 (double-join protection) | `functional-spec.md` §1, DEC-007 | `backend/app/services/guest/join_service.rb` — idempotency key resolution (create / replay / conflict), backed solely by the DB unique index on `idempotency_key` (CORR-005) | `backend/test/services/guest/join_service_test.rb`, `backend/test/services/guest/join_service_concurrency_test.rb` (real-thread concurrency), `backend/test/controllers/guest/queue_entries_controller_test.rb`; TEST-002, TEST-003, TEST-021 |
| REQ-STAFF-001 (login) | `functional-spec.md` §4 | — | — |
| REQ-STAFF-002 (view queue) | `functional-spec.md` §5 | — | — |
| REQ-STAFF-003 (view tables) | `functional-spec.md` §5 | — | — |
| REQ-STAFF-004 (seat by code) | `functional-spec.md` §6, `api-spec.md` seat | `backend/app/services/staff/confirm_seating_service.rb`, `backend/app/controllers/staff/seat_controller.rb` — `seating_code` lookup, atomic `ready`+`pending → seated`+`active`, verified under real PostgreSQL concurrency (Phase 5B.6); **no staff authentication** (no session/login mechanism exists yet — see `api-spec.md` seat "Implementation status") | TEST-004, TEST-005, TEST-006, TEST-015, plus `confirm_seating_service_test.rb`, `confirm_seating_service_concurrency_test.rb`, `seat_controller_test.rb` |
| REQ-STAFF-005 (release) | `functional-spec.md` §7, DEC-014 | — | TEST-008, TEST-026 |
| REQ-STAFF-006 (no-show) | `functional-spec.md` §8 | — | TEST-012 |
| REQ-STAFF-007 (no camera scanner) | — (product scope note only) | — | — |
| REQ-STAFF-008 (single staff UI, safe backend writes) | `architecture.md` §3 | — | TEST-001, TEST-004 |
| REQ-TABLE-001 (seed data) | DEC-001, `data-model.md` | — | TEST-016 |
| REQ-TABLE-002/003 (exclusivity) | `domain-model.md` INV-001–003 | — | TEST-004, TEST-007 |
| REQ-TABLE-004 (smaller group, larger table) | `allocation-spec.md` §1, `allocation-algorithm.md` §6 (`fit_score`) | `backend/app/services/allocation/decision_engine.rb`, now reachable end-to-end via `Allocation::Orchestrator` on Guest Join and lazy no-show expiration (Phase 5B.5.4) | TEST-023, `decision_engine_test.rb`, `orchestrator_test.rb` |
| REQ-TABLE-005 (max two-table combination) | DEC-002 | — | TEST-006 |
| REQ-TABLE-006 (atomic combined allocation) | `allocation-spec.md` §5, `allocation-algorithm.md` §18, INV-005 | `backend/app/services/allocation/reservation_service.rb`, now reachable end-to-end via `Allocation::Orchestrator` (Phase 5B.5.4) | TEST-005, TEST-006, `reservation_service_test.rb`/`reservation_service_concurrency_test.rb`, `orchestrator_test.rb` |
| REQ-TABLE-007/008 (combination lifecycle) | INV-004, INV-006 | — | TEST-022, TEST-008 |
| REQ-QUEUE-001/002 (not FIFO, position reflects availability) | `seating-allocation-policy.md`, `allocation-algorithm.md` (full document) | `backend/app/services/allocation/{decision_engine,reservation_service,orchestrator}.rb` — end-to-end via Guest Join and lazy no-show expiration triggers (Phase 5B.5.4); Release and Guest Leave triggers remain unintegrated (no implemented code path yet, `allocation-algorithm.md` §25c) | TEST-011, TEST-024, `orchestrator_test.rb`, `queue_entries_allocation_integration_test.rb` |
| REQ-QUEUE-003 (starvation protection) | `starvation-policy.md`, `allocation-algorithm.md` §9 | `backend/app/services/allocation/decision_engine.rb`, verified effective through the full orchestrated flow (Phase 5B.5.4) | TEST-009, TEST-010, `orchestrator_test.rb` |
| REQ-QUEUE-004 (dynamic position) | DEC-005, `allocation-algorithm.md` §11 (`total_score`) | Guest-facing `position` (Phase 5B.4) remains the chronological-rank approximation — the full `total_score`-based computation drives real allocation decisions now (Phase 5B.5.4) but is still not exposed as the guest-facing `position` number itself | TEST-011 |
| REQ-INFRA-001/002 (persistence, migrations) | `data-model.md` | — | TEST-016 |
| REQ-INFRA-003 (hard-path tests) | `test-strategy.md` | — | (this table) |
| REQ-INFRA-004 (runnable, Docker Compose) | `architecture.md` §6 | — | manual — `docker compose up` smoke test |
| REQ-FE-001–006 (frontend) | `functional-requirements.md` | — | TEST-003 (double-join) |
| DEC-011 (oversized-group rejection) | `functional-spec.md` §1, `allocation-spec.md` §0 | — (deferred; requires allocation/table-compatibility logic not yet built — see `api-spec.md` join "Implementation status") | TEST-025 |

## P1 requirements (only tracked once P0 is stable, per `scope-and-tradeoffs.md`)

| Requirement | Specification | Implementation | Test |
|---|---|---|---|
| REQ-SHOW-001 (live updates) | OPEN-002, `architecture.md` §7 | — | TEST-018 |
| REQ-SHOW-002 (cache + invalidation) | DEC-013, `api-spec.md` | — | TEST-017 |
| REQ-SHOW-003 (async notification) | `data-model.md` notification_jobs | — | TEST-019 |
| REQ-SHOW-004 (observability) | `01-requirements/non-functional-requirements.md` NFR-OBS-001 | — | manual |
| REQ-SHOW-005 (rate limiting) | — | — | TEST-020 |

## Not tracked here (by design)

Future-scope items (`07-future-evolution/`) have no requirement ID and are intentionally absent from this table — tracking them here would imply they're in scope for implementation.
