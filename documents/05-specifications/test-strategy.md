# Test Strategy

Status: specification only — no tests are written yet. Prioritizes business correctness over controller/wiring tests, per the brief and the Phase 1 analysis's flagged AI-agent risk of "writing happy-path tests while missing race conditions."

## Principles

1. Every domain invariant in `03-architecture/domain-model.md` has at least one test that would fail if the invariant were violated.
2. Concurrency and atomicity tests exercise real concurrent execution (parallel requests/transactions against a real or realistic test database), not just sequential calls that assume a lock exists.
3. Controller/route-wiring tests are secondary — valuable for coverage, but not a substitute for the tests below.

## P0 — Hard-path tests

| ID | Test | Invariant/Requirement | Category |
|---|---|---|---|
| TEST-001 | Two simultaneous join requests for different guests both succeed with distinct entries | INV-001, REQ-GUEST-001 | Concurrent |
| TEST-002 | A retried join (same idempotency key) results in exactly one `QueueEntry` | INV-007, REQ-GUEST-007 | Duplicate/retry |
| TEST-003 | Double-submitting "Join" from the client results in exactly one entry end-to-end | REQ-FE-006 | Duplicate/retry |
| TEST-004 | Two seat operations racing for the same single table: exactly one succeeds, the other fails cleanly | INV-001, INV-003 | Concurrent, atomicity |
| TEST-005 | Combined-table seating: simulate one required table becoming unavailable mid-allocation — the whole allocation fails, neither table is touched | INV-005, INV-008 | Transaction/atomicity |
| TEST-006 | Two groups racing for the same adjacent pair: exactly one is seated on it, the other remains `waiting` with no partial state | INV-005, INV-008 | Concurrent, atomicity |
| TEST-007 | Allocating an already-occupied table is rejected | INV-002, INV-003 | Correctness |
| TEST-008 | Releasing a group's seating assignment (by `queue_entry_id`) makes its table(s) immediately eligible for the next matching group | INV-006, INV-010, DEC-014 | Happy path |
| TEST-009 | Starvation scenario: a continuous stream of small-group joins/seats does not indefinitely block a group past the maximum-wait threshold once its full configuration becomes available | INV-013, REQ-QUEUE-003 | Starvation |
| TEST-010 | Starvation protection does not reserve a lone free table that is only half of a protected group's requirement | INV-013 (critical rule, `starvation-policy.md`) | Starvation |
| TEST-011 | A group's position is recomputed correctly (not FIFO) when a smaller table frees ahead of a larger group's needed configuration | REQ-QUEUE-001/002 | Correctness |
| TEST-012 | No-show transitions a `waiting` entry to a terminal state distinct from `left`; cannot later be seated | INV-011 | Edge case |
| TEST-013 | A guest reopening the page with a valid active-visit token for a non-terminal entry resumes the same entry, not a new one | REQ-GUEST-004, DEC-006 | Edge case |
| TEST-014 | A guest reopening the page with a token for a terminal entry does not resume it as an active session | DEC-006 | Edge case |
| TEST-015 | Seating with an invalid, already-used, or unknown code is rejected with no state change | `05-specifications/api-spec.md` | Failure case |
| TEST-016 | Migrations apply cleanly to an empty database and seed data matches DEC-001 | REQ-INFRA-001/002 | Infra |
| TEST-021 | A genuinely concurrent duplicate join (two requests racing with the *same* idempotency key, not a sequential retry) still results in exactly one `QueueEntry` | INV-007, NFR-IDEM-001 | Concurrent, duplicate/retry |
| TEST-022 | While a `TableCombination` is active, neither member table can be independently allocated to a different group | INV-004 | Correctness |
| TEST-023 | A smaller group is seated on a larger single table when no smaller-capacity table is currently free (REQ-TABLE-004) | REQ-TABLE-004 | Happy path |
| TEST-024 | A large group is never offered/seated on a single table whose capacity is insufficient, even if that table is free | Stage 1-2, `seating-allocation-policy.md` | Correctness |
| TEST-025 | A join whose group size exceeds every seatable configuration (single or combined) is rejected at submission with a validation error and no entry is created | DEC-011 | Validation |
| TEST-026 | Release resolves and frees a group's complete seating assignment via its `queue_entry_id`; there is no code path that releases only one member of a combined pair | DEC-014, INV-015 | Transaction/atomicity |

**Coverage of the Session 2 review's explicit 12-item test list:** (1)→TEST-002, (2)→TEST-021, (3)→TEST-007/TEST-004, (4)→TEST-005/TEST-006, (5)→TEST-005, (6)→TEST-022, (7)→TEST-008, (8)→TEST-023, (9)→TEST-024, (10)→TEST-009, (11)→TEST-010, (12)→TEST-011.

## P1 — Tests added if P1 features are built

| ID | Test | Requirement | Category |
|---|---|---|---|
| TEST-017 | Guest's cached position is invalidated and updated after a seat/release/no-show/join event | REQ-SHOW-002 | Cache invalidation |
| TEST-018 | Live-update mechanism reflects a position change without manual refresh | REQ-SHOW-001 | Integration |
| TEST-019 | Notification job retries on failure without sending a duplicate notification | REQ-SHOW-003 | Async/idempotency |
| TEST-020 | Rate limiting rejects excessive guest requests without blocking legitimate traffic | REQ-SHOW-005 | Security |

## Explicitly out of scope for testing (Future features)

- Fairness debt / missed-opportunity tracking (`07-future-evolution/`).
- Shared-table flows.

## Highest-value tests (P0 within P0)

Marked as the tests that most directly demonstrate the brief's core evaluation criteria: **TEST-001, TEST-002, TEST-004, TEST-005, TEST-006, TEST-009, TEST-010**. These map one-to-one to "idempotent join," "combining tables," and "no group waits forever" — the three requirements the brief calls out most explicitly as hard.
