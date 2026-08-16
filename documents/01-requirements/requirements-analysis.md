# Requirements Analysis

Status: baseline analysis, carried forward from the Phase 1 Claude session and reconciled with the Phase 3 approved product decisions.

## 1. Source documents

- Assignment brief (restaurant waitlist take-home).
- `documents/06-ai-working-record/agent-prompts.md` — Phase 1 requirements-analysis prompt and Phase 3 documentation-foundation prompt.
- `documents/02-product-decisions/decision-log.md` — decisions approved by the candidate that constrain this analysis.

## 2. Explicit requirements

See `functional-requirements.md` and `non-functional-requirements.md` for the itemized, ID-tagged lists. In summary, the brief explicitly requires:

- An unauthenticated guest flow (join with group size + phone number, view position, leave, recover an active visit, receive a seating code).
- An authenticated staff flow (login stub, view queue/tables, seat by code, release tables, mark no-show).
- Backend correctness guarantees: one group per table, atomic combined-table allocation, idempotent join, non-FIFO position, no starvation.
- Persisted data with migrations, and tests for the hard paths.
- A runnable app, Docker Compose preferred.
- "Show us if you can" stretch items: live updates, cached read path, async notification job, observability, rate limiting.

## 3. Implicit requirements

Necessary for the explicit behavior to actually work, even though not stated as discrete features:

| ID | Implicit requirement | Why it's required |
|---|---|---|
| IMP-001 | An anonymous identity token tied to a queue entry | Required for "recover an active visit after closing/re-scanning" with no login |
| IMP-002 | A concurrency-safe allocation mechanism at the data layer (not just application-level checks) | Required for "one group per table" and atomic combined seating to hold under concurrent writes |
| IMP-003 | An explicit state machine for queue entries and tables | "Seat," "release," "no-show," "leave" are transitions between defined states, not free-form fields |
| IMP-004 | Cache invalidation tied to every state-changing write | Required for a cached read path to stay correct (P1, if built) |
| IMP-005 | A capacity/adjacency matching function, not a raw counter, for position | Required because position depends on table configuration, not arrival order alone |
| IMP-006 | Guest-entry access scoping (a guest can only act on their own entry) | Required because there is no login to naturally scope access |
| IMP-007 | A durable record of *why* an entry left the queue (left vs. no-show vs. seated) | Required to keep no-show and voluntary-leave as distinct, auditable outcomes |

These are treated as requirements, not options — they are necessary consequences of the explicit requirements above, distinguished here from **recommendations**, which are choices about *how* to satisfy them (see `documents/02-product-decisions/decision-log.md`).

## 4. Assumptions in force for this take-home

These are declared, not hidden. Each is an assumption made **for the scope of the 2-day build**, not a claim that it reflects real restaurant operations.

| ID | Assumption | Basis |
|---|---|---|
| ASM-001 | Seed data is 40 tables: 20×2-seat, 18×4-seat, 2×6-seat | Approved decision, `documents/02-product-decisions/decision-log.md` DEC-001 |
| ASM-002 | A group may combine at most two adjacent tables | Approved decision, DEC-002 |
| ASM-003 | Starvation-protection threshold is a configurable value, illustrated as 20 minutes | Approved decision, DEC-004; explicitly not a claimed restaurant requirement |
| ASM-004 | One staff user operates the staff UI at a time | Stated directly in the brief |
| ASM-005 | Adjacency is symmetric and given as fixed seed data (no adjacency-inference logic needed) | Reasonable reading of "table layout... is seed data" |
| ASM-006 | Guests do not change group size after joining (no "grew/shrank at the door" flow) in the P0 scope | Explicitly called out in the brief as real-world messiness; deferred, see `07-future-evolution/production-evolution.md` |

## 5. Priorities

See `05-specifications/functional-spec.md` §Scope and `02-product-decisions/scope-and-tradeoffs.md` for the full P0/P1/Future breakdown. Headline: **P0 is guest+staff flows, correct table/combination allocation, idempotent join, concurrency safety, starvation protection, persistence+migrations, and hard-path tests.** Live updates, caching, async notification, observability, and rate limiting are P1. Fairness debt, missed-opportunity tracking, shared tables, and richer overrides are explicitly Future and out of scope for the two-day build.

## 6. Traceability

Every requirement in `functional-requirements.md` maps to at least one acceptance criterion in `acceptance-criteria.md` and, where applicable, to a hard-path test in `05-specifications/test-strategy.md`.
