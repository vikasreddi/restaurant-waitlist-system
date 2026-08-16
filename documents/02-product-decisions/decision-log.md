# Decision Log

Decisions the candidate has approved. Agents must not silently alter, reinterpret, or expand any decision recorded here (see `documents/06-ai-working-record/ai-development-approach.md` §AI Governance). Decisions are numbered `DEC-NNN` and referenced by ID from other documents.

Each entry: context, options considered, chosen approach, rationale, trade-offs, implementation scope, future evolution.

---

## DEC-001 — Table seed data

**Context.** Table layout is fixed seed data per the brief; the brief describes "around 40 tables," mostly seating 2 or 4, with one or two large tables, but does not give exact numbers.

**Options considered.**
- Invent an arbitrary distribution.
- Use a distribution that stresses the interesting cases (scarce large-table capacity, common small-table churn).

**Chosen approach.** 40 tables total: 20 two-seat, 18 four-seat, 2 six-seat. Represented by table ID, capacity, adjacency, and occupancy state. Tables are **not** permanently bound to a group-size category — a smaller group may use a larger table when necessary.

**Rationale.** Matches the brief's description ("around 40 tables," "most seat 2 or 4," "only one or two large tables") while being concrete enough to seed and test against. Keeping tables unbound from group-size categories avoids an artificial second allocation rule and matches "seating is not first-come-first-served" — availability, not a rigid size bucket, drives eligibility.

**Trade-offs.** This is an assumption for the take-home, not a requirement extracted from the brief — a different distribution would also be defensible. Two 6-seat tables makes large-group starvation scenarios easy to construct and test, which is useful for demonstrating the starvation policy but is a deliberately adversarial choice, not necessarily realistic.

**Implementation scope.** Seed script/migration data only; no admin UI (explicitly out of scope per the brief).

**Future evolution.** A real deployment would source this from restaurant-specific configuration, not hardcoded seed data.

---

## DEC-002 — Maximum table combination

**Context.** The brief states large groups "almost always" need two adjacent tables, but leaves open whether 3+ tables could ever be combined.

**Options considered.**
- Support N-table combinations generally.
- Cap combinations at exactly two tables.

**Chosen approach.** A group may combine at most two adjacent tables. Combined allocation is atomic: both tables allocated or neither; no partial allocation.

**Rationale.** Matches the brief's own framing and running example throughout ("two adjacent ones pushed together"). Two-table combination is sufficient to cover the group sizes implied by the seed data (2, 4, 6, 8-seat via 4+4, etc.) without adding N-way combinatorial allocation complexity that the brief never asks for.

**Trade-offs.** A hypothetical group larger than any two-table combination's capacity (e.g., 10 people, no adjacent pair summing to ≥10) is not seatable under this rule. See open question in `scope-and-tradeoffs.md`.

**Implementation scope.** Allocation logic considers single tables and adjacent pairs only; never triples.

**Future evolution.** N-table combination chains are a plausible real-world extension, explicitly not built now.

---

## DEC-003 — Seating allocation algorithm

**Context.** The brief requires non-FIFO seating where eligibility depends on table availability and configuration, with no group waiting forever.

**Options considered.** (Full comparison in `seating-allocation-policy.md`.)
- Strict FIFO — rejected, contradicts the brief directly.
- Naive greedy per-table iteration ("for each table, seat the first group that fits") — rejected; considers one table at a time in isolation rather than reasoning over all currently compatible configurations and waiting groups together, which cannot correctly express smallest-fit preference or starvation protection.
- Pure smallest-fit, no aging — rejected, does not bound worst-case wait for large groups (starvation risk).
- Compatibility-aware aging with maximum-wait protection — chosen.
- Fairness-debt / missed-opportunity based global optimization — rejected for the two-day core; deferred to Future.

**Chosen approach.** **Compatibility-Aware Aging with Maximum-Wait Protection**, in six stages: (1) determine compatible seating configurations for a group by capacity/adjacency, (2) restrict competition to configurations that can actually seat the group, (3) prefer the smallest suitable available configuration, (4) use wait-time as an aging/fairness signal among groups competing for the same compatible configuration, (5) apply a configurable maximum-wait threshold after which a group becomes starvation-protected for its *complete* required configuration (not an individual table), (6) allocate atomically. Full detail in `seating-allocation-policy.md` and `starvation-policy.md`.

