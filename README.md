# Restaurant Waitlist

A restaurant waitlist take-home assignment: guests join a queue by scanning a QR code, watch their position from their phone, and staff seat them as tables free up.

## Status

**Phase 5A — runnable bootstrap complete and verified.** Documentation, specification, and architecture decisions were completed and reviewed first (Sessions 1–2), the AI-native development environment was configured next (Session 3), and a runnable React + Rails + PostgreSQL foundation now exists under Docker Compose (Sessions 4–5) — see `documents/06-ai-working-record/` for the full record.

## Current implementation status

**Phase 5A — Runnable bootstrap complete.**

Implemented:
- React + TypeScript frontend
- Rails API backend
- PostgreSQL
- Docker Compose
- Health endpoint
- Frontend/backend connectivity check

Not yet implemented:
- queue domain
- guest join
- guest identity
- idempotency
- table allocation
- starvation protection
- staff operations
- Redis
- Sidekiq

## Technology stack (approved — DEC-012)

React + TypeScript (frontend) · Ruby on Rails API (backend) · PostgreSQL (database, source of truth) · Redis (P1 cache, guest read path only — never authoritative) · Sidekiq + Redis (P1 background jobs) · Docker Compose (containerization). Full evaluation in `documents/02-product-decisions/decision-log.md` DEC-012.

## Where to start

| If you want... | Go to |
|---|---|
| The full requirements analysis | `documents/01-requirements/` |
| The product decisions that are locked in (seating algorithm, starvation policy, scope) | `documents/02-product-decisions/` |
| The system/domain/data/API design | `documents/03-architecture/` |
| Diagrams of the key flows | `documents/04-diagrams/` |
| Implementation-ready behavioral specs | `documents/05-specifications/` |
| The AI working record (prompts, decisions, corrections, session log) | `documents/06-ai-working-record/` |
| What's explicitly deferred and why | `documents/07-future-evolution/` |

## The short version

- **Guest screen:** scan a shared QR code, join with group size + phone number (no login), watch position, leave anytime, recover an active visit after closing the tab, get a code when ready.
- **Staff screen:** login (stub), view the live queue and every table's state, seat a group by its code, release tables when a group leaves, mark no-shows.
- **The hard part:** one group per table, atomic all-or-nothing combined-table seating for large groups, idempotent join under retries, non-FIFO position that reflects real table availability, and a documented policy giving large groups seating priority once their full table configuration is available — see `documents/02-product-decisions/starvation-policy.md` for the precise guarantee (it does **not** promise an absolute maximum wait time), the chosen rule, and what it costs.

## Open decisions before implementation starts

Resolved as of Session 2: technology stack (DEC-012), cache technology and its authority boundary (DEC-013), oversized-group handling (DEC-011), release granularity (DEC-014), and the idempotency-key format (client-generated UUID). Still open — see `documents/02-product-decisions/decision-log.md` §Open decisions: live-update mechanism (`OPEN-002`), seating-code format/strength (`OPEN-005`), and guest-abandonment/expiration behavior (`OPEN-007`).

## Run instructions

```
docker compose up
```

Starts PostgreSQL, the Rails API backend (`http://localhost:3000`, health check at `/health`), and the React frontend (`http://localhost:5173`). Requires Docker (this project was developed and verified against Colima on Apple Silicon; Docker Desktop works equally well). Dev-only credentials (`postgres`/`postgres`) are set directly in `docker-compose.yml` — not secrets, not used anywhere else. No business functionality is implemented yet (see "Current implementation status" above) — this brings up the infrastructure only.
