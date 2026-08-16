# FUTURE — Fairness Debt (NOT IMPLEMENTED)

**Status: future evolution only. Not implemented in the two-day core (DEC-008). Nothing in this document is built.**

## Concept

A future production scheduler could track, for each waiting group, a "fairness debt" that accumulates specifically when that group experiences a genuine missed compatible seating opportunity (see `missed-opportunities.md` for the precise definition). Future priority could then be computed from `waiting time + configuration scarcity + fairness debt`, rather than wait-time alone.

## Why it's deferred

- Requires persisting historical scheduling state per group (which opportunities were available and passed over), adding a new class of data and bookkeeping not needed for the P0 starvation guarantee.
- The simpler maximum-wait-threshold policy (`02-product-decisions/starvation-policy.md`) already satisfies "no group waits forever" without it.
- Testing a debt-weighted scheduler correctly (proving it doesn't introduce new starvation modes of its own) is a meaningfully larger effort than the two-day window supports.

## What it would need if built later

- A durable record of each missed-opportunity event per group (see `missed-opportunities.md`).
- A decision on debt decay/reset (does debt persist across visits? within one visit only?).
- A decision on how debt is weighted against raw wait time and scarcity, and how that weighting is validated against not accidentally starving *other* groups.
- Re-validation of the entire test suite in `05-specifications/test-strategy.md` against the new prioritization logic.

## Constraint carried forward

Scarcity/debt-based signals, if ever built, **must not automatically make large groups win** — this constraint from the current policy (`seating-allocation-policy.md` Stage 4) is expected to survive into any future refinement, not be silently dropped.
