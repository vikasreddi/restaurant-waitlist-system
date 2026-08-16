# Allocation Algorithm Specification

Status: **specification only, locked for implementation (Phase 5B.5.1).** This document makes `02-product-decisions/seating-allocation-policy.md` and `starvation-policy.md` precise enough to implement without inventing business rules. It supersedes `allocation-spec.md` §2–§4 wherever the two disagree (see §23 "Reconciliation with `allocation-spec.md`" below); `allocation-spec.md` §0–§1 and §5–§8 (eligibility, transaction shape, staff confirmation, release, lazy expiration) are unchanged and remain authoritative as written.

No application code was written or modified to produce this document (Phase 5B.5.1 is analysis/specification only, per its governing prompt).

## 1. Purpose

Answer, precisely and with explicit formulas, how the allocation service (Phase 5B.5.2+) selects which waiting `QueueEntry` gets which table configuration, whenever a configuration becomes available. Deterministic, explainable, testable — never an unconstrained AI runtime decision (§16).

## 2. Inputs

At the moment an allocation pass runs:
- The current set of **free** tables (`Table` rows with no non-released `SeatingAssignmentTable` claim, per `domain-model.md` §2 — derived, never stored).
- The current set of **waiting** `QueueEntry` rows (`status = 'waiting'`).
- Static seed data: table capacities, `TableAdjacency` pairs (DEC-001, DEC-002).
- The current wall-clock time (`now`).
- Configuration values (§19).

No other input. In particular: no prediction of future arrivals or future releases (`seating-allocation-policy.md` "Explicitly out of scope").

## 3. Hard eligibility rules (compatibility — never overridable by priority)

A **configuration** is either:
- `SingleTable(T)` — one free table, or
- `CombinedPair(T1, T2)` — exactly two free tables that are a valid `TableAdjacency` pair (never three or more, DEC-002/INV-012; never an invented adjacency).

A configuration's **capacity** is `T.capacity` (single) or `T1.capacity + T2.capacity` (combined).

A `(entry, configuration)` pair is **compatible** iff:

```
configuration.capacity >= entry.group_size
```

This is a **hard gate**, evaluated before any scoring. No score, weight, aging value, or starvation flag can ever make an incompatible pair eligible (§4 of the governing prompt). Every `waiting` entry is already guaranteed seatable by *some* eventual configuration, because oversized groups are rejected at join time (`allocation-spec.md` §0, DEC-011) — so "no compatible configuration exists *right now*" (§13) means "wait for one to free," never "this group can never be seated."

## 4. Table configuration generation

```
function generate_available_configurations():
    configs = []
    for each free table T:
        configs.add(SingleTable(T))
    for each TableAdjacency pair (T1, T2) where T1 is free and T2 is free:
        configs.add(CombinedPair(T1, T2))
    return configs
```

Only the 40 seeded tables and the 19 seeded adjacency pairs are ever considered (10 × 2+2, 9 × 4+4, 2 standalone 6-seat). No 3+-table combination is ever generated (DEC-002). This is unchanged from `allocation-spec.md` §1's `compatible_configurations` — restated here as configuration generation independent of any one group, since §14 below needs the full available-configuration set up front, not one group's view of it.

## 5. Compatibility calculation

Boolean only (§3 above): `configuration.capacity >= entry.group_size`. There is no partial/fractional compatibility — a configuration either can seat the group or cannot.

## 6. Fit calculation

```
fit_score(entry, configuration) = entry.group_size / configuration.capacity
```

Range: `(0, 1]`. `1.0` = exact fit (no wasted capacity). Lower values mean more wasted capacity.

Examples: group 4 on a 4-seat table → `4/4 = 1.0`. Group 4 on a combined `4+4=8` → `4/8 = 0.5`. Group 2 on a 2-seat table → `1.0`. Group 2 on a 6-seat table → `2/6 ≈ 0.333`.

**Why a ratio, not a difference:** a raw "seats wasted" count (`capacity - group_size`) is not comparable across configurations of different absolute size in a normalized scoring formula (wasting 2 seats out of 4 is a much worse decision than wasting 2 seats out of 8) — the ratio directly expresses *utilization*, which is the actual business goal (conserve scarce capacity, `seating-allocation-policy.md` Stage 3), and is naturally bounded to `(0, 1]` with no extra normalization step needed.

This single formula answers §9 ("how are 1-table and 2-table configurations compared") without a hardcoded rule: a combined configuration's capacity is simply the sum of its two tables, so it is only preferred over a compatible single-table alternative when it is the tighter fit — never by a blanket "single always wins" or "combined always available" rule (§15).

## 7. Scarcity calculation

```
scarcity_score(entry, available_configurations) =
    1 / count( c in available_configurations where compatible(entry, c) )
```

Range: `(0, 1]`. Computed **fresh, from the current available-configuration landscape**, at the moment of each allocation pass — never from static/seed-time table-type counts (§7 of the governing prompt explicitly requires this to reflect the *currently* available landscape, not a fixed assumption that "6-seat tables are always scarce").