**Rationale.** Deterministic and simple enough to implement correctly in two days, while directly satisfying both "not FIFO" and the starvation-protection requirement (see DEC-004 for the precise, corrected wording of that guarantee). Avoids introducing permanent group-size weighting (which would contradict "seating is not first-come-first-served" in the opposite direction, i.e., large groups always winning).

**Revision (Session 2 human review).** The algorithm was originally named "Compatibility-Aware **Weighted** Aging with Maximum-Wait Protection." No concrete, deterministic weighting formula was ever defined — Stage 4 only ever used raw wait time as an aging/fairness signal — so "Weighted" was a naming overstatement, corrected here. See `06-ai-working-record/ai-corrections.md` CORR-002. The six stages themselves are unchanged.

**Trade-offs.** See `starvation-policy.md` — protecting a complete configuration means a single table that could otherwise seat a smaller waiting group may sit empty briefly while its combination partner is still occupied and the protected group waits for both. This is a deliberate correctness-over-utilization trade documented as required by the brief ("tell us what you chose, and what it costs you").

**Implementation scope.** P0 — this is the core seating algorithm for the entire application.

**Future evolution.** Configuration scarcity, missed-opportunity tracking, and fairness debt (see `07-future-evolution/`) are explicitly deferred refinements to this policy, not replacements for it.

---

## DEC-004 — Starvation / fairness policy

**Context.** The brief explicitly flags that small groups continuously taking single tables can prevent a large group from ever seeing both required tables free at once, and requires a documented policy to prevent this.

**Chosen approach.** A configurable maximum-wait threshold (illustrated as 20 minutes, a take-home assumption, not a restaurant requirement). Before the threshold, normal compatibility + smallest-fit + wait-time aging applies. After the threshold, the group becomes starvation-protected — but protection applies to the **complete seating opportunity**, never to an individual table in isolation (a lone free table that is only half of a needed pair is never reserved indefinitely).

**The precise guarantee (corrected wording).**

> Maximum-wait protection guarantees priority when the group's complete compatible seating configuration becomes available. It does not guarantee an absolute maximum total waiting time.

If a 6-person group needing T1+T2 crosses the threshold while only T1 is free, it still cannot be seated — it is not seatable on T1 alone. Once T1 **and** T2 are simultaneously available, the protected group receives priority for that configuration over newly-eligible competitors. The threshold bounds how long the group waits *relative to competing traffic once its configuration is available*; it does not bound how long the qualifying configuration itself takes to first appear.

**Rationale / trade-offs.** See `starvation-policy.md` for the full write-up, including the explicit cost this imposes on smaller groups' wait times once a large group is protected.

**Implementation scope.** P0.

**Future evolution.** Scarcity- and fairness-debt-weighted prioritization (`07-future-evolution/fairness-debt.md`, `missed-opportunities.md`) are deferred.

**Revision (Session 2 human review).** The prior wording stated this policy "directly and provably satisfies 'no group waits forever'" with the wait "bounded by how long it takes for that configuration to next become available." That overstated the guarantee — it implied an effective upper bound on total wait time, which is not actually provided (a rare qualifying configuration could still mean a long absolute wait). Corrected to the precise guarantee above. See `06-ai-working-record/ai-corrections.md` CORR-001.

---

## DEC-005 — Position model

**Context.** Guests need a meaningful position indicator, but position is not a fixed FIFO slot given non-FIFO seating.

**Chosen approach.** Position is a dynamic rank computed from **current** state only — current waiting groups, current table availability, table capacity, adjacency, compatibility, waiting time, and starvation-protection state — recomputed on every relevant state change (join, leave, no-show, table availability change, seating, a group becoming starvation-protected). It is explicitly **not** presented as a guarantee that exactly N groups will be seated before a given guest, and it never predicts *when* a table will become free — only what the rank is right now.

**Rationale.** Matches the reality of the allocation policy; over-promising a fixed number, or implying the system forecasts future table availability, would be actively misleading given DEC-003.

