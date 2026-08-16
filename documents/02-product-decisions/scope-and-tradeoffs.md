# Scope and Trade-offs

Governs DEC-010. This is the working scope contract for the two-day build — the boundary agents must not silently expand or shrink.

## P0 — Must be correct

Non-negotiable; do not sacrifice any of this for P1 features.

- Guest flow: join (idempotent), view position, leave, recover active visit, receive seating code.
- Staff flow: login (stub), view queue/tables, seat by code, release, mark no-show.
- Table allocation: exclusivity, capacity/adjacency-aware compatibility, smallest-fit preference.
- Atomic combined-table seating (both-or-neither).
- Starvation protection per `starvation-policy.md`.
- Concurrency safety on all write paths.
- Persistence with migrations.
- Hard-path tests (concurrency, idempotency, atomicity, starvation — see `05-specifications/test-strategy.md`).
- Runnable application (Docker Compose preferred).

## P1 — If P0 is stable

Attempted only once P0 is demonstrably correct and tested.

- Live updates for the guest screen.
- Caching the guest read path.
- Cache invalidation on relevant write events.
- Async background job for "table ready" notification.
- Structured logging.
- Basic metrics.
- Rate limiting on the public guest endpoint.

## Future — explicitly not built in this assignment

Documented under `07-future-evolution/` as design thinking only, clearly labeled as not implemented.

- Fairness debt tracking.
- Missed-seating-opportunity tracking.
- Configuration-scarcity-weighted prioritization.
- Shared tables (guest-consented table sharing).
- Global/optimal scheduling optimization.
- Richer staff overrides (e.g., manual queue reordering, forced un-seat, editable seed data via UI).
- Handling guests who change group size at the door, or "wander off" without leaving/no-show (beyond what no-show already covers) — real-world messiness explicitly called out in the brief as ours to choose; deferred rather than built, given the two-day window.

## Explicit cuts and reasoning

| Cut | Reasoning |
|---|---|
| Camera-based QR/code scanning | Brief states this explicitly is not the point ("the point is the backend, not the camera"); manual code entry is sufficient. |
| Multi-staff concurrent UI / permission tiers | Brief explicitly assumes one staff UI user; only the backend concurrency safety matters. |
| Table-layout management screen | Brief states layout is seed data with no management screen. |
| Guest accounts or cross-visit history | Brief explicitly excludes this ("nothing is kept for them between visits"). |
| Real SMS/push notification delivery | Brief asks for an async *mechanism* (job off the request path), not a real delivery integration; building a real SMS integration is disproportionate to the two-day window and not required for the "show us if you can" credit, which is about the pattern, not the carrier. |
| N-table (3+) combinations | DEC-002 caps combination at two tables, matching the brief's own framing; see open question below for groups exceeding two-table capacity. |

## Resolved — oversized groups (was an open question, now DEC-011)

**What happens when a group's size exceeds all combinable capacity** (e.g., a party larger than any two-table combination can seat, given the seed data's largest pair)? The brief does not resolve this, and DEC-002 (max two tables) means such a group cannot be seated by the core algorithm. Resolved in Session 2 human review: the join is **rejected at submission** with a clear validation error directing the group to speak to staff, rather than accepted and left permanently unseatable. Full evaluation of both options and the rationale is in `decision-log.md` DEC-011.

## Cross-cutting concerns chosen for "done well"

Per the brief's instruction that a thin, correct slice with one or two cross-cutting concerns done well beats broad, half-working coverage, this project prioritizes:

1. **Concurrency/atomicity correctness** across the full write path (join, seat, release, no-show), including the hard combined-table atomicity requirement — this is P0 and tested explicitly, not assumed correct.
2. **One live-update + caching pairing** (P1) — attempted as a single coherent pair (e.g., polling backed by a cached read path with explicit invalidation) rather than partially implementing several stretch items shallowly.

Everything else in P1 is genuinely optional against remaining time, in the order listed above.
