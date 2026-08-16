# FUTURE — Shared Tables (NOT IMPLEMENTED)

**Status: future evolution only. Not implemented in this assignment (DEC-009). The current invariant — one group per table — holds throughout the two-day scope. Nothing in this document is built.**

## Concept

A future guest experience could offer an "I am willing to share a table" option, allowing unrelated small groups to be matched onto a single table that neither alone would fully occupy, improving utilization on busy nights.

## Why it's deferred

Directly and explicitly excluded from scope (DEC-009) — the brief's core invariant throughout is that a table holds exactly one group at a time (`03-architecture/domain-model.md` INV-001). Introducing shared tables would require:

- **Consent flow:** guests must opt in, and understand who/what they're agreeing to share with.
- **Privacy:** two unrelated groups' phone numbers/identities must not be exposed to each other.
- **Matching logic:** a new allocation dimension beyond capacity/adjacency — compatible party sizes, timing, and consent must all align.
- **Table lifecycle changes:** a table's occupancy state would need a notion of partial capacity in use, not just free/occupied/combined, changing every invariant in `03-architecture/domain-model.md` that currently assumes single-group occupancy.
- **New failure modes:** what happens if one shared party leaves early, or if consent is withdrawn mid-wait — none of which exist in the current model.

## What it would need if built later

- A redesigned `Table` occupancy model supporting partial capacity.
- A consent and matching subsystem, likely with its own state machine.
- A full re-derivation of the allocation policy (`02-product-decisions/seating-allocation-policy.md`) to account for partial-fit configurations, plus a corresponding rewrite of the starvation policy's "complete configuration" rule, since "complete" would no longer map cleanly to "one or two whole tables."
- A substantially expanded test-strategy to cover the new state space.

This is flagged as a genuine future capability worth considering, not a corner cut for lack of interest — but it changes enough of the core model that it is explicitly out of scope for a two-day build.