**Trade-offs.** A moving position number can read as confusing to guests unfamiliar with why it changes; product copy should set that expectation (implementation-phase concern, not decided here).

**Implementation scope.** P0 — required for REQ-GUEST-002 / REQ-QUEUE-004.

**Future evolution.** A future version could show an estimated wait time instead of/alongside rank; not built now.

---

## DEC-006 — Anonymous guest identity

**Context.** No login exists; the guest must still recover their entry after closing and reopening the page.

**Chosen approach.** An anonymous **active-visit token** representing the guest's *current* waitlist visit, not a permanent account. Today's visit produces Token A tied to Queue Entry A; a future, separate visit produces an unrelated Token B tied to a new entry. Once a visit reaches a terminal state, its token no longer behaves as an active waitlist session.

**Rationale.** Satisfies "recover an active visit" without introducing any account/login concept, consistent with "nothing is kept for them between visits."

**Trade-offs.** Token possession is effectively equivalent to entry access — whoever holds the token/link can view (and act on) that entry; this is treated as an acceptable, explicitly scoped trade for a guest flow that intentionally has no authentication. Exact token transport (cookie/localStorage/URL) and unguessability strength are implementation-phase decisions, not finalized here.

**Implementation scope.** P0.

**Future evolution.** None planned; deliberately kept minimal.

---

## DEC-007 — Idempotency mechanism for join

**Context.** Join must be idempotent; phone number alone is explicitly ruled out as the mechanism (phone numbers can collide across guests/households and are not a reliable per-request identifier).

**Chosen approach.** Join uses a proper idempotency strategy backed by database-level protection (e.g., a client-supplied idempotency key persisted and checked within a transaction/unique constraint) — exact mechanism to be finalized in the specification/architecture phase, not phone number alone.

**Rationale.** Phone number is guest-supplied, unauthenticated, and not guaranteed unique per request or per guest; using it alone as a dedupe key would either over-block (two different groups sharing a household phone) or under-protect (retries that vary other fields).

**Trade-offs.** Requires the client to generate/persist an idempotency key across retries, adding minor frontend complexity versus a naive "dedupe by phone" approach.

**Implementation scope.** P0.

**Future evolution.** N/A.

---

## DEC-008 — Fairness debt / missed-opportunity tracking deferred

**Context.** A more sophisticated fairness model (tracking genuinely missed compatible seating opportunities and accumulating "debt" to influence future priority) was discussed as a possible refinement.

**Chosen approach.** **Not implemented in the two-day core.** Documented only as future evolution (`07-future-evolution/fairness-debt.md`, `missed-opportunities.md`).

**Rationale.** Adds historical scheduling state and complexity disproportionate to a two-day build; the maximum-wait threshold policy (DEC-004) already satisfies "no group waits forever" without it.

**Trade-offs.** The simpler policy is coarser — it does not distinguish a group that has been repeatedly, genuinely passed over from one that simply hasn't had a compatible configuration appear yet. Accepted as a reasonable simplification for scope.

**Implementation scope.** None (Future only).

**Future evolution.** See `07-future-evolution/fairness-debt.md` and `missed-opportunities.md`.

---

## DEC-009 — Shared tables deferred

**Context.** A "willing to share a table" guest option was discussed as a possible utilization improvement.

**Chosen approach.** **Not implemented.** The current invariant — one group per table — is maintained throughout the two-day scope. Documented as future evolution only.

**Rationale.** Shared tables would require new consent, privacy, and lifecycle rules (partial table occupancy, matching unrelated groups) that meaningfully expand scope beyond what the brief asks for.

**Trade-offs.** None accepted now — this is a pure scope exclusion.

**Implementation scope.** None (Future only).

**Future evolution.** See `07-future-evolution/shared-tables.md`.

---

## DEC-010 — Scope: P0 / P1 / Future

**Context.** The brief explicitly rewards a thin, correct slice over broad half-working coverage.

