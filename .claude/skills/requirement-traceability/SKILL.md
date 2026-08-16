---
name: requirement-traceability
description: Use when mapping a requirement ID (REQ-*) to its specification, implementation, and tests, or when updating documents/01-requirements/traceability.md after implementing or testing something. Use during implementation planning (to confirm scope) and during code review (to check coverage). Triggers on "which requirement does this cover," "update traceability," "is REQ-* implemented," "map requirements to code."
---

# Requirement Traceability

This project traces every P0/P1 requirement through four stages:

```
Requirement (REQ-*)  →  Specification  →  Implementation  →  Test (TEST-* or file)
```

The live map is `documents/01-requirements/traceability.md`. It is a plain Markdown table — deliberately not a database, ticketing system, or generated report. Keep it that way; do not build tooling around it beyond what's needed to keep the table accurate.

## Using this skill during planning

Before starting an implementation task:
1. Identify the `REQ-*` ID(s) the task covers. If the task doesn't map to any existing requirement ID, stop — either it's out of scope (check `documents/02-product-decisions/scope-and-tradeoffs.md`) or the traceability table is missing a row, which is itself worth flagging.
2. Look up the "Specification" column for that requirement in `traceability.md` and read that section before writing code. Do not implement from memory of what the requirement "probably means."
3. Confirm the requirement's priority (P0 vs. P1 vs. Future) — do not implement a P1/Future item while P0 work for the same area is incomplete (`CLAUDE.md` engineering rules).

## Using this skill during/after implementation

When a task is done:
1. Fill in the "Implementation" column with the file/module that implements the behavior (e.g., `app/services/seating_allocator.rb`).
2. Fill in the "Test" column with the `TEST-*` ID from `documents/05-specifications/test-strategy.md` if one exists, or the test file path, or `manual` with a one-line note if no automated test applies.
3. Never fill in "Implementation" without a corresponding "Test" entry — an implemented-but-untested row is a signal the task isn't actually done, per `CLAUDE.md`'s "claim completion without verification" prohibition.

## Using this skill during review

`code-review-agent` should cross-check the diff under review against `traceability.md`: does the changed code correspond to a row that was previously `—`/`—` and is now filled in correctly? Does anything in the diff implement a requirement ID that traceability.md doesn't list at all (possible scope creep — check against `documents/07-future-evolution/` and `scope-and-tradeoffs.md`)?

## What "lightweight" means here

- No automated linkage/CI enforcement is required for this two-day project — a human (or `code-review-agent`) spot-checking the table against the diff is sufficient.
- Do not add columns beyond Requirement / Specification / Implementation / Test unless a real recurring need shows up — resist the urge to make this more elaborate than the assignment calls for.
