# Starvation / Fairness Policy

Status: **Approved (DEC-004).** This is the policy the README's "the rule you chose so that no group waits forever, why you chose it, and what it costs you" section must draw from directly.

## The problem

A large group (needing two adjacent tables, e.g., a group of 6) can be waiting while small groups continuously and legitimately claim single tables as they turn over. Because the large group needs *two specific tables free at the same instant*, and small-group traffic keeps consuming single tables one at a time, that joint condition may never arise on its own — the large group could wait indefinitely even though the restaurant is actively seating people all evening (REQ-QUEUE-003).

## Who is vulnerable

Groups requiring a combined configuration (per the seed data, effectively groups of 5–8 needing two adjacent tables) are the vulnerable population. Groups that fit a single table are not structurally at risk of this failure mode, since any one freed compatible table can seat them.

## Chosen policy

A **configurable maximum-wait threshold** (illustrated as 20 minutes for this take-home; explicitly not a claimed real-restaurant number). Below the threshold, the group is seated under ordinary compatibility + smallest-fit + wait-time-aging rules (`seating-allocation-policy.md`, Stages 1–4). At and beyond the threshold, the group becomes **starvation-protected**: when its complete required configuration becomes simultaneously available, it receives priority for that configuration over other groups that only just became eligible for it.

Protection is scoped to the **complete seating opportunity**, never a lone table — a single free table that is only half of what a protected group needs is not withheld from smaller groups while its partner is still occupied, since holding it back would not actually help the protected group and would only reduce table utilization.

### The precise guarantee (corrected — see revision note below)

> Maximum-wait protection guarantees priority when the group's complete compatible seating configuration becomes available. It does not guarantee an absolute maximum total waiting time.

This is deliberately weaker than "no group waits forever in absolute time." It guarantees that once a protected group's complete configuration exists, competing traffic cannot indefinitely displace it from that configuration. It does **not** guarantee the configuration itself will appear within any fixed time — if the qualifying configuration is rare (e.g., few adjacent large-capacity pairs exist), the group can still wait longer than the threshold in absolute terms. This distinction is stated explicitly rather than glossed over; see "What it costs," below, for the direct consequence.

## Why this policy

- It gives waiting large groups a concrete, testable priority guarantee the moment their configuration becomes available — see the precise guarantee above. This is deterministic and simple to implement and test within two days: a single comparison (wait time vs. threshold) gates a priority rule that only ever applies at the exact moment a full configuration opens up.
- It avoids the complexity (and testing burden) of a scarcity- or fairness-debt-weighted global scheduler (see `07-future-evolution/`), which was considered and explicitly deferred (DEC-008).
- It avoids the opposite failure mode — permanently reserving a lone table the moment it frees, which would waste capacity and could itself starve smaller groups indefinitely if the large group's second table takes a long time to free.

## What it costs

- **Utilization cost:** none while below the threshold — small groups are never blocked pre-threshold. Above the threshold, the cost is scoped and bounded: once a protected group's full configuration appears, one or more smaller groups that would otherwise have been eligible for those specific tables at that moment are passed over in favor of the protected group. This is a deliberate, bounded fairness trade, not a general slowdown.
- **Latency cost to small groups:** in the specific, comparatively rare moment a full large-group configuration opens up while a protected group is waiting, small groups lose that particular seating opportunity and wait for the next one. This is the direct, acknowledged cost the brief asks us to name.
- **No guaranteed maximum wait time in absolute terms:** the threshold guarantees *priority once the configuration is available*, not a hard ceiling on total wait — if the qualifying configuration itself is rare (e.g., only two 6-seat-equivalent adjacent pairs exist in the seed data), a protected group could still wait longer than the threshold in absolute terms, just no longer than necessary once compared to competing traffic for that same configuration. This is an accepted limitation, not silently glossed over.
- **Threshold tuning is a judgment call:** 20 minutes is illustrative; too short reduces the policy's value (constant protection-mode churn), too long weakens the priority guarantee's practical usefulness. Not resolved further here — implementation-time configuration.

## What was explicitly rejected

- **Reserve-on-first-free:** holding a lone freed table indefinitely for a large group the moment it appears. Rejected — directly contradicts the brief's own worked example (do not reserve T1 indefinitely while T2 is occupied) and wastes capacity with no guarantee the second table frees soon.
- **Fairness-debt/scarcity global optimization:** rejected for the two-day core as disproportionate complexity (DEC-008); documented as future evolution.
- **Permanent large-group priority:** rejected — contradicts "seating is not first-come-first-served" applied in the other direction, and isn't what the brief asks for (it asks for a starvation *bound*, not large-group primacy).

## Revision note (Session 2 human review)

The original version of this document stated the policy "directly and provably satisfies 'no group waits forever'" with the wait "bounded by how long it takes for that configuration to next become available" — implying an effective upper bound on total wait time. That was an overstatement: it is inconsistent with the "No guaranteed maximum wait time in absolute terms" limitation already listed above. Corrected to the precise guarantee stated at the top of this document. See `06-ai-working-record/ai-corrections.md` CORR-001.
