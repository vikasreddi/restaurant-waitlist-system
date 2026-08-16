# Requirement Traceability

Lightweight, living map: **Requirement → Specification → Implementation → Test.** Updated as implementation proceeds (per session, per task) — not a one-time artifact. Kept intentionally simple: a Markdown table, not a tracking system. Use the `requirement-traceability` skill when updating this file.

Status: **Phase 5A = infrastructure/bootstrap only** (Rails/React/PostgreSQL/Docker Compose runnable foundation, no business logic). No business requirement below has been implemented yet — the "Implementation" and "Test" columns remain `—` for every row until Phase 5B (Domain Model + Migrations + Seed Data) begins. This file should be updated in the same commit/checkpoint as the code and tests it describes, not after the fact from memory.

## How to use this file

- When starting an implementation task, find the requirement ID(s) it covers below and confirm the "Specification" column points to what you're about to build.
- When the task is done, fill in "Implementation" (file/module) and "Test" (test ID from `05-specifications/test-strategy.md`, or file path) for each requirement it satisfies.
- If a requirement has no realistic test (e.g., a UI copy detail), write `manual` in the Test column with a one-line note, not a blank.
- Never mark a requirement done in this file without a corresponding test or an explicit, noted reason one isn't applicable.

## P0 requirements

| Requirement | Specification | Implementation | Test |
|---|---|---|---|
| REQ-GUEST-001 (join) | `05-specifications/functional-spec.md` §1, `api-spec.md` join | — | — |
| REQ-GUEST-002 (view position) | `functional-spec.md` §9, `api-spec.md` current | — | — |
| REQ-GUEST-003 (leave) | `functional-spec.md` §3 | — | — |
| REQ-GUEST-004 (recover visit) | `functional-spec.md` §2, DEC-006 | — | TEST-013, TEST-014 |
| REQ-GUEST-005 (seating code) | `api-spec.md` current | — | — |
| REQ-GUEST-006 (no cross-visit history) | DEC-006 | — | — |
| REQ-GUEST-007 (double-join protection) | `functional-spec.md` §1, DEC-007 | — | TEST-002, TEST-003, TEST-021 |
| REQ-STAFF-001 (login) | `functional-spec.md` §4 | — | — |
| REQ-STAFF-002 (view queue) | `functional-spec.md` §5 | — | — |
| REQ-STAFF-003 (view tables) | `functional-spec.md` §5 | — | — |
| REQ-STAFF-004 (seat by code) | `functional-spec.md` §6, `api-spec.md` seat | — | TEST-004, TEST-005, TEST-006, TEST-015 |
| REQ-STAFF-005 (release) | `functional-spec.md` §7, DEC-014 | — | TEST-008, TEST-026 |
| REQ-STAFF-006 (no-show) | `functional-spec.md` §8 | — | TEST-012 |
| REQ-STAFF-007 (no camera scanner) | — (product scope note only) | — | — |
| REQ-STAFF-008 (single staff UI, safe backend writes) | `architecture.md` §3 | — | TEST-001, TEST-004 |
| REQ-TABLE-001 (seed data) | DEC-001, `data-model.md` | — | TEST-016 |
| REQ-TABLE-002/003 (exclusivity) | `domain-model.md` INV-001–003 | — | TEST-004, TEST-007 |
| REQ-TABLE-004 (smaller group, larger table) | `allocation-spec.md` §1 | — | TEST-023 |
| REQ-TABLE-005 (max two-table combination) | DEC-002 | — | TEST-006 |
| REQ-TABLE-006 (atomic combined allocation) | `allocation-spec.md` §5, INV-005 | — | TEST-005, TEST-006 |
| REQ-TABLE-007/008 (combination lifecycle) | INV-004, INV-006 | — | TEST-022, TEST-008 |
| REQ-QUEUE-001/002 (not FIFO, position reflects availability) | `seating-allocation-policy.md` | — | TEST-011, TEST-024 |
| REQ-QUEUE-003 (starvation protection) | `starvation-policy.md` | — | TEST-009, TEST-010 |
| REQ-QUEUE-004 (dynamic position) | DEC-005 | — | TEST-011 |
| REQ-INFRA-001/002 (persistence, migrations) | `data-model.md` | — | TEST-016 |
| REQ-INFRA-003 (hard-path tests) | `test-strategy.md` | — | (this table) |
| REQ-INFRA-004 (runnable, Docker Compose) | `architecture.md` §6 | — | manual — `docker compose up` smoke test |
| REQ-FE-001–006 (frontend) | `functional-requirements.md` | — | TEST-003 (double-join) |
| DEC-011 (oversized-group rejection) | `functional-spec.md` §1, `allocation-spec.md` §0 | — | TEST-025 |

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
