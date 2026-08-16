---
description: Check hard-path test coverage against documents/05-specifications/test-strategy.md and report gaps
---

Check the current state of hard-path test coverage:

1. Read `documents/05-specifications/test-strategy.md` for the full `TEST-*` list (P0 hard-path tests TEST-001–TEST-016, TEST-021–TEST-026; P1 tests TEST-017–TEST-020).
2. If $ARGUMENTS is provided, scope to that area (e.g., `/test-hard-paths idempotency`, `/test-hard-paths starvation`); otherwise cover all of them.
3. For each in-scope `TEST-*` ID, determine whether an actual test exists in the codebase and whether it genuinely exercises the hard path (real concurrent execution for concurrency tests, real failure injection for atomicity/rollback tests — see the `hard-path-testing` skill for what counts) rather than merely asserting a happy-path return value.
4. If tests exist, you may run them (read-only — do not edit test files as part of this command; that's a separate implementation task).
5. Update `documents/01-requirements/traceability.md`'s Test column for anything you confirm is covered.

Report as a table: `TEST-ID | Exists? | Genuinely exercises the hard path? | Notes`. Flag any `TEST-*` ID with no corresponding test as a gap — do not silently skip it. Do not write new tests as part of this command; that's the `test-engineering-agent`'s job once gaps are identified and scoped.
