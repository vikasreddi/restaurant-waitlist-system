---
name: hard-path-testing
description: Use when writing or reviewing tests for concurrency, idempotency, atomicity, rollback, starvation, or state-transition correctness in this codebase. Load before writing any test for a hard path listed in documents/05-specifications/test-strategy.md, or when a test only covers the happy path and needs to be strengthened. Triggers on "concurrency test," "race condition test," "idempotency test," "atomicity test," "starvation test," "flaky under load."
---

# Hard-Path Testing

This project's hardest, highest-value tests prove that a domain invariant (`documents/03-architecture/domain-model.md`, INV-001–INV-015) holds under adversarial conditions — not that the happy path returns 200. The Phase 1 analysis flagged "writing happy-path tests while missing race conditions" as a top AI-agent risk on this project; this skill exists to counter that specific failure mode.

## The five hard-path categories and how to think about each

### Concurrency
Don't simulate concurrency with sequential calls that happen to interleave in your test's imagination — actually run two (or more) requests/transactions in parallel (threads, parallel test processes, or the framework's concurrency-testing utilities) against a shared test database, and assert on the *combined* outcome (e.g., "exactly one of these two succeeded," not "both individually succeeded when run one at a time"). A test that would pass even with no locking at all is not a concurrency test.

### Idempotency
Test both the sequential-retry case (same key, second call after the first completed) and the genuinely concurrent case (same key, both calls in flight at once — see TEST-002 vs. TEST-021 in `test-strategy.md`). Also test the negative case: a *different* key from what should be a *new* attempt must not be treated as a duplicate.

### Atomicity
For any "both-or-neither" operation (combined-table allocation, INV-005), the test that matters is the failure-injection case: force one half of the operation to be unavailable (e.g., a competing transaction holds the second table) and assert that *neither* table ends up allocated — not just that the happy "both free" case works. A rollback that isn't tested is a rollback that isn't proven.

### Starvation / fairness
Test the actual guarantee as corrected in `documents/02-product-decisions/starvation-policy.md` — priority once the complete configuration is available, not an absolute wait-time ceiling. Also explicitly test the negative case from the brief's own worked example: a lone freed table that is only half of a protected group's requirement must **not** be reserved for them while the other half is still occupied (INV-013's critical rule) — this is easy to get backwards, so it needs its own test, not just an implication of the positive case.

### State transitions
Every entity state machine in `domain-model.md` (QueueEntry: waiting/seated/left/no_show; Table: free/occupied/combined) should have a test for each valid transition and at least one test asserting an invalid transition is rejected (e.g., seating an already-seated entry, releasing an already-free table, marking a terminal entry as no-show again should be a safe no-op, not a silent corruption).

## Structuring a hard-path test

1. Name it after the invariant or `TEST-*` ID it proves, not the method it calls (`test_combined_allocation_is_all_or_nothing`, not `test_seat_endpoint`).
2. State the invariant being proven in a comment or test description — one line, referencing the `INV-*`/`TEST-*` ID.
3. Set up the adversarial condition explicitly (the race, the retry, the partial failure) rather than relying on default test-framework ordering.
4. Assert on system state after the dust settles, not just the return value of one call — e.g., after a combined-allocation race, assert both tables' actual DB state, not just that one API call returned 200 and the other 409.

## Anti-patterns to reject in review

- A "concurrency test" that calls the same method twice in a row on one thread.
- An idempotency test that only checks the second call doesn't 500, without checking the database has exactly one row.
- A starvation test that only checks the positive case (protected group eventually seated) without the negative case (lone table not reserved prematurely).
- Deleting or loosening an assertion because the test was "flaky" without first determining whether the flakiness reveals a real race condition in the implementation.