**Why this formula:** it directly answers "how many currently-available options does this specific waiting group have right now?" A group with only one currently-compatible configuration (e.g., a 6-person group when only one 6-seat table is free and no 4+4 pair is free) gets `scarcity_score = 1.0` — maximal urgency, since losing this configuration to another group means this group has nothing else to wait on right now. A group with many currently-compatible configurations (e.g., a 2-person group when 2-, 4-, and 6-seat tables are all free) gets a low score, correctly signaling that giving it any *one* of those configurations costs less in opportunity terms — some other option remains for it. Division by zero cannot occur: this score is only ever computed for a pair already known to be compatible with at least the configuration under evaluation, so the count is always ≥ 1.

This is the concrete, deterministic answer to §11's opportunity-cost concern ("consuming a 6-seat table for a 2-person group may create a significant future opportunity cost") without any predictive modeling — it reads only the current landscape (§7's explicit MVP constraint).

## 8. Waiting-time aging

```
waiting_seconds(entry) = now - entry.joined_at

aging_score(entry) = min(waiting_seconds(entry) / MAX_AGING_WINDOW_SECONDS, 1.0)
```

- **Starting value:** `0.0`, at the instant of joining (`waiting_seconds = 0`).
- **Growth:** linear in elapsed wait time.
- **Maximum contribution:** `1.0` — hard-capped, reached once `waiting_seconds >= MAX_AGING_WINDOW_SECONDS`. It never exceeds `1.0` no matter how long the group has waited (§10, see §10 below for why this is sufficient as the maximum-weight safeguard).
- **Units:** dimensionless, normalized `[0, 1]`, directly comparable to `fit_score` and `scarcity_score`.
- **Tunable configuration:** `MAX_AGING_WINDOW_SECONDS` (§19). **Default: equal to `STARVATION_THRESHOLD_SECONDS`** (1200s / 20 minutes) — chosen deliberately so ordinary aging saturates to its maximum at *exactly* the moment starvation protection (a separate, categorical mechanism, §9) takes over. Past that point, priority is governed by the starvation override, not by an ever-larger aging number — there is no reason for aging to keep growing once a stronger, purpose-built mechanism has already engaged.

This directly implements `seating-allocation-policy.md` Stage 4 ("longer wait time increases priority among competing groups") as a bounded, normalized contribution rather than an unbounded raw-seconds value.

## 9. Starvation protection

