# Non-Functional Requirements

| Category | ID | Requirement | Priority | Notes |
|---|---|---|---|---|
| Correctness | NFR-CORR-001 | One group occupies at most one table (or one combined pair) at a time; no double-booking under any interleaving of requests | P0 | Core invariant, see `03-architecture/domain-model.md` INV-001..004 |
| Correctness | NFR-CORR-002 | Combined-table allocation is all-or-nothing | P0 | See `02-product-decisions/seating-allocation-policy.md` |
| Concurrency | NFR-CONC-001 | Backend write paths (join, seat, release, no-show) are safe under concurrent guest/staff requests | P0 | Explicit in brief despite single-staff-UI assumption |
| Concurrency | NFR-CONC-002 | No lost updates or partial writes under race conditions on table state | P0 | Requires DB-level protection (transactions/locking), not app-level checks only |
| Idempotency | NFR-IDEM-001 | Guest join is idempotent: a retried request never creates a second entry | P0 | Explicit; must not rely on phone number alone (approved decision) |
| Idempotency | NFR-IDEM-002 | Seat, release, and no-show operations are safe to retry without corrupting state | P0 | Implicit, required by NFR-CONC-001 |
| Persistence | NFR-PERS-001 | Queue and table state survive process restarts | P0 | Explicit ("persisted data") |
| Persistence | NFR-PERS-002 | Schema evolves via versioned migrations | P0 | Explicit |
| Availability/Reliability | NFR-AVAIL-001 | No group waits forever for seating, even under adversarial small-group arrival patterns | P0 | Liveness guarantee, not just a correctness one; policy in `starvation-policy.md` |
| Performance | NFR-PERF-001 | The read path tolerates "hundreds of guests" refreshing through a Friday evening without degrading | P1 | No explicit SLA given; addressed via caching if built |
| Security | NFR-SEC-001 | Staff actions require authentication | P0 | Stub auth acceptable |
| Security | NFR-SEC-002 | A guest can only view/act on their own queue entry | P0 | Implicit, no login to scope access otherwise |
| Security | NFR-SEC-003 | Phone number is never treated as an authentication credential | P0 | Explicit AI-agent risk called out in Phase 1 analysis |
| Security | NFR-SEC-004 | The public guest endpoint is rate-limited | P1 | Explicit "show us if you can" |
| Observability | NFR-OBS-001 | Logs and metrics exist to reconstruct "why did group X wait N minutes" | P1 | Explicit "show us if you can" |
| Scalability | NFR-SCALE-001 | System handles the stated scale (~40 tables, ~400 groups/evening) without special scaling infrastructure | P0 | No larger scale implied; avoid overengineering |
| Deployability | NFR-DEPLOY-001 | Application runs via `docker compose up` for frontend + backend, with run instructions | P0 | Explicit |
| Testability | NFR-TEST-001 | Hard paths (concurrency, idempotency, atomicity, starvation, cache invalidation if built) are covered by automated tests prioritizing business correctness over controller wiring | P0 | Explicit |