**Chosen approach.** See `scope-and-tradeoffs.md` for the full breakdown and reasoning. Headline: correctness of guest/staff flows, table/combination allocation, idempotency, concurrency safety, starvation protection, persistence, and hard-path tests are P0 and non-negotiable. Live updates, caching, async notification, structured logging/metrics, and rate limiting are P1, attempted only once P0 is stable. Fairness debt, missed-opportunity tracking, shared tables, richer staff overrides, and global scheduling optimization are Future and explicitly not attempted in this assignment.

**Rationale / trade-offs.** See `scope-and-tradeoffs.md`.

**Implementation scope.** Governs all subsequent phases.

**Future evolution.** See `07-future-evolution/production-evolution.md`.

---

## DEC-011 — Oversized groups (resolves OPEN-006)

**Context.** A group's size can exceed every permitted seating configuration (max two adjacent tables, DEC-002) — e.g., more people than the largest two-table combination in the seed data can hold. The brief does not resolve this.

**Options considered.**
- **Option A — Reject the join** with a clear validation error at submission time, directing the group to speak to staff directly.
- **Option B — Accept the join but mark it permanently unseatable**, surfacing it to staff as a group the automatic system cannot place.

**Evaluation.**
- *Correctness guarantee:* Option A keeps every entry that exists in `waiting` state guaranteed-seatable by construction — the allocation policy and starvation guarantee (DEC-004) never have to reason about an entry that can *never* satisfy any compatible configuration. Option B introduces a queue entry that is waiting forever by definition, which directly undermines the "no group waits forever" guarantee's meaningfulness (a system that lets in an unseatable entry needs a special-cased exception to its own core liveness property).
- *Implementation simplicity:* Option A is a single validation check at join time, against the same `compatible_configurations` capacity logic already needed for Stage 1 of allocation (`05-specifications/allocation-spec.md`). Option B requires a new terminal-but-not-really state, staff-facing exception handling, and carve-outs in every piece of code that assumes a `waiting` entry is eventually seatable (including starvation-protection logic and tests).
- *Guest experience:* Option A gives the guest an immediate, actionable answer instead of a false sense of being queued. Option B risks a guest believing they are being handled by the system when they are not.