**Not a stored field** (`domain-model-proposal.md` §7–8, `data-model.md`'s explicit "not stored: any position, rank, weight, or starvation-protection flag"). See §23 below for why `allocation-spec.md` §4's stored `starvation_protected_since` pseudocode is corrected by this document.

```
function is_starvation_protected(entry, now):
    return (now - entry.joined_at) >= STARVATION_THRESHOLD_SECONDS
```

Derived at evaluation time, exactly like the DEC-015 lazy-expiration check already implemented for `ready` entries (`Guest::CurrentQueueStatusService`, Phase 5B.4) — no scheduler, no cron, no background job, computed only when an allocation pass (or, later, a staff/guest read) actually needs it.

**Behavior (INV-013, unchanged from `seating-allocation-policy.md` Stage 5):** protection applies only to a group's **complete** required configuration, never a lone member table of a combined requirement. Because every candidate pair in this algorithm is already gated by hard compatibility (§3) — which by construction only ever includes configurations that *fully* seat the group — a "protected candidate" is exactly "a candidate whose entry is starvation-protected," with no separate half-configuration case to special-case. If a 6-person group is protected but only one of its two required adjacent tables is currently free, no `CombinedPair` configuration exists for it yet (§4), so it simply has no candidate this pass — not a bug, the direct consequence of §3's hard gate.

**Effect on selection:** categorical, not additive. If **any** eligible candidate for the pool being considered this pass is starvation-protected, **only** starvation-protected candidates are considered further — non-protected candidates are excluded outright, regardless of their `total_score` (§11). This guarantees the `starvation-policy.md` "precise guarantee" (priority once the complete configuration is available) cannot be defeated by a merely-high `total_score`.

**Ordering among multiple simultaneously-protected candidates:** `starvation-policy.md`/`seating-allocation-policy.md` guarantee priority *over non-protected competing traffic* — they do not specify how to order two or more protected groups against each other. This document resolves that (undecided) gap deterministically: protected candidates are ranked by the same `total_score` + tie-break chain as everyone else (§11, §14). Since every starvation-protected entry already has `aging_score = 1.0` (capped, §8), aging can no longer differentiate among them — so in practice `fit_score` and `scarcity_score` decide, falling back to `joined_at` (oldest first) only on a further tie. This is a deliberate, documented refinement over `allocation-spec.md` §3's `oldest_by_wait_time(protected)` shortcut — still fully satisfies INV-013 (a protected candidate always beats a non-protected one), just resolves protected-vs-protected ordering more richly than "oldest always wins," which nothing in the approved policy actually requires.

## 10. Maximum-weight safeguard

The concern (§10 of the governing prompt): waiting time must not grow without bound and eventually dominate every other factor.

**Resolution: cap the aging *contribution*, not the overall score.** `fit_score` and `scarcity_score` are already naturally bounded to `(0, 1]` by their own definitions (ratios) — they carry no time-dependence and cannot grow unboundedly. `aging_score` is the only time-dependent, monotonically-growing term, so it is the only one that needs an explicit ceiling; capping it (§8: hard-capped at `1.0`) is therefore sufficient to bound the *entire* `total_score` (§11) — `total_score`'s maximum possible value is fixed at `WEIGHT_FIT + WEIGHT_SCARCITY + WEIGHT_AGING = 1.0` by construction, for any entry, no matter how long it has waited. Capping "maximum overall priority contribution" separately would be redundant given the weights already sum to a fixed total.

Beyond `MAX_AGING_WINDOW_SECONDS`, further elapsed time changes nothing about `total_score` — the group's priority is then governed entirely by starvation protection (§9), a categorical override, not a larger number. This is the deliberate design: unbounded waiting time is handled by a *qualitatively different* mechanism (guaranteed priority over non-protected competitors) rather than by letting a numeric score grow forever, which is both safer (no numeric overflow/precision concern) and matches the product decision that starvation protection is a distinct guarantee, not "more of the same aging" (`starvation-policy.md`).

## 11. Candidate scoring (composite formula)

For every compatible `(entry, configuration)` pair that is not excluded by the starvation gate (§9):

```
total_score(entry, configuration, available_configurations, now) =
      WEIGHT_FIT      * fit_score(entry, configuration)
    + WEIGHT_SCARCITY  * scarcity_score(entry, available_configurations)
    + WEIGHT_AGING     * aging_score(entry, now)
```

**Default weights (tunable MVP parameters, §19 — not a claimed product truth):**

| Weight | Default | Rationale |
|---|---|---|
| `WEIGHT_FIT` | `0.4` | Capacity conservation is `seating-allocation-policy.md` Stage 3's explicitly named goal ("prefer the smallest suitable configuration... to conserve larger capacity for groups that need it") — weighted highest since it's the only factor that differentiates a single group's own multiple options (see §14). |
| `WEIGHT_SCARCITY` | `0.3` | Protects groups with few alternatives from having a rare-for-them configuration taken by a group with many alternatives (§7). |
| `WEIGHT_AGING` | `0.3` | Rewards elapsed wait among otherwise-similar candidates (Stage 4), bounded (§8/§10) so it can never dominate. |

Weights sum to `1.0` so `total_score ∈ (0, 1]` always. `WEIGHT_SCARCITY = WEIGHT_AGING` deliberately — both represent a form of "protect the group with fewer other paths to being seated" (alternative-count vs. elapsed-time), and nothing in the approved requirements argues one should outweigh the other; `WEIGHT_FIT` is weighted higher because fit is the *only* term of the three that differentiates between a single group's own compatible options (see §14) — without it dominant enough, the algorithm could not reliably reproduce Stage 3's smallest-fit preference.

**Why this doesn't invert the original 6-stage model:** `seating-allocation-policy.md` Stage 3 (smallest-fit) governs a *single* group choosing among *its own* multiple compatible options; Stage 4 (aging) governs *multiple groups* competing for the *same* option. In this composite formula, `scarcity_score` and `aging_score` are computed per-entry and are (for a fixed entry, in one pass) nearly constant across that entry's own different candidate configurations — so `fit_score` remains the dominant differentiator *within* one entry's own options (preserving Stage 3's role), while `aging_score` (plus `scarcity_score`) is what differentiates *between* competing entries for the same configuration (preserving Stage 4's role). The unified formula subsumes both original stages rather than contradicting either.

## 12. Global winner selection (not first-match)

```
function run_allocation_pass():
    loop:
        available = generate_available_configurations()          # §4
        waiting   = all QueueEntry where status = 'waiting'
        if available is empty or waiting is empty:
            return   # nothing more can happen this pass

        candidates = []
        for entry in waiting:
            for configuration in available:
                if compatible(entry, configuration):             # §3, hard gate
                    candidates.append((entry, configuration))

        if candidates is empty:
            return   # no compatible pairing exists right now (§13)

        protected_candidates = [c in candidates where is_starvation_protected(c.entry, now)]
        pool = protected_candidates if protected_candidates is not empty else candidates

        winner = deterministic_max(pool, key = ranking_key)       # §14 tie-break chain

        result = allocate(winner.entry, winner.configuration)     # allocation-spec.md §5, unchanged
        if result == FAILURE:
            continue   # lost a race; recompute the grid fresh and try again
        # else: committed — loop again, since state changed and another
        # pairing may now be possible (a different group for the same
        # newly-partially-freed adjacency slot, etc.)
```

This directly answers §14 of the governing prompt ("do not implement find-first-group / find-first-table — consider all currently eligible candidates together, score them, choose the deterministic highest-priority candidate"). It is **not** naive greedy per-table iteration (same non-goal `allocation-spec.md` and `seating-allocation-policy.md` already state) — the full cross-product of waiting entries × available configurations is generated and globally compared before any single allocation commits.

**Termination:** each successful `allocate` strictly reduces either the waiting set or the available-configuration set (usually both), so the loop terminates in at most `min(|available configurations|, |waiting entries|)` successful iterations, plus a bounded number of `FAILURE` retries under real concurrency (each `FAILURE` is itself evidence another transaction just consumed a table, further shrinking `available` on the next loop). No infinite loop is possible.

**Complexity (§20/§28 — do not over-optimize):** each grid regeneration is `O(|waiting| × |available|)` ≈ hundreds × ~60 (40 tables + 19 adjacency pairs, worst case both fully free) — a few thousand comparisons — repeated at most `min(|available|, |waiting|)` times per trigger event (≤ ~60). Total work per trigger is on the order of `10^4`–`10^5` simple comparisons — trivial at this scale, entirely within plain Ruby/ActiveRecord, no index/optimizer/ML component needed or justified.

## 13. No configuration available

If `available` (or `waiting`) is empty, or no compatible pair exists in the current grid, `run_allocation_pass` returns without touching the database. Every currently-`waiting` entry simply remains `waiting` — this is not an error or a special case, it is the ordinary steady state whenever supply and demand don't currently intersect (§13 of the governing prompt, worked as Example 12 below).

## 14. Tie-breaking (deterministic, no randomness)

`ranking_key`, applied within whichever pool (§12) is being compared, highest wins at each level before falling to the next:

1. **`total_score` (§11)** — highest wins. (Starvation protection has already partitioned the pool in §9/§12 — this is not re-applied here as a separate tier, since by this point every candidate in `pool` is either all-protected or all-non-protected.)
2. **Fewer tables consumed** — a `SingleTable` candidate beats a `CombinedPair` candidate on an exact `total_score` tie (only reachable when `fit_score` also ties, e.g. group of 4 vs. a free 4-seat single table and a free `2+2` pair simultaneously) — consuming one table for the same outcome as two is strictly better resource use (§15 of the governing prompt), and this is the one signal `total_score` cannot already express (`fit_score` alone can tie between a single and a combined option; table *count* is a distinct, additional signal only worth consulting on that residual tie).
3. **Earlier `joined_at`** — oldest first (Stage 4's literal fallback once the composite score doesn't distinguish).
4. **Lower `QueueEntry.id`** — final, always-distinguishing tie-break (two entries cannot share a `joined_at` down to database precision *and* still tie on every prior level in any realistic scenario, but `id` guarantees a strict total order regardless).

**Why not the six-level hierarchy suggested in the governing prompt's own §21 example, verbatim:** that suggestion listed "better compatibility / lower waste" and "lower resource consumption" as separate tiers from "overall priority score." Here, `fit_score` is already a first-class term *inside* `total_score` (§11) — re-checking "compatibility/waste" again as an independent tie-break tier would double-count the same signal. Only "lower resource consumption" (single vs. combined table count) captures something `total_score` cannot already express (an exact `fit_score` tie between differently-shaped configurations), so only that one is kept as its own tier (level 2 above); the rest collapses into `total_score` itself.

**Determinism guarantee:** for a fixed database state and a fixed `now`, `run_allocation_pass` always produces the same sequence of allocations — every input to every formula above (`group_size`, table `capacity`, `joined_at`, `id`, current free/occupied state) is either static seed data or already-persisted state, and `now` is passed in once per pass, not re-read per candidate.

## 15. Missed compatible opportunities

Definition (inherited from `07-future-evolution/missed-opportunities.md`, restated here for the algorithm's own precision): within one `run_allocation_pass` iteration, if `winner = (G, C)` is selected, every **other** `(entry, configuration)` pair in `candidates` where `configuration == C` — i.e., every other waiting group that was also compatible with the *specific* configuration `C` that was just consumed — experienced a missed compatible opportunity for `C` in that instant. A group is **not** counted as having missed an opportunity for a configuration it was never compatible with (e.g., a 6-person group never "misses" a 2-seat table), and a group is **not** counted as missing anything when only half of its *own* required combined configuration was ever free (INV-013 — no complete configuration existed for it, so there was no opportunity to miss in the first place).

**MVP status: descriptive only.** This algorithm does not compute, log, or persist missed-opportunity events (`DEC-008`) — the definition above exists so the concept is precise and testable if `fairness-debt.md`/`missed-opportunities.md` are ever built later, not because anything in Phase 5B.5.2 needs to act on it.

## 16. MVP now vs. future fairness

**Implemented by this specification, to be built in Phase 5B.5.2:**
- Hard compatibility gating (§3).
- Fit calculation (§6).
- Scarcity calculation, from the current landscape only (§7).
- Bounded waiting-time aging (§8).
- Starvation protection, derived at read time, categorical override (§9).
- The maximum-weight safeguard via aging's hard cap (§10).
- Composite `total_score` and global candidate scoring (§11, §12).
- Deterministic tie-breaking (§14).
- Atomic, concurrency-safe allocation transactions (§17, §18, unchanged from `allocation-spec.md` §5).

**Explicitly future (not built now, `07-future-evolution/`):**
- Cumulative missed-compatible-opportunity tracking and fairness debt (`missed-opportunities.md`, `fairness-debt.md`, DEC-008).
- Historical fairness across long time periods.
- Predictive/forecasted demand.
- Table-sharing (`shared-tables.md`).
- Learned/adaptive compatibility or weighting (any ML-adjusted `WEIGHT_*` value).
- Multi-objective optimization solvers.
- AI-assisted policy tuning as a live, automatic mechanism (see §17 — AI may assist *offline*, never adjust weights at runtime on its own).

## 17. AI's role

**AI may (offline, human-supervised, never in the request path):**
- Analyze historical allocation outcomes for patterns.
- Suggest `WEIGHT_FIT`/`WEIGHT_SCARCITY`/`WEIGHT_AGING`/threshold adjustments for a human to review and apply as ordinary configuration changes.
- Identify repeated starvation patterns worth a policy review.
- Detect unusual allocation patterns (e.g., a persistent imbalance) for human investigation.
- Simulate alternative policies/weights offline against recorded or synthetic data.
- Help tune parameters — as a suggestion, not an autonomous change.

**AI must NOT, at runtime:**
- Decide "give Table 12 to Group 7" directly, or any equivalent unconstrained judgment call.
- Substitute for `run_allocation_pass` (§12) or any formula in this document.
- Dynamically alter weights or thresholds mid-operation without a human-reviewed configuration change.

Every runtime decision traces back to the explicit, deterministic formulas in §6–§14 — the algorithm is auditable and reproducible from logged inputs (`group_size`, table state, `joined_at`, `now`) alone, with no opaque model in the decision path.

## 18. Concurrency requirements

Unchanged from `allocation-spec.md` §5/§17 of the governing prompt, restated here for completeness since §12's global pass wraps multiple individual `allocate` attempts:

- Each `allocate(entry, configuration)` call is its own transaction (`allocation-spec.md` §5, unmodified): lock the 1–2 target `Table` rows via `SELECT ... FOR UPDATE`, in a **deterministic order (ascending `table_id`)** to avoid deadlocks when two concurrent passes target overlapping table sets, re-check `is_free` under the lock, then create the `SeatingAssignment` + `SeatingAssignmentTable` row(s) and transition the entry to `ready`, or roll back entirely on any conflict (INV-005 — both tables or neither, never partial).
- The database's own `UNIQUE(table_id) WHERE released_at IS NULL` partial index (INV-016) remains defense-in-depth beneath the application-level lock, exactly as `allocation-spec.md` §8's combined-pair race example already describes — if the lock discipline is ever imperfect, the constraint is still what actually prevents a double-claim from committing.
- `run_allocation_pass` (§12) treats any single `allocate` `FAILURE` as "recompute the grid and continue" — never as reason to abort the whole pass, since a failure only ever means the *specific* candidate lost a race, not that the algorithm state is corrupt.
- **Isolation level:** `READ COMMITTED` (matches `domain-model-proposal.md` §11's already-established choice) — sufficient given the explicit row locks above; `SERIALIZABLE` or optimistic/version-column concurrency control is not required anywhere in this model.

## 19. Configuration values

All values below are tunable and must live in one centralized location — following the project's existing idiom (`SeatingAssignment::READY_TIMEOUT`, `backend/app/models/seating_assignment.rb`, `ENV.fetch(...).to_i.seconds`), not scattered as magic numbers through the allocation service. This document specifies the **contract**; Phase 5B.5.2 implements it (e.g., as an `AllocationPolicy` module of `ENV`-backed constants, mirroring the existing pattern).

| Name | Default | Status | Notes |
|---|---|---|---|
| `STARVATION_THRESHOLD_SECONDS` | `1200` (20 min) | Already approved (DEC-004, illustrative) | Read by `is_starvation_protected` (§9). |
| `MAX_AGING_WINDOW_SECONDS` | `1200` (20 min) | **Tunable MVP parameter**, new in this document | Defaults equal to `STARVATION_THRESHOLD_SECONDS` — see §8 for why. Could be decoupled later if evidence suggests aging should saturate earlier or later than starvation engages. |
| `WEIGHT_FIT` | `0.4` | **Tunable MVP parameter**, new in this document | §11. |
| `WEIGHT_SCARCITY` | `0.3` | **Tunable MVP parameter**, new in this document | §11. |
| `WEIGHT_AGING` | `0.3` | **Tunable MVP parameter**, new in this document | §11. Must always satisfy `WEIGHT_FIT + WEIGHT_SCARCITY + WEIGHT_AGING = 1.0`. |
| `READY_TIMEOUT_SECONDS` | `300` (5 min) | Already implemented (`SeatingAssignment::READY_TIMEOUT`, Phase 5B.2) | Not owned by this document — referenced only because §5a's `confirm_seating`/`expire_ready` interact with the entries this algorithm produces. |

## 20. Complexity

See §12 above (bounded, `O(|waiting| × |available|)` per grid regeneration, at most `min(|available|, |waiting|)` regenerations per trigger). No data structure beyond plain Ruby arrays/ActiveRecord queries is required at this scale (§28 — no ML, no vector database, no solver, no distributed system).

## 21. Worked examples

Fixed context for all examples unless stated otherwise: `WEIGHT_FIT=0.4, WEIGHT_SCARCITY=0.3, WEIGHT_AGING=0.3, MAX_AGING_WINDOW_SECONDS=1200, STARVATION_THRESHOLD_SECONDS=1200`.

**Example 1 — 2-person group, free 2-seat table.**
Waiting: G1(size 2, waiting 1 min). Available: T1(2-seat, free). Only candidate: (G1, T1). `fit=2/2=1.0`, `scarcity=1/1=1.0` (only 1 compatible config exists), `aging=60/1200≈0.05`. `total_score≈0.4·1+0.3·1+0.3·0.05=0.715`. Winner: G1 at T1 (only candidate — trivial win). No alternatives to lose.

**Example 2 — 2-person group, only a 4-seat table free.**
Waiting: G1(size 2). Available: T2(4-seat, free) only. Candidate: (G1, T2), `fit=2/4=0.5`. Only candidate again — wins by default. Demonstrates Stage 3's underlying reason for existing (a smaller table would score higher on `fit` *if* available) without blocking the group when it isn't.

**Example 3 — 2-person + 4-person groups, one free 4-seat table.**
Waiting: G1(size 2, waiting 1 min), G2(size 4, waiting 1 min). Available: T2(4-seat) only. Both compatible (`4 >= 2` and `4 >= 4`). `fit(G1,T2)=0.5`, `fit(G2,T2)=1.0`. `scarcity`: each has 1 compatible config → `1.0` each. `aging`: ≈equal (both waited ~1 min) → ≈equal. `total_score(G2,T2) = 0.4·1.0+0.3·1.0+0.3·~0.05 ≈ 0.715` beats `total_score(G1,T2) = 0.4·0.5+0.3·1.0+0.3·~0.05 ≈ 0.515`. **Winner: G2** — the exact fit wins; G1 remains waiting for a 2-seat table (a better outcome for it anyway).

**Example 4 — 2-person + 6-person groups, one free 6-seat table.**
Waiting: G1(size 2), G2(size 6), both waiting ~1 min, no adjacent pair free. `fit(G1,T)=2/6≈0.333`, `fit(G2,T)=6/6=1.0`. `scarcity(G1)`: if G1 also has other free compatible tables (say a 2-seat and a 4-seat are also free), its count is higher (e.g., 3) → `scarcity(G1)=1/3≈0.333`; `scarcity(G2)`: the 6-seat table is G2's *only* option → `scarcity(G2)=1/1=1.0` (assuming no 4+4 pair is free). G2 dominates on both `fit` and `scarcity`. **Winner: G2.**

**Example 5 — 4-person + 6-person groups, one free 6-seat table.**
`fit(G1=4,T)=4/6≈0.667`, `fit(G2=6,T)=1.0`. If both have other options, `scarcity` may be closer, but `fit` alone already favors G2 unless G1 is waiting dramatically longer or is starvation-protected. **Winner: G2**, assuming comparable wait times — this is the intended outcome (Stage 3, better fit) and is not a hardcoded "always prefer larger group" rule (§6 of the governing prompt): if G1 were instead starvation-protected (waited ≥20 min) and G2 were not, G1 would win categorically (§9) regardless of `fit`.

**Example 6 — 6-person group, two adjacent free 4-seat tables.**
Waiting: G1(size 6). Available: `CombinedPair(T1,T2)` where `T1.capacity=T2.capacity=4`, combined `8`. `fit(G1, pair)=6/8=0.75`. If no single 6-seat table is free, this is G1's only candidate. **Winner: G1 at the combined pair** — the only compatible configuration; `allocate` reserves both tables atomically (§18) or fails and rolls back entirely if either is lost to a race.

**Example 7 — 6-person group, one free 6-seat table AND one free 4+4 combination simultaneously.**
Candidates: (G1, SingleTable(6-seat)) with `fit=1.0`; (G1, CombinedPair(4,4)) with `fit=0.75`. Same `scarcity`/`aging` (same entry, same pass). `total_score` for the single table is strictly higher (`0.4·1.0 > 0.4·0.75`, all else equal). **Winner: the single 6-seat table** — not because of a hardcoded "prefer single" rule, but because it is the better fit (§15); the `4+4` pair remains free for a group that might need exactly `7` or `8`.

**Example 8 — small groups repeatedly arriving while a large group waits (demonstrating starvation protection, pre-threshold).**
G_large(size 6, waiting 5 min, under threshold). A steady stream of `G_small(size 2)` groups arrive and are seated on single 2-seat tables as they free — none of them are compatible with a lone freed 2-seat table that G_large also needs (G_large needs a full 6-seat or 4+4 configuration, never a lone 2-seat table), so **no missed opportunity occurs here** (§15) — G_large simply has no candidate configuration yet. This is the ordinary, correct pre-threshold state, not a bug: `seating-allocation-policy.md` Stage 5 only ever engages once G_large's *complete* configuration is available.

**Example 9 — small group has better fit, large group has crossed the starvation threshold (demonstrating the safeguard).**
Waiting: G_small(size 2, waiting 3 min), G_large(size 6, waiting 21 min — past `STARVATION_THRESHOLD_SECONDS`). Available: one free 6-seat table (compatible with both — `6>=2` and `6>=6`). Without starvation protection, `fit(G_small,T)=2/6≈0.333` vs `fit(G_large,T)=1.0` — G_large would already win on fit alone here, so to make the safeguard's *effect* visible, suppose instead T is a `CombinedPair(3-seat-equivalent... )` — more precisely: suppose the only free configuration is a 4+4 pair (`capacity=8`) compatible with both. `fit(G_small,pair)=2/8=0.25`, `fit(G_large,pair)=6/8=0.75` — G_large already wins on fit too in this shape. To construct a genuine case where fit alone would favor the small group: suppose two configurations are free simultaneously — a 2-seat table (only G_small fits: `2>=2`, `2<6` so G_large is incompatible) and the 4+4 pair (both fit). G_small's `fit` on the 2-seat table is `1.0`, clearly the "better fit" outcome for G_small individually — but G_small and G_large are never actually competing for the *same* configuration in this shape, so fit-comparison across different configurations doesn't apply directly. The safeguard's real effect: **G_large, being starvation-protected, is placed in `protected_candidates` and wins the 4+4 pair outright** the moment both member tables are simultaneously free, even if some other non-protected group with a numerically higher `total_score` was also compatible with that same pair — protection is categorical (§9), not merely a score boost, precisely so a merely-better-fitting non-protected competitor can never out-rank it.

**Example 10 — two groups equally eligible (deterministic tie-breaking).**
G1(size 4, joined at `T`) and G2(size 4, joined at `T + 1s`), both compatible with the same single free 4-seat table, otherwise-identical `scarcity`. `fit` ties (`1.0` each). `aging` differs negligibly (1 second apart) but not exactly — so in practice `total_score` already differs fractionally in G1's favor (it has waited 1 second longer). If `joined_at` were ever recorded identically (clock-precision collision), tie-break level 4 (`id`) decides — whichever entry was inserted first (lower `id`) wins. **Result is always the same for the same DB state** — no randomness.

**Example 11 — a candidate would consume a scarce table needed by another compatible group (demonstrating scarcity).**
Free: one 6-seat table only. Waiting: G_A(size 2, many other compatible free tables also exist — say 3 total including this one) and G_B(size 6, this 6-seat table is its *only* compatible option). `scarcity(G_A)=1/3≈0.333`; `scarcity(G_B)=1/1=1.0`. Even if `fit(G_A,T)=0.333` and `fit(G_B,T)=1.0` already favor G_B on fit alone, `scarcity` reinforces the same conclusion rather than fighting it — this is the intended, non-degenerate case. **Winner: G_B**; G_A's other 2 compatible tables remain fully available to it.

**Example 12 — no currently available configuration is compatible.**
Waiting: G1(size 6). Available: two free 2-seat tables, not adjacent to each other, no 4+4 pair free, no 6-seat table free. `generate_available_configurations` produces only `SingleTable`s with `capacity=2` and 2-seat/2-seat non-adjacent pairs excluded (not a valid `TableAdjacency`) — none satisfy `2 >= 6` or any valid combined pair `>= 6`. `candidates` is empty for G1. **No allocation. G1 remains `waiting`.** This is the correct, ordinary outcome (§13) — not an error, and not a trigger to invent a seating arrangement that doesn't exist.

## 22. Pseudocode

```
function run_allocation_pass():
    loop:
        available = generate_available_configurations()
        waiting   = QueueEntry.where(status: "waiting")

        if available.empty? or waiting.empty?:
            return

        candidates = []
        for entry in waiting:
            for configuration in available:
                if compatible(entry, configuration):
                    candidates << Candidate(entry, configuration)

        if candidates.empty?:
            return

        protected_candidates = candidates.select { |c| is_starvation_protected(c.entry, now) }
        pool = protected_candidates.empty? ? candidates : protected_candidates

        winner = pool.max_by { |c| ranking_key(c) }   # see below — lexicographic, deterministic

        result = allocate(winner.entry, winner.configuration)   # allocation-spec.md §5, unchanged
        continue unless result == SUCCESS
        # SUCCESS: loop again — state changed, re-derive available/waiting fresh
        # FAILURE: also loop again — lost a race, re-derive fresh and retry

function compatible(entry, configuration):
    configuration.capacity >= entry.group_size

function ranking_key(candidate):
    [
        total_score(candidate.entry, candidate.configuration, available, now),  # higher wins
        candidate.configuration.table_count == 1 ? 1 : 0,                       # single beats combined on tie
        -candidate.entry.joined_at.to_i,                                        # earlier joined_at wins on tie
        -candidate.entry.id                                                     # lower id wins on tie
    ]
    # compared lexicographically; ties at one level fall through to the next

function total_score(entry, configuration, available, now):
    WEIGHT_FIT * fit_score(entry, configuration) +
    WEIGHT_SCARCITY * scarcity_score(entry, available) +
    WEIGHT_AGING * aging_score(entry, now)

function fit_score(entry, configuration):
    entry.group_size.to_f / configuration.capacity

function scarcity_score(entry, available):
    1.0 / available.count { |c| compatible(entry, c) }

function aging_score(entry, now):
    [(now - entry.joined_at) / MAX_AGING_WINDOW_SECONDS, 1.0].min

function is_starvation_protected(entry, now):
    (now - entry.joined_at) >= STARVATION_THRESHOLD_SECONDS
```

This is illustrative-precision pseudocode, not idiomatic Ruby — Phase 5B.5.2 writes the actual `ActiveRecord`/transaction-idiomatic implementation (same status disclaimer as `allocation-spec.md`'s existing pseudocode, per DEC-012).

## 23. Reconciliation with `allocation-spec.md` (genuine corrections found — see also `ai-corrections.md` CORR-006)

While producing this document, the following contradiction was found and corrected, per this phase's own §23 instruction to compare against every authoritative document and record genuine corrections rather than silently overwrite history:

- **`allocation-spec.md` §4** (`update_starvation_protection()`) pseudocode wrote `G.starvation_protected_since = now` — a stored, per-row field, updated "on a schedule." This directly contradicts `domain-model-proposal.md` §7–8 (finalized, Phase 5B.1) and `data-model.md`'s explicit "not stored: any position, rank, weight, or starvation-protection flag" — both of which pre-date `allocation-spec.md`'s unrevised §4 and were evidently never reconciled against it during the Phase 5B.1.5 consistency pass (whose named audit scope did not include this specific pseudocode). **`allocation-spec.md` §4 is corrected** (see the diff applied alongside this document) to derive starvation protection at evaluation time from `joined_at`, exactly matching this document's §9 `is_starvation_protected` function — no stored field, no schedule, no background job, consistent with DEC-015's established "never a background scheduler" precedent for the structurally identical READY-expiration check.
- No other contradiction was found between this document and `seating-allocation-policy.md`, `starvation-policy.md`, `functional-spec.md`, `api-spec.md`, `domain-model.md`, or `data-model.md` — the six-stage model, the DEC-004/DEC-015 thresholds, INV-013, and the READY/allocation split are all preserved and made more precise, not altered, by §3–§18 above.

## 24. Known limitations

- The composite `total_score` blends three normalized signals with fixed default weights; the weights are explicitly labeled tunable MVP parameters (§11, §19), not derived from any formal optimization — a real restaurant would need to observe outcomes and adjust them (§17, offline AI-assisted tuning is one legitimate future path for that, never a runtime one).
- `scarcity_score` reflects only the *current* landscape, not near-future arrivals/releases — it can be "wrong" in hindsight (e.g., another compatible table frees a second later), which is an accepted, documented limitation consistent with `seating-allocation-policy.md`'s explicit rejection of predictive/global-optimal scheduling.
- The starvation-protected-candidates ordering (§9) is this document's own reasonable completion of a genuine gap in the approved policy (which specifies protection *against non-protected competitors*, not protected-vs-protected ordering) — not itself an approved product decision; flagged here so a human reviewer can confirm or override it before Phase 5B.5.2 implements it.
- `run_allocation_pass`'s repeat-until-exhausted loop (§12) is synchronous and re-derives the full grid from scratch on every iteration for simplicity and correctness under concurrency (§20) — acceptable at the stated MVP scale (~40 tables, hundreds of waiting groups), not necessarily at a much larger scale, which is out of scope for this assignment.

## 25. Future evolution

See §16's "Explicitly future" list and the existing `07-future-evolution/missed-opportunities.md` and `fairness-debt.md` — nothing in this document expands or contracts that already-approved boundary (DEC-008).
