# Seating Allocation Policy

Status: **Approved (DEC-003).** This document is the authoritative specification of the seating algorithm. Agents must not alter this policy; see `06-ai-working-record/ai-development-approach.md` for governance.

Name: **Compatibility-Aware Aging with Maximum-Wait Protection**

*(Revised in Session 2 human review — previously named "...Weighted Aging..."; no concrete weighting formula was ever defined, so "Weighted" was dropped as an overstated name. See `06-ai-working-record/ai-corrections.md` CORR-002. The six stages below are unchanged.)*

Design goal: deterministic, simple enough to implement correctly within a two-day window, and directly satisfying REQ-QUEUE-001 (not FIFO), REQ-QUEUE-002 (position reflects table availability), and REQ-QUEUE-003 (starvation protection as precisely defined in `starvation-policy.md`).

## Not naive greedy table iteration

This policy is explicitly **not**:

```text
for each table:
    find first group that fits
    seat it
```

That pattern considers one table at a time in isolation and cannot correctly express either smallest-fit preference (Stage 3) or starvation protection (Stage 5), both of which require reasoning over *all* currently compatible configurations and *all* currently eligible waiting groups together before committing an allocation. The global reasoning order is:

```text
Available table configurations
        ↓
Compatible waiting groups
        ↓
Determine eligible allocations
        ↓
Apply starvation protection
        ↓
Prefer smallest suitable configuration
        ↓
Apply waiting-time aging
        ↓
Select allocation
        ↓
Atomic database transaction
```

The exact implementation algorithm can be finalized in the implementation phase, but it must preserve this global reasoning shape — see `05-specifications/allocation-spec.md` for the pseudocode-level specification.

## Stage 0 — Reject oversized groups at join time

Before a group ever enters the queue, its size is checked against the largest seatable configuration in the seed data (a single table or an adjacent two-table combination, DEC-002). If no configuration can ever seat it, the join is rejected with a clear validation error rather than creating an entry the policy can never resolve (DEC-011). Every `waiting` entry the policy reasons about from Stage 1 onward is therefore guaranteed to be seatable by *some* currently-or-eventually-available configuration.

## Stage 1 — Determine seating requirements

For a waiting group, determine which seating configurations (single tables or adjacent two-table combinations) have sufficient capacity.

Examples:
- Group of 2 → any table with capacity ≥ 2 (a 2-seat table, or a 4-seat table if needed — REQ-TABLE-004).
- Group of 4 → any table/configuration with capacity ≥ 4.
- Group of 6 → a 6-seat table, or an adjacent pair whose combined capacity ≥ 6.

## Stage 2 — Find compatible available configurations

A group competes only for configurations that can actually seat it. A 6-person group never competes for a single 4-seat table; a 2-person group is not blocked from a free 4-seat table just because larger tables "should" be reserved for larger groups (no permanent size binding, DEC-001).

## Stage 3 — Prefer the smallest suitable available configuration

Among currently available compatible configurations, prefer the smallest one that fits the group, to conserve larger capacity for groups that need it.

Example: group of 2, T1 (2 seats) and T2 (4 seats) both exist. If T1 is free, prefer T1. If T1 is occupied and T2 is free, the group uses T2 rather than wait unnecessarily for T1 to free.

## Stage 4 — Wait-time aging

When multiple waiting groups compete for the *same* compatible configuration opportunity, longer wait time increases priority among them.

Explicitly **not** implemented: arbitrary permanent group-size weighting. Group size determines *compatibility* (which configurations a group can use), not an unconditional rule that larger groups outrank smaller ones. This preserves REQ-QUEUE-001 ("not FIFO," but also not "biggest group always wins").

## Stage 5 — Maximum-wait / starvation protection

A configurable maximum-wait threshold (illustrated as 20 minutes; a take-home assumption, not a claimed restaurant requirement) governs when a group becomes **starvation-protected**.

- **Before** the threshold: normal compatibility + smallest-fit + wait-time aging (Stages 1–4) apply, unmodified.
- **After** the threshold: the group becomes starvation-protected, per the critical rule below.

### Critical rule — protection applies to the complete opportunity, not a single table

Starvation protection protects the **complete required seating configuration**, never an individual table in isolation.

Worked example: a 6-person group requires T1 + T2 (adjacent, combined capacity ≥ 6).
- If T1 is FREE and T2 is OCCUPIED, the system does **not** reserve T1 indefinitely for the protected group — the group cannot use T1 alone, so holding it back from smaller groups would waste capacity without helping the protected group.
- Only when T1 **and** T2 are simultaneously available, forming a valid configuration for that group, does the protected group receive priority for that specific configuration over other groups that just became eligible for it.

**Precise guarantee:** maximum-wait protection guarantees priority when the group's complete compatible seating configuration becomes available. It does **not** guarantee an absolute maximum total waiting time — if the qualifying configuration itself is rare, the group can still wait longer than the threshold in absolute terms; the guarantee is about priority *relative to competing traffic* once the configuration exists, not a hard ceiling on wait duration. See `starvation-policy.md` for the full write-up of what this policy does and does not promise, and its cost.

See `07-future-evolution/missed-opportunities.md` for the deferred refinement that would track *how often* this near-miss (T1 free, T2 occupied) happens.

## Stage 6 — Atomic allocation

When a configuration is selected for a group:
- Single-table allocation is transaction-safe (protected against concurrent competing allocation attempts).
- Combined-table allocation reserves all required tables atomically.
- If any required table cannot be acquired at commit time (e.g., lost a race to another allocation), the entire allocation fails — no partial combination is ever left in place.
- This directly implements REQ-TABLE-006 and INV-005 (`03-architecture/domain-model.md`).
- **The outcome of this stage is the group becoming `ready`** (table(s) reserved, seating code generated) — **not** `seated`. Seating happens later, when staff confirm the code (`05-specifications/allocation-spec.md` §5a) — a separate operation this policy does not govern. This policy's job ends the moment a configuration is committed to a group.

## Explicitly out of scope for this policy (see `07-future-evolution/`)

- Configuration-scarcity weighting (a 6-person group has fewer compatible configurations than a 2-person group — not factored into priority now).
- Missed-opportunity tracking and fairness debt.
- Any global/optimal scheduling (e.g., holding a table briefly in anticipation of a better global assignment).

## Relationship to position (`03-architecture/domain-model.md`, DEC-005)

A guest's displayed position is a rank derived from this policy's current state (which groups are compatible with which currently-or-soon available configurations, and current wait-time ordering among them), recomputed on relevant events. It is not this policy's output frozen at join time.
