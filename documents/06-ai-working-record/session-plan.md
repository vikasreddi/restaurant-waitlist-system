# Session Plan (Guidance, Not a Mandatory Sequence)

Principle: **one bounded objective per agent session.** This keeps each session's diff reviewable, keeps context focused on one part of the specification, and matches the deliverable's requirement to show planned, bounded AI-agent work rather than one unbounded "build the whole app" session.

## Suggested breakdown

```
Session A — Project bootstrap only
Session B — Database/domain model only
Session C — Join/idempotency only
Session D — Allocation engine only
Session E — Hard-path testing
Session F — Staff APIs
Session G — Guest frontend
Session H — Staff frontend
Session I — Redis/live updates
Session J — Sidekiq notification
Session K — Final review
```

This is a reasonable default ordering (infrastructure and data model before behavior, backend before frontend, P0 before P1), **not a forced sequence.** If the specification or an early session reveals a better order (e.g., building the allocation engine and its hard-path tests in the same session because they're genuinely inseparable — see `documents/05-specifications/test-strategy.md` principle 1, every invariant needs a test that would fail if violated), take it. What must not happen is collapsing multiple unrelated objectives (e.g., "domain model + staff frontend") into one session just to move faster.

## What "bounded" means in practice

Each session should be able to state, before starting:
- Which requirement IDs it's implementing (`documents/01-requirements/traceability.md`).
- Which specification section governs the behavior (`documents/05-specifications/`).
- What "done" looks like (acceptance criteria + tests), not just "code written."
- What is explicitly out of scope for this session (so a later session isn't silently skipped by assuming it was covered).

And after finishing:
- `documents/01-requirements/traceability.md` updated for whatever it completed.
- `documents/06-ai-working-record/session-log.md` updated with what happened, referencing the requirement IDs and any `BLOCKED — HUMAN DECISION REQUIRED` reports raised (`CLAUDE.md` §When scope is exceeded).
- Any genuine agent mistake caught during the session recorded in `ai-corrections.md` (never fabricated — see that file's standing rule).

## Relationship to the agents in `.claude/agents/`

A session is a scope boundary, not necessarily a single agent invocation. Within one session, the expected flow is: `spec-reviewer` checks the plan against the relevant spec → the appropriate implementation agent (`backend-domain-agent` for backend sessions) implements within that scope → `test-engineering-agent` adds/extends hard-path tests → `code-review-agent` reviews the result → human review → commit/checkpoint. Not every session needs every agent (e.g., Session A, project bootstrap, may not need `test-engineering-agent` beyond a smoke test), but the ordering (review before code, tests alongside code, review after code) should hold within any session that touches domain logic.
