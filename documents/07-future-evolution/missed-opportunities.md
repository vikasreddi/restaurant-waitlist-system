# FUTURE — Missed Compatible Opportunity Tracking (NOT IMPLEMENTED)

**Status: future evolution only. Not implemented in the two-day core (DEC-008). Nothing in this document is built.**

## Definition

A missed compatible opportunity occurs only when all three of the following hold:

1. The complete valid seating configuration required by a waiting group was simultaneously available.
2. Another allocation consumed that configuration instead.
3. The waiting group therefore remained unseated.

## Worked example

- Group A = 4 people, Group B = 4 people, Group C = 6 people.
- Table T1 = 4 seats, Table T2 = 4 seats, T1 adjacent to T2 (T1+T2 can seat C).
- If A is seated at T1 and B is seated at T2 (both individually, at the same or different moments before T1+T2 were ever simultaneously free together), C experienced a **genuine missed opportunity** only if there was a moment when T1 and T2 were *both* free at once and one of those allocations took a table from that specific joint window.
- Contrast: if T1 is free and T2 is occupied (by anyone), there is **no complete configuration for C** at that moment — this is *not* a missed opportunity, per the same rule that governs starvation protection in `02-product-decisions/starvation-policy.md` (protection/tracking only ever applies to the complete configuration, never a lone table).

## Why it's deferred

- Requires detecting and recording a specific joint-availability window and which allocation "took" it — a nontrivial event-ordering problem to get right and test, beyond what the current maximum-wait threshold policy needs.
- Valuable primarily as an input to `fairness-debt.md`, which is itself deferred (DEC-008).

## What it would need if built later

- An event log capturing every configuration's free/occupied transitions with enough precision to detect true simultaneous availability windows.
- A defined query/trigger that evaluates, on every allocation, whether any *other* currently-waiting group's complete requirement was satisfied by the tables just consumed.
- Careful test coverage distinguishing genuine missed opportunities from the "only half the configuration was ever free" case, since that distinction is exactly what the brief's own worked example (`starvation-policy.md`) warns against getting wrong.