**Chosen approach.** **Option A.** Reject the join at submission with a clear validation error when no single table or adjacent two-table combination (per the seed data's actual capacities, DEC-001) can seat the requested group size. The guest-facing message should direct them to speak to staff directly rather than implying the system will eventually seat them.

**Rationale.** Clearest correctness guarantee (every `waiting` entry is provably seatable by some currently-or-eventually-available configuration) and the simplest implementation, per the explicit preference in the governing prompt for this decision.

**Trade-offs.** A legitimately very large party (e.g., a party of 12) gets no automated path at all — they must be handled entirely manually by staff, outside the system. This is accepted as reasonable for the two-day scope given the seed data (DEC-001) makes this an edge case, not a common one.

**Implementation scope.** P0 — this is a join-time validation rule (`05-specifications/functional-spec.md` §1, `05-specifications/api-spec.md` join endpoint).

**Future evolution.** N-table combination chains (`07-future-evolution/production-evolution.md`) would reduce how often this rejection fires, but do not eliminate the need for the rule itself.

---

## DEC-012 — Technology stack (resolves OPEN-001)

**Context.** The candidate proposed: React + TypeScript (frontend), Ruby on Rails API (backend), PostgreSQL (database), Redis (cache), Sidekiq + Redis (background jobs), Docker Compose (containerization). The stack was evaluated against the assignment's actual demands rather than replaced by default.

**Evaluation against the assignment's hard requirements:**

| Dimension | Assessment |
|---|---|
| Two-day feasibility | High. Rails is a batteries-included framework (migrations, ActiveRecord, RSpec/Minitest, Sidekiq integration all standard) that minimizes setup time relative to the two-day window. |
| Concurrency & transaction support | PostgreSQL provides real ACID transactions; Rails/ActiveRecord exposes both pessimistic locking (`SELECT ... FOR UPDATE` via `.lock!`) and optimistic locking (`lock_version` column) — both sufficient to implement INV-001–INV-013. |
| Atomic table allocation | PostgreSQL transactions directly implement the both-or-neither guarantee (INV-005); no additional infrastructure needed. |
| Database locking | Native, first-class in PostgreSQL; no external lock service required at this scale. |
| Idempotency | A unique index on `idempotency_key` in PostgreSQL (`03-architecture/data-model.md`) gives a database-enforced guarantee, not just an application-level check. |
| Redis caching | Reasonable, minimal choice for the P1 guest read path; the risk is Redis being mistaken for a source of truth — addressed explicitly by DEC-013 below. |
| Background jobs | Sidekiq + Redis is a standard, well-documented pairing for Rails; proportionate to the "table ready" notification requirement (REQ-SHOW-003) — no heavier messaging system (e.g., Kafka) is warranted at this scale. |
| Testing | RSpec (or Minitest) plus Rails' transactional test helpers and support for request/model/concurrency-style tests directly support `05-specifications/test-strategy.md`. |
| Docker Compose | Rails + PostgreSQL + Redis + Sidekiq is one of the most common Docker Compose configurations in the ecosystem; low integration risk. |
| Developer productivity / candidate fit | The candidate's own reference project (`mentoring-session-booking-main`, inspected structurally per the Phase 3 prompt) is itself a Rails API + React SPA + PostgreSQL + Docker Compose application, indicating working familiarity with exactly this stack — materially de-risking the two-day window versus an unfamiliar stack. |

**No serious issue was identified.**

**Chosen approach.** **Keep the proposed stack as-is:** React + TypeScript, Rails API, PostgreSQL, Redis, Sidekiq + Redis, Docker Compose.

**Rationale.** Every hard requirement (atomicity, concurrency safety, idempotency) maps directly onto PostgreSQL/ActiveRecord primitives; Redis/Sidekiq are proportionate, standard choices for the P1 stretch items rather than overengineering; and the candidate has demonstrated working familiarity with this exact combination.

**Trade-offs.** None significant identified. The only discipline required is keeping Redis strictly out of the authority path for table-allocation decisions — see DEC-013.

**Implementation scope.** Governs all subsequent implementation.

**Future evolution.** N/A — this is the stack for the assignment, not a long-term platform decision.

---

## DEC-013 — Cache/consistency principle: PostgreSQL is sole source of truth (resolves OPEN-003)

**Context.** With Redis approved as the P1 cache technology (DEC-012), a boundary must be fixed so caching cannot silently become a second, potentially inconsistent source of truth for table availability.

**Chosen approach.**

> PostgreSQL is the source of truth for table allocation. Redis must never be used to determine whether a table is actually free.

Redis, if built, sits only in front of the **guest read path** (REQ-SHOW-002) and is invalidated on every relevant write event (`04-diagrams/07-architecture-data-flow.md`). Every allocation decision (seat, release, no-show, combined-table acquisition) reads and writes PostgreSQL directly, inside a transaction, regardless of what Redis currently holds.

**Rationale.** This is the mechanism that prevents the "cache goes stale during a queue update" risk (Phase 1 analysis §6) from becoming an actual correctness bug rather than a momentary display staleness. A stale Redis read can, at worst, show a guest a slightly outdated position; it can never cause a double-booked table, because Redis is never consulted by the allocation path.

**Trade-offs.** None beyond the ordinary cost of maintaining an invalidation path (already scoped under REQ-SHOW-002, P1).

**Implementation scope.** P1 (only relevant once Redis caching is actually built); the principle itself is a standing architectural constraint from now on regardless of when Redis lands.

**Future evolution.** N/A.

---

## DEC-014 — Release identified by seating assignment, not raw table

**Context.** Human review identified that allowing a release call to take an arbitrary `table_id` risks releasing only half of a combined pair, or invoking release against a table that isn't actually the caller's concern — bypassing the atomicity that combined-table allocation is supposed to guarantee end-to-end.

**Chosen approach.** Release is identified by the **seated `queue_entry_id`** (the group being released), never by a raw `table_id` or `combination_id` supplied independently. The backend resolves internally whether that entry occupies a single table or a combined pair, and releases the complete assignment atomically in one transaction — there is no code path that can release only one member of a combination.

**Rationale.** Matches the same "both-or-neither" discipline already required for allocation (INV-005) — release is symmetric to allocation and should be exactly as atomic. Identifying by queue entry also matches how staff actually think about the action ("this group is leaving"), not by table bookkeeping detail.

**Trade-offs.** None — this is strictly a tightening of the existing API surface, not a new capability.

**Implementation scope.** P0 — updates `03-architecture/api-overview.md` and `05-specifications/api-spec.md` release endpoint.

**Future evolution.** N/A.

---

## DEC-015 — READY reservation expiration policy (resolves OPEN-007 for the `ready` state)

**Context.** Phase 5B.1 domain-model analysis (`05-specifications/domain-model-proposal.md`) introduced a `ready` `QueueEntry` state — a group whose configuration has been chosen and whose table(s) are provisionally held, waiting for staff to confirm via the seating code. Human review of that proposal identified that nothing prevented a `ready` reservation from holding its table(s) indefinitely if the group never showed up and staff never got around to marking them no-show — a real starvation/utilization risk the proposal itself had only flagged as an open question, not resolved.

**Chosen approach.**

```
WAITING → READY → (5-minute timeout, no staff confirmation) → NO_SHOW → reserved tables released atomically
```

- **Outcome on expiry:** auto-`no_show`. A `ready` entry whose reservation has been held past the timeout transitions to the existing terminal `no_show` state — the same state and release path staff already use manually, not a new terminal state.
- **`ready → waiting` is explicitly NOT used for this.** A demote-back-into-the-queue path was considered and rejected for the MVP (see Trade-offs).
- **Evaluation mechanism: lazy, not a background sweep.** No Sidekiq job, scheduler, or periodic process is introduced. Overdue `ready` reservations are expired inline, as a side effect of operations that already touch the relevant entries/tables: guest position/read, staff queue/table view, guest join, allocation/availability calculation, and seating operations. Before an allocation decision considers a table, any stale `ready` reservation holding it is expired and released first, in the same transaction as the decision that needs the table.
- **Duration:** 5 minutes. A tunable configuration value (env/config, not a hardcoded literal in business logic and not a database-persisted setting) — the same treatment as the starvation threshold in DEC-004.

**Rationale / documented trade-off (verbatim, as the record of this decision):**

> A READY reservation expires after 5 minutes and becomes NO_SHOW if staff has not confirmed the seating code. This prevents tables from being held indefinitely and keeps the MVP state machine simple. Lazy expiration avoids introducing scheduler/background-job infrastructure solely for this timeout. The trade-off is that a guest may lose their place if the delay was caused by staff rather than the guest. A future version could distinguish guest timeout from staff-caused expiration and return the guest to WAITING while preserving the original waiting timestamp.

**Implementation scope.** P0 — this closes a real correctness gap in the P0 state machine (an unbounded hold was possible without it), not a P1 nicety.

**Future evolution.** Distinguishing guest-caused vs. staff-caused expiration, and a `ready → waiting` re-queue path preserving original wait time, per the trade-off note above — not built now.

---

## Open decisions (not yet made — tracked, not resolved here)

These remain open and must not be silently decided by an agent. See `01-requirements/requirements-analysis.md` and the Phase 1 analysis for full context. Resolved items (OPEN-001, OPEN-003, OPEN-004, OPEN-006) have been moved into the decision entries above and are removed from this list.

| ID | Open decision | Status |
|---|---|---|
| OPEN-002 | Live-update mechanism (polling vs. SSE vs. WebSockets) | Still pending — not addressed by this review round |
| OPEN-005 | Seating-code format/strength | Pending specification phase |
| OPEN-007 | Guest abandonment/expiration behavior | **Partially resolved** by DEC-015 — the `ready`-state case (a called group that never shows up) is decided. The `waiting`-state case (a guest who stops polling but is never called) remains open; lower urgency, since an unwatched `waiting` entry holds no table hostage the way a `ready` one does. |

**Note on OPEN-004 (idempotency key format).** Partially resolved by this review round: the join idempotency key is client-generated (a UUID is sufficient) and reused verbatim across retries of the same logical attempt; a genuinely new join attempt uses a new key (`05-specifications/api-spec.md`, `04-diagrams/06-guest-join-idempotency.md`). The exact transport (header vs. body field) remains an implementation-phase detail, not elevated to a standalone open item.
