# Agent Prompts

Verbatim record of the prompts actually given to the AI agent (Claude Code) for this assignment, in chronological order. Both prompts were authored by the candidate as standalone Markdown files and supplied in the same Claude Code session.

---

## Prompt 1 — Phase 1: Requirements Analysis Only

**Source file:** `restaurant_waitlist_claude_phase1_requirements.md` (supplied by the candidate, read from local Downloads folder).

**Session context:** First substantive prompt of the session. Instructed Claude to act as a Senior Product Engineer / Requirements Analyst and produce a structured requirements inventory only — no code, no files, no repository changes, no final technology or schema decisions.

**Full text:**

> # Restaurant Waitlist — Claude Requirements Analysis
>
> ## Purpose
>
> This document is the **first input to Claude Code** for the Restaurant Waitlist take-home assignment.
>
> ### Current phase
>
> **Phase 1 — Requirements Analysis**
>
> At this stage, Claude must **not implement anything**. The objective is to independently analyze the assignment so that we can compare Claude's interpretation with our own analysis before making scope, architecture, and product decisions.
>
> [Full assignment brief: setting, guest screen, staff screen, must-have requirements (frontend/backend), "show us if you can" items, "your call" items, deliverables (running app, README, AI working record), interview session.]
>
> ### Claude Task — Phase 1: Requirements Analysis Only
>
> Instructed to produce, as analysis only (no code/files/agents/config):
> 1. Explicit functional requirements (ID-tagged, who/what/result/acceptance criteria)
> 2. Explicit non-functional requirements (correctness, concurrency, idempotency, persistence, availability, performance, security, observability, scalability, deployability, testability)
> 3. Implicit requirements, clearly distinguished from recommendations
> 4. Domain entities (conceptual, no schema)
> 5. Domain invariants (ID-tagged)
> 6. Concurrency risks
> 7. Idempotency analysis (join, seating, release, no-show)
> 8. Table allocation rules and ambiguities
> 9. Queue/position rules ("not FIFO" analysis)
> 10. Starvation problem — marked `DECISION REQUIRED`, no policy selected
> 11. Anonymous guest identity analysis
> 12. Live updates — polling/SSE/WebSocket trade-offs, no selection
> 13. Caching — what/why/staleness/invalidation triggers, no technology chosen
> 14. Background jobs — sync vs async boundary, no queue technology chosen
> 15. Observability — logs, metrics, correlation IDs, business events
> 16. Security concerns, must-have vs. optional hardening
> 17. Hard-path test scenarios, P0-marked
> 18. `DECISIONS REQUIRED` checklist
> 19. Scope analysis: P0/P1/P2/Explicitly cut, with reasoning
> 20. AI-agent risks (where a coding agent is likely to assume wrong)
>
> Final response required to be analysis only, with a concise summary, P0/P1/P2 scope proposal, `DECISIONS REQUIRED` checklist, top 10 risks, top 10 tests, and top 10 AI-agent failure modes. Explicit instruction: do not modify files, do not create code, do not implement anything, do not create agents or configuration. Stop after the analysis, and bring it back to the human decision process before any implementation is requested.

**Full analysis produced in response to this prompt is preserved in this session's transcript and summarized in `session-log.md`; the approved decisions that emerged from human review of it are recorded in `../02-product-decisions/decision-log.md`.**

---

## Prompt 2 — Phase 3: Documentation & Specification Foundation

**Source file:** `restaurant_waitlist_phase3_claude_prompt.md` (supplied by the candidate, read from local Downloads folder, after the candidate had made product decisions informed by the Phase 1 analysis).

**Session context:** Second substantive prompt. Instructed Claude that the candidate had already made and approved a set of product/architecture decisions (table seed data, max combination size, the full seating allocation algorithm, starvation policy, position model, guest identity mechanism, idempotency requirement), and to turn these — plus the requirements — into a structured, committable documentation set. Explicitly still no application code, migrations, agents, skills, hooks, or MCP config.

**Full text:**

> # Claude Prompt — Phase 3: Documentation & Specification Foundation
>
> ## Purpose
>
> This is the first Claude session for the Restaurant Waitlist take-home assignment. **This phase is documentation/specification only.** Do not implement application code, APIs, database migrations, frontend components, agents, skills, or MCP integrations yet. The goal is to create a clean, specification-driven development foundation and an auditable AI working record. The candidate is driving the product and architecture decisions. Do not silently replace or reinterpret those decisions.
>
> [Sections 1-2: Assignment restated, Must-Have Requirements restated for guest/staff/tables/queue/infrastructure/frontend/optional.]
>
> ## 3. Approved Product Decisions
>
> - Table seed data: 20 two-seat, 18 four-seat, 2 six-seat tables (40 total), represented by ID/capacity/adjacency/occupancy state; no permanent group-size-to-table binding.
> - Maximum combination: at most two adjacent tables, atomic (both or neither).
>
> ## 4. Final Seating Allocation Algorithm
>
> **Compatibility-Aware Weighted Aging with Maximum-Wait Protection**, in six stages: (1) determine seating requirements by capacity/adjacency, (2) find compatible available configurations, (3) prefer smallest suitable configuration, (4) wait-time aging among competing groups (no arbitrary permanent group-size weighting), (5) maximum-wait/starvation protection (configurable threshold, e.g. 20 minutes — take-home assumption) with the critical rule that protection applies to the complete seating opportunity, never an individual table in isolation, (6) atomic allocation (transaction-safe, both-or-neither for combined tables).
>
> ## 5. Position Model
>
> Position is a dynamic rank under the current policy, not a permanent FIFO number; changes on join/leave/no-show/table availability/seating/starvation-protection events; never promised as an exact seating-order guarantee.
>
> ## 6. Guest Identity
>
> Anonymous active-visit token representing the current waitlist visit only (not a permanent account); recovers an active visit after closing/reopening; a terminal visit no longer behaves as an active session.
>
> ## 7. Idempotency
>
> Join must be idempotent; phone number alone must not be the mechanism; a retry must not create a second entry; requires a proper idempotency strategy plus database protection.
>
> ## 8. Future Fairness — DO NOT IMPLEMENT NOW
>
> Configuration scarcity, missed compatible opportunities, and fairness debt documented as future evolution only, not built in the two-day core.
>
> ## 9. Future Shared Tables — DO NOT IMPLEMENT NOW
>
> "Willing to share a table" documented as future evolution only; current invariant remains one group per table.
>
> ## 10. Scope
>
> P0 (must be correct): guest flow, staff flow, table allocation, idempotent join, concurrency safety, atomic combined seating, starvation protection, persistence, migrations, hard-path tests, runnable application. P1 (if P0 stable): live updates, cache, cache invalidation, async notification, structured logging, basic metrics, rate limiting. Future: fairness debt, missed-opportunity tracking, advanced scarcity optimization, shared tables, global scheduling optimization, richer staff overrides. Do not sacrifice P0 correctness for optional features.
>
> ## 11. Required Documentation Structure
>
> Create `restaurant-waitlist/documents/{01-requirements, 02-product-decisions, 03-architecture, 04-diagrams, 05-specifications, 06-ai-working-record, 07-future-evolution}/` and a top-level `README.md`, populated per a detailed file list and content spec for each subdirectory (requirements analysis/functional/non-functional/acceptance-criteria; decision log/seating-allocation-policy/starvation-policy/scope-and-tradeoffs; architecture/domain-model/data-model/api-overview; 7 Mermaid diagrams; functional-spec/allocation-spec/api-spec/test-strategy; ai-development-approach/agent-prompts/agent-decisions/ai-corrections/session-log; fairness-debt/missed-opportunities/shared-tables/production-evolution future-evolution docs).
>
> ## 12. AI Governance
>
> Agents may identify contradictions/edge cases/alternatives, challenge assumptions, review specs, identify risks. Agents must not silently change business rules, starvation policy, table allocation policy; must not expand scope, add unnecessary infrastructure, implement future features, or claim future features are implemented. Important contradictions must be documented and surfaced for human review.
>
> ## 13. AI Working Method
>
> Assignment → requirements analysis → human product decisions → specification → human specification review → agent-assisted implementation → tests → agent review → human verification → corrections → final verification. Goal is not to maximize AI-generated code volume, but to demonstrate planning, constraining, reviewing, correcting, and verifying AI-assisted engineering work.
>
> ## 14. Reference Project
>
> If a reference project/archive is available in the workspace, inspect only its documentation organization as a structural reference; do not copy its implementation, architecture, or decisions blindly.
>
> ## 15. Strict Phase Boundary
>
> DO NOT: write application code, create backend APIs, create frontend components, create database migrations, install unnecessary dependencies, create implementation agents/skills, configure MCP servers, implement Redis, implement queues, implement authentication.
>
> ## 16. Final Output
>
> Create the documentation structure and populate the Markdown files, using Mermaid where appropriate; no application code. Report: files created, major assumptions, unresolved questions, contradictions/risks found, recommendations requiring human approval. Do not silently change any approved product decision.

---

## Prompt 3 — Phase 3 Review Correction & Architecture Decision

**Source file:** `restaurant_waitlist_phase3_review_architecture_prompt.md` (candidate-authored, read from `~/Downloads/`, in a new session continuing work on the same `~/Documents/restaurant-waitlist/` repository).

**Session context:** Human review of the Session 1 documentation output surfaced specific overstatements/gaps to correct, plus a candidate-proposed technology stack to evaluate (not replace by default) and finalize the architecture around. Still documentation/design only — no code, migrations, agents, skills, or MCP config.

**Full text:**

> # Claude Prompt — Phase 3 Review Correction & Architecture Decision
>
> ## Purpose
>
> We have completed the initial requirements and specification documentation for the Restaurant Waitlist take-home assignment. This session is still **DOCUMENTATION / DESIGN ONLY**. Do NOT write application code, create backend APIs/migrations/frontend components, create implementation agents/skills, or configure MCP servers. The purpose of this session is to correct the specification based on human review and finalize the technology and architecture direction before implementation. The candidate is driving the product decisions; challenge them where useful, but do not silently replace approved decisions.
>
> ## 1. Human Review Corrections
>
> **Correction 1 — Starvation guarantee.** Prior wording implied the starvation policy "provably satisfies no group waits forever" — too strong. Correct rule: maximum-wait protection guarantees priority when the group's complete compatible seating configuration becomes available; it does not guarantee an absolute maximum total waiting time. Update all relevant documentation.
>
> ## 2. Algorithm Naming
>
> Rename "Compatibility-Aware **Weighted** Aging with Maximum-Wait Protection" to "Compatibility-Aware Aging with Maximum-Wait Protection" unless a concrete, deterministic weighting formula is identified as necessary — none was. The six stages (determine compatible configurations, find available compatible configurations, prefer smallest suitable, wait-time aging, maximum-wait protection, atomic allocation) are unchanged. Do not introduce arbitrary group-size weights.
>
> ## 3. Position Calculation
>
> Remove any implication that the system predicts "soon available" tables. Position must be based on CURRENT state only (waiting groups, table availability/capacity/adjacency/compatibility, waiting time, starvation-protection state) — never a prediction of when a table will become free. Position is dynamic and may change after relevant queue/table events.
>
> ## 4. Allocation Must Not Be Naive Greedy Table Iteration
>
> The specification must make clear that seating is not `for each table: find first group that fits; seat it`. The scheduler must evaluate compatible seating configurations and waiting groups globally: available table configurations → compatible waiting groups → eligible allocations → apply starvation protection → prefer smallest suitable configuration → apply waiting-time aging → select allocation → atomic database transaction. Exact implementation algorithm can be finalized later, but the specification must preserve this global reasoning.
>
> ## 5. Idempotency
>
> Clarify: a join attempt has a unique idempotency key (client-generated, e.g. UUID-A); on network failure, retry reuses the same key and yields the same queue entry; a genuinely new join attempt gets a new key. Do NOT use phone number as the idempotency key. Combine client-side key reuse on retry with backend/database uniqueness protection.
>
> ## 6. Table Release
>
> Do not design release as an arbitrary individual-table operation when tables are combined. If T1+T2 → Group A, releasing Group A must release the complete seating assignment atomically. The API/domain model should identify the seating assignment or queue entry, not allow releasing an arbitrary half of a combined unit. Update the API specification.
>
> ## 7. Oversized Groups
>
> Resolve the case where a group cannot fit in any permitted seating configuration. Evaluate Option A (reject the join with a clear validation error) vs. Option B (accept but mark permanently unseatable). Prefer whichever gives the clearest correctness guarantee and simplest implementation. Document the decision and trade-off.
>
> ## 8. Technology Proposal
>
> Candidate's proposed stack: React + TypeScript (frontend), Ruby on Rails API (backend), PostgreSQL (database), Redis (cache), Sidekiq + Redis (background jobs), Docker Compose. Evaluate against two-day feasibility, concurrency/transaction support, atomic table allocation, database locking, idempotency, Redis caching, background jobs, testing, Docker Compose, developer productivity, and suitability for the candidate's existing skills. Do NOT replace it simply because another stack is possible — if suitable, explicitly recommend keeping it; if there's a serious issue, explain it and propose a minimal alternative. Do not add Kafka or another unnecessary messaging system.
>
> ## 9. Architecture
>
> If the stack is approved, update architecture docs to reflect React SPA → Rails API → PostgreSQL, and Rails API → Redis → Sidekiq worker → notification provider/stub. Redis is an optimization for the read-heavy guest position path; PostgreSQL remains the source of truth for queue and table state.
>
> ## 10. Concurrency Principle
>
> Document clearly: PostgreSQL is the source of truth for table allocation; Redis must never be used to determine whether a table is actually free. The eventual implementation must protect one group per table, combined-table atomicity, no partial allocation, and idempotent joins via database transactions/constraints/locking. Do not implement yet.
>
> ## 11. API Contract Review
>
> Ensure the API spec clearly distinguishes Guest (join; get active visit/position; leave) from Staff (login; queue; tables; seat by code; release seating assignment; mark no-show). Keep the API minimal — no unnecessary CRUD endpoints.
>
> ## 12. Testing Specification
>
> Update the test strategy to explicitly cover 12 named cases: duplicate join with the same idempotency key; concurrent duplicate join; one table cannot be assigned twice; combined tables allocated atomically; partial combined allocation rolls back; combined tables cannot be independently allocated while occupied; combined tables become independently available after release; smaller group can use a larger table when appropriate; large group is not compatible with a single insufficient table; starvation-protected group gets priority when its complete configuration becomes available; starvation protection does not reserve an incomplete configuration; dynamic position changes after queue/table state changes.
>
> ## 13. AI Governance
>
> Do not create implementation agents/skills/MCP config yet — next phase, after architecture/specification is approved. Candidate continues to drive product decisions. Agents may identify contradictions/edge cases/alternatives, challenge assumptions, review specs, identify risks; must not silently change business rules, starvation policy, or table allocation policy, expand scope, add unnecessary infrastructure, implement future features, or claim future features are implemented.
>
> ## 14. AI Working Record
>
> Record this session in `session-log.md` and this prompt in `agent-prompts.md`. If an actual mistake from the previous Claude output is identified during this review, record it in `ai-corrections.md` with session/prompt/AI suggestion/why incorrect/human review/correction/final decision/resulting specification change. Do NOT fabricate mistakes.
>
> ## 15. Required Output
>
> Update the existing documentation only — no application code, agents, skills, or MCP configuration. At the end provide: corrected files; final recommended technology stack; final architecture; final allocation-policy summary; unresolved decisions; risks; what is now frozen for implementation; what remains intentionally deferred. Next phase begins only after candidate review and approval.

---

## Prompt 4 — Phase 4: AI-Native Development Configuration

**Source file:** `restaurant_waitlist_phase4_ai_configuration_prompt.md` (candidate-authored, read from `~/Downloads/`, in a new session continuing on the same repository after Session 2's output was approved).

**Session context:** With requirements, product decisions, specifications, architecture, and test strategy reviewed and frozen, this prompt authorized configuring the AI-native development environment itself — `CLAUDE.md`, agents, skills, commands, hooks, settings, and MCP if genuinely useful — while keeping application implementation explicitly out of scope for one more session.

**Full text:**

> # Claude Prompt — Phase 4: AI-Native Development Configuration
>
> ## Purpose
>
> Phase 3 requirements, product decisions, specifications, architecture, and test strategy have been reviewed and are now the baseline for implementation. This phase establishes the AI-native development environment. The goal is to configure Claude so that future implementation is specification-driven, bounded by the approved product decisions, traceable to requirements, test-driven for hard paths, reviewable, and reproducible across sessions.
>
> This phase is configuration and development-process setup only. Do NOT implement application features, create Rails controllers/models, create React components, create database migrations, implement Redis caching, implement Sidekiq jobs, write production application code, or create unnecessary infrastructure. You MAY create: CLAUDE.md; Claude agent definitions; skills; commands; hooks; settings/configuration; MCP configuration if genuinely useful; documentation describing the AI workflow.
>
> ## 1. Source of Truth
>
> `documents/01-requirements/` through `documents/07-future-evolution/` are authoritative. Read them before creating configuration. Do not duplicate large sections into configuration files — make agents reference the documents. If a contradiction is found, STOP and report it for human review rather than silently changing the product decision.
>
> ## 2. Approved Technology Stack
>
> React + TypeScript / Ruby on Rails API / PostgreSQL / Redis / Sidekiq + Redis / Docker Compose. Do not introduce Kafka or another messaging platform, or additional infrastructure unless a requirement genuinely requires it.
>
> ## 3. Core Development Principle
>
> Requirements → Product decisions → Specifications → Implementation plan → Small implementation task → Tests → AI review → Human review → Commit/checkpoint → Next task. Claude must not skip directly from requirements to broad implementation. Each task needs clear scope, referenced specification, acceptance criteria, tests, and verification.
>
> ## 4. Create CLAUDE.md
>
> Root-level CLAUDE.md establishing project-wide engineering rules: product rules (one group per table, max two-table combination, atomic combined allocation, combination lifecycle, dynamic non-FIFO position, compatibility-from-current-state, smallest-suitable preference, wait-time aging, maximum-wait protection scoped to complete configurations, no individual-table reservation, PostgreSQL as source of truth, Redis never authoritative, anonymous active-visit token identity, idempotent join, phone number never the idempotency key, shared tables and fairness debt as future scope); engineering rules (small changes, no unrelated refactors, follow specs, test hard business rules, business logic out of controllers, domain/service objects, transactions for atomicity invariants, validate against spec, don't invent behavior, don't silently expand scope); AI rules (agents may inspect/plan/propose/implement-within-scope/test/review; must not change product decisions silently, invent requirements, implement future features, remove tests to pass the suite, weaken invariants, replace database correctness with cache behavior, or claim completion without verification).
>
> ## 5. Requirement Traceability
>
> Create a lightweight mechanism (simple Markdown mapping/checklist, not a complicated tracking system) so the agent can answer Requirement → Specification → Implementation → Test for requirement IDs like REQ-GUEST-001, REQ-TABLE-005, REQ-QUEUE-003, REQ-INFRA-002.
>
> ## 6. Agent Design
>
> Create four agents (not dozens): **spec-reviewer** (review specs before implementation; check requirement coverage, contradictions, missing acceptance criteria, domain invariants, implementation plans, scope creep; must NOT implement code; output format: Requirements checked / Potential issues / Missing cases / Recommended changes / Approval status). **backend-domain-agent** (implement backend domain behavior for an assigned task — Rails domain logic, queue logic, seating allocation, table state transitions, transactions, idempotency, PostgreSQL constraints/locking, backend tests; work only within assigned scope, read specs first, never implement fairness debt or shared tables, never use Redis as source of truth, add/modify tests with domain changes). **test-engineering-agent** (design/implement hard-path tests — unit/service/integration/concurrency/idempotency/atomicity/starvation; required hard paths: duplicate join, concurrent duplicate join, table double allocation, combined-table atomicity, rollback, release, dynamic position, starvation protection, incomplete combined configuration; prefer business invariants over superficial controller coverage). **code-review-agent** (review completed implementation against requirements — traceability, correctness, concurrency, transactions, security, test coverage, unnecessary complexity, scope creep; must not silently modify code during review; findings categorized BLOCKER/HIGH/MEDIUM/LOW).
>
> ## 7. Skills
>
> Create three skills: **requirement-traceability** (map Requirement → specification → code → test, usable during implementation and review). **hard-path-testing** (standardize thinking about concurrency, idempotency, atomicity, rollback, starvation, state transitions; encourage tests that prove invariants over happy paths). **rails-domain-development** (project-specific Rails guidance — service/domain boundaries, transactions, PostgreSQL locking, model validations, testing; not a generic Rails tutorial).
>
> ## 8. Commands
>
> If supported, create only useful commands: `/spec-review` (review current specs before implementation), `/test-hard-paths` (run/guide verification of hard business paths), `/requirements-check` (map current implementation against requirement IDs). Do not create commands that simply wrap trivial shell commands.
>
> ## 9. MCP Strategy
>
> Do NOT add MCP servers merely to demonstrate MCP usage. Determine genuine usefulness first. Likely useful categories: git/repository context, documentation/specification retrieval, database inspection during debugging if safe and useful. MCP must not become the source of truth for product requirements — the Markdown specifications remain authoritative. If no MCP provides meaningful benefit, document: *"No MCP was added because the available MCP capability did not provide sufficient value for this two-day project."* This is an acceptable outcome. Do not install unnecessary MCP servers.
>
> ## 10. Hooks
>
> If useful and supported, consider lightweight hooks for formatting, tests, validation, preventing accidental broad changes. Do not create slow hooks that consume substantial development time, or automatically run expensive full-system operations after every tiny change. If hooks are not necessary, document why.
>
> ## 11. Settings
>
> Create/update settings only as needed, kept minimal, not for appearance. Configuration should make the agent respect project instructions, remain scoped, use tests, avoid unnecessary modifications.
>
> ## 12. AI Working Record
>
> Update `session-log.md`, `agent-prompts.md`, `agent-decisions.md`. Record this Phase 4 session: what agents were created and why, what each is allowed/prohibited from doing, skills/commands/MCPs/hooks created and why, anything intentionally not added and why. Do NOT fabricate AI mistakes — record actual corrections only when they occur.
>
> ## 13. AI Session Boundaries
>
> Future sessions should follow bounded objectives — example: Session A project bootstrap only, B database/domain model only, C join/idempotency only, D allocation engine only, E hard-path testing, F staff APIs, G guest frontend, H staff frontend, I Redis/live updates, J Sidekiq notification, K final review. Do not force this exact sequence if the specification reveals a better one. The principle: one bounded objective per agent session.
>
> ## 14. Claude Must Stop When Scope Is Exceeded
>
> If an agent discovers an architectural contradiction, a missing product decision, a security issue requiring a new product decision, or an ambiguity affecting correctness, it should NOT invent the answer — report `BLOCKED — HUMAN DECISION REQUIRED` with issue, affected requirement, possible options, recommendation, trade-off.
>
> ## 15. Important Domain Invariants
>
> Treat as non-negotiable: table invariant (one group per table), release invariant (combined assignment released as a complete unit), atomicity invariant (combined seating all-or-nothing), idempotency invariant (retry never creates another entry), source-of-truth invariant (PostgreSQL determines actual table state), compatibility invariant (a group only assigned a configuration that can seat it), starvation invariant (protected group gets priority when its complete configuration is available), no-reservation invariant (incomplete configuration never reserves an individual table indefinitely), scope invariant (future features not introduced into P0).
>
> ## 16. No Implementation In This Phase
>
> After creating the configuration, stop. Do not run generators, create models/migrations/controllers/React components/Redis code/Sidekiq jobs, or implement authentication/APIs. The next phase will explicitly authorize implementation.
>
> ## 17. Final Output
>
> Report: configuration created (CLAUDE.md, agents, skills, commands, hooks, settings, MCP configuration), and for each item its purpose, why it exists, what it's allowed to do, what it cannot do; deliberately-not-added items and why; the intended AI workflow for future sessions; remaining risks; and explicit confirmation that no application implementation was performed during Phase 4.

---

---

## Prompt 5 — Phase 5A: Environment Inspection + Runnable Bootstrap

**Source file:** `restaurant_waitlist_phase5A_bootstrap_prompt.md` (candidate-authored, read from `~/Downloads/`, in a new session — the first implementation session, corresponding to "Session A" in `session-plan.md`).

**Session context:** First authorization to write actual code. Bounded to the smallest runnable foundation (Docker Compose bringing up a React+TS frontend, a Rails API backend, and PostgreSQL, with a `/health` endpoint) — explicitly no business functionality (no queue/table/seating models, no auth, no guest/staff APIs).

**Full text:**

> # Claude Prompt — Phase 5A: Environment Inspection + Runnable Bootstrap
>
> ## Goal
>
> Start implementation by creating the smallest runnable project foundation. This is a **bounded bootstrap task**. The objective is to reach this checkpoint: Docker Compose running a React + TypeScript frontend, a Rails API backend, and PostgreSQL. Do not implement business functionality yet.
>
> ## 1. Read Before Acting
>
> Read CLAUDE.md and documents/01-requirements, 02-product-decisions, 03-architecture, 05-specifications before making changes. Follow the approved architecture and scope. If a contradiction affecting implementation is found, stop and report it instead of silently changing a product decision.
>
> ## 2. Inspect the Environment First
>
> Check Docker, Docker Compose, Ruby, Rails, Node.js, npm, package manager, Git. Report what's installed, versions, what's missing, what can be provided through Docker. Do NOT install or upgrade global software automatically, modify unrelated system configuration, install PostgreSQL/Redis globally, or install Rails globally unless explicitly required and approved. Prefer project-local/containerized dependencies. If Docker Desktop is unavailable, report that clearly and explain the minimum manual prerequisite.
>
> ## 3. Approved Stack
>
> React + TypeScript / Ruby on Rails API / PostgreSQL / Docker Compose. Do NOT add yet: Redis, Sidekiq, Kafka, RabbitMQ, WebSockets, external notification providers — considered after the P0 core is working.
>
> ## 4. Project Structure
>
> `restaurant-waitlist/{backend/, frontend/, documents/, docker-compose.yml, CLAUDE.md, README.md}`. Do not move/delete existing documentation or duplicate it unnecessarily.
>
> ## 5. Backend Bootstrap
>
> Minimal Rails API-mode app: PostgreSQL adapter, Docker-Compose-suitable env config, dev/test config, minimal `GET /health` returning `{"status": "ok"}`. Do NOT create queue/table models, seating services, authentication, guest/staff APIs, allocation logic, idempotency logic, Redis code, or Sidekiq code.
>
> ## 6. Frontend Bootstrap
>
> Minimal React + TypeScript SPA: minimal dev server, backend-URL env config, a simple page proving the frontend is running and (if practical) showing backend health-check status. Do NOT implement guest join form, staff dashboard, queue UI, seating UI, auth UI, or allocation UI.
>
> ## 7. PostgreSQL
>
> Add to Docker Compose with a persistent dev volume, env vars, db/user/password config, and backend connectivity. No business migrations yet — a Rails default migration/setup solely for bootstrapping is fine.
>
> ## 8. Docker Compose
>
> `docker compose up` should start frontend, backend, postgres. Expose sensible dev ports. Avoid hardcoding secrets unsafe to commit; documented dev-only credentials are acceptable.
>
> ## 9. Verification
>
> Actually run the project. Verify `docker compose config` succeeds; PostgreSQL container starts and accepts connections; Rails container starts and `GET /health` returns 200; React frontend starts and is accessible; if practical, frontend can call the Rails health endpoint.
>
> ## 10. Testing
>
> No business tests yet. A minimal health-endpoint test is acceptable if straightforward.
>
> ## 11. Documentation While Implementing
>
> Not stopping documentation, but no large new design documents — update only the AI working record (this prompt in `agent-prompts.md`, this session in `session-log.md`, important environment/setup decisions in `agent-decisions.md`). Update the relevant architecture document only for an important architectural discovery. Do NOT fabricate AI corrections; record a real mistake in `ai-corrections.md` only if one occurs.
>
> ## 12. Scope Boundary
>
> Ends when React/Rails/PostgreSQL/Docker/health-check are all working. Do not continue into domain implementation even if bootstrap succeeds — the next task separately implements the persisted domain model.
>
> ## 13. Final Report
>
> Report: environment (installed tools, versions, missing tools, whether Docker was sufficient); files created/changed; verification (commands run and results — Docker Compose status, Rails health endpoint, React availability, PostgreSQL connectivity); problems encountered and how resolved; which AI working-record files were updated; and an explicit phase-boundary confirmation that no queue/seating/allocation/auth/Redis/Sidekiq/other business functionality was implemented. STOP after this checkpoint.

---

## Prompt 6 — Mid-session stop instruction (Phase 5A)

**Source:** typed directly in the Phase 5A session (not a separate file), after environment inspection surfaced a real blocker.

**Full text:**

> STOP at the current Phase 5A environment setup checkpoint. Do not run any more installation commands. Do not modify the project further. Before stopping, ensure all important work is saved to disk. Report: 1. What has been completed. 2. What failed. 3. What remains to be done. 4. The exact next command/action required after the macOS administrator permission issue is resolved. Update the AI working record with this session state if appropriate. Then stop and wait.

**Context this responds to:** environment inspection (Prompt 5 §2) found no Docker/container runtime, no Node.js, and only a very old system Ruby (2.6.10, no Rails) on this machine. Per Prompt 5's explicit "do not install global software automatically" boundary and this session's own operating guidance around impactful system changes, the candidate was asked (via a clarifying question, not a silent choice) how to proceed; they chose installing Colima + Docker CLI via Homebrew. That install then failed because this machine's pre-existing Homebrew installation has broken `/usr/local` permissions, requiring a `sudo chown` only the candidate can run (needs their password). Rather than let the agent attempt further workarounds, the candidate issued this stop instruction to checkpoint state cleanly before resolving the OS-level permission issue themselves.

---

---

## Prompt 7 — Phase 5A: Resume Bootstrap After macOS Permission Fix

**Source file:** `restaurant_waitlist_phase5A_resume_bootstrap_prompt.md` (candidate-authored, read from `~/Downloads/`, in a new session, after the candidate resolved the Homebrew permission issue that had blocked Session 4).

**Session context:** Explicit resume instruction after an environment blocker was cleared. Required inspecting existing state first (not restarting the project), re-verifying the environment, and only then continuing the same bounded bootstrap objective from Prompt 5.

**Full text:**

> # Phase 5A — Resume Bootstrap After macOS Permission Fix
>
> ## Current Phase
>
> **Phase 5A — Environment + Runnable Bootstrap.** The previous Phase 5A session was intentionally stopped because the `vikas` macOS account did not have administrator/sudo access and the existing Homebrew installation under `/usr/local` had ownership/permission issues. The administrator permission issue has now been resolved. Resume from the existing project state.
>
> ## 1. Do Not Restart the Project
>
> Before doing anything: inspect the current project, current Git status, existing files, the AI working record, and the current environment. Do NOT recreate the project, overwrite existing documentation, redo existing Phase 4 work, or start a new unrelated project.
>
> ## 2. Environment Verification
>
> Verify `whoami`, `brew --prefix`, `docker --version`, `docker compose version`, `colima version`, `ruby --version`, `rails --version`, `node --version`, `npm --version`, `git --version`, and whether the Homebrew paths required for installation are now writable. If Docker/Colima are missing, install the minimum required tooling (preferred: Colima + Docker CLI + Docker Compose) using the now-working Homebrew installation. Do not install unnecessary software; do not install PostgreSQL/Redis globally if Docker can provide them. If an installation requires an interactive administrator password, stop and ask the human rather than attempting to bypass it.
>
> ## 3. Approved Stack
>
> React + TypeScript / Ruby on Rails API / PostgreSQL / Docker Compose, exactly, for this checkpoint. Redis and Sidekiq are NOT part of this checkpoint.
>
> ## 4. Phase 5A Objective
>
> Get `docker compose up` starting a React+TS frontend, Rails API backend, and PostgreSQL successfully.
>
> ## 5. Backend Bootstrap
>
> Create or complete the minimal Rails API app: API mode, PostgreSQL connection, Docker-compatible config, dev/test config, minimal `GET /health` → 200 `{"status":"ok"}`. Do NOT implement queue/table/seating models, allocation service, guest/staff APIs, authentication, idempotency, or starvation logic.
>
> ## 6. Frontend Bootstrap
>
> Create or complete the React+TS SPA: dev server, backend URL config, a simple status page showing "Frontend: running" / "Backend: connected", calling `GET /health` if practical. Do NOT implement guest join form, queue screen, staff dashboard, seating controls, or auth UI.
>
> ## 7. PostgreSQL
>
> Add to Docker Compose: dev database, persistent volume, backend connectivity, env config. No business schema yet — only whatever minimal Rails database setup proves the app can connect.
>
> ## 8. Docker Compose
>
> Create or complete `docker-compose.yml` so `docker compose up` starts frontend, backend, postgres, with sensible dev ports. Do not add Redis, Sidekiq, Kafka, RabbitMQ, or external notification providers yet.
>
> ## 9. Verification
>
> Actually run and verify: `docker compose config` succeeds; all three services report running; `GET /health` → 200; Rails can connect to PostgreSQL; the React app is accessible in a browser; if practical, frontend can call `/health`. Do not claim success without actually verifying it.
>
> ## 10. Troubleshooting Rule
>
> If something fails: inspect the actual error, identify the root cause, make the smallest necessary correction, rerun the relevant verification. Do not repeatedly retry the same failing command, install unrelated packages, change the approved architecture, modify unrelated project files, or bypass permission/security controls. If the problem requires a human administrator action, stop and report it.
>
> ## 11. AI Working Record
>
> Implementing and documenting in parallel. Add this prompt to `agent-prompts.md`; record this continuation in `session-log.md`; record important environment/setup decisions in `agent-decisions.md`; record a real AI mistake in `ai-corrections.md` only if one occurs — do NOT fabricate. Do not create another large architecture document.
>
> ## 12. Git Checkpoint
>
> If the bootstrap is successfully verified, inspect `git status`. Do not create a commit unless the project workflow already expects Claude to commit. If committing is part of the existing workflow, use a focused commit such as `chore: bootstrap runnable application` — do not mix unrelated changes into the checkpoint.
>
> ## 13. Strict Phase Boundary
>
> STOP once Docker/Colima, Docker Compose, React+TS, Rails API, PostgreSQL, `/health`, and frontend-reachable are all OK. Do NOT proceed to Phase 5B (Domain Model + Migrations + Seed Data) in this session.
>
> ## 14. Final Report
>
> Report: environment (user, Docker/Compose/Colima/Ruby/Rails/Node/npm versions); files created/modified; verification results (compose config, containers, PostgreSQL, `/health`, React, frontend→backend connectivity); problems encountered and how resolved; AI working-record files updated; and an explicit phase-status statement — either "Phase 5A bootstrap is complete and verified" or "Phase 5A remains blocked because: <exact reason>." Do not proceed to Phase 5B in this session.

**Mid-session exchange (not a separate governing document):** environment verification in this session found a second, smaller round of the same `/usr/local` permission problem (a subset of paths still owned by another user), and then a genuinely new blocker once permissions were fully fixed: this Mac is Apple Silicon (arm64) but its only Homebrew was the Intel build running under Rosetta, and Colima's Lima VM refuses to start under a non-native binary. Both were surfaced to the candidate rather than worked around — see `session-log.md` Session 5 for the full sequence, including the candidate's choice to install a second, native Homebrew at `/opt/homebrew` and start Colima with `colima start --arch aarch64` themselves.

---

## Prompt 8 — Phase 5A.1: Bootstrap Cleanup + Git Checkpoint

**Source file:** `restaurant_waitlist_phase5A1_git_checkpoint_prompt.md` (candidate-authored, read from `~/Downloads/`, in a new session immediately after Phase 5A's completion).

**Session context:** A small, explicitly-scoped cleanup task before Phase 5B — correct stale "no application code exists yet" language left over from before the bootstrap, and establish the first git checkpoint (the project had no repository at all until this session).

**Full text:**

> # Phase 5A.1 — Bootstrap Cleanup + Git Checkpoint
>
> Phase 5A is complete — the runnable foundation (React+TS frontend, Rails API backend, PostgreSQL, Docker Compose, `/health`, frontend→backend health verification) has been created and verified. This task is a small cleanup/checkpoint before Phase 5B.
>
> **1. Read current state first:** `CLAUDE.md`, `README.md`, `documents/06-ai-working-record/`, `docker-compose.yml`, `backend/`, `frontend/`, plus `git status` and `git log --oneline --max-count=5`. Do not recreate the project, redo Phase 5A, or start Phase 5B.
>
> **2. Update CLAUDE.md:** correct only the stale project-status/bootstrap sections to state Phase 5A bootstrap is complete, a runnable React+Rails+PostgreSQL foundation exists, Docker Compose is operational, `/health` is available, and domain/business implementation has NOT started. Keep all existing engineering rules and product decisions intact — do not weaken or rewrite the approved domain rules.
>
> **3. Update README.md:** must no longer say "No application code has been written yet" or imply the bootstrap hasn't happened. Include a concise "Current implementation status" section (implemented: React/Rails/PostgreSQL/Docker Compose/health endpoint/connectivity check; not yet implemented: queue domain, guest join, guest identity, idempotency, table allocation, starvation protection, staff operations, Redis, Sidekiq). Do not rewrite the whole README unnecessarily or invent completed functionality.
>
> **4. Verify AI working record:** ensure the Phase 5A session record actually contains the environment issue, the Intel-vs-ARM64 Homebrew issue, the Colima architecture resolution, final Docker verification, and the bootstrap result. Do not fabricate anything; if already present, do not duplicate — add only a concise checkpoint entry if necessary.
>
> **5. Requirement traceability:** do NOT create business requirement mappings yet (Phase 5B does that) — only record that Phase 5A = infrastructure/bootstrap and no business requirements have been implemented yet.
>
> **6. Git setup:** the AI working record must be committed alongside the code. Check whether a top-level git repository already exists; if not, `git init`. Create/verify a root-level `.gitignore` excluding `.env`/`.env.*`, `.DS_Store`, `node_modules/`, `coverage/`, `log/`, `tmp/`, `vendor/bundle/` — but must NOT ignore `documents/`, `CLAUDE.md`, `.claude/`, `README.md`, `docker-compose.yml`.
>
> **7. Inspect before commit:** run `git status`, review what will be committed. Do not commit secrets, passwords, private credentials, generated personal machine configuration, or unnecessary large files.
>
> **8. First git checkpoint:** if this is a new repository, create the first commit: `chore: bootstrap runnable application`, containing the runnable application + AI working record + CLAUDE.md + Claude agents/skills/commands/config + README + Docker Compose. If a repository already exists and Phase 5A is already committed, do not duplicate the commit.
>
> **9. Scope boundary:** do NOT create any Phase 5B business functionality — no `QueueEntry`/`Table`/`SeatingAssignment`/`IdempotencyRecord` models, no restaurant table seed data, no allocation/queue service, no guest/staff APIs, no authentication, no Redis, no Sidekiq, no starvation logic. This task is only cleanup + checkpoint.
>
> **10. AI working record:** record this session concisely in `agent-prompts.md`, `session-log.md`, `agent-decisions.md`. Do not create an AI correction unless a real mistake occurs.
>
> **11. Verification:** after cleanup, verify the Phase 5A application still works — at minimum `docker compose config`, and if practical `docker compose up` confirming PostgreSQL/Rails/`/health`/frontend. Do not make unrelated fixes.
>
> **12. Final report:** documentation files updated and stale statements corrected; git status (existed already? initialized? commit hash and message?); verification results; AI working-record files updated; explicit scope confirmation: "Phase 5A.1 is complete. No Phase 5B business functionality was implemented." Then STOP — next authorized task is Phase 5B (Domain Model + Migrations + Seed Data), not begun in this session.

---

## How these prompts were used

- Prompt 1 produced the independent analysis in `../01-requirements/` (originally delivered as an in-conversation analysis; formalized into the requirements documents during the Prompt 2 session).
- Prompt 2 supplied the already-approved decisions that populate `../02-product-decisions/decision-log.md`, `seating-allocation-policy.md`, and `starvation-policy.md` verbatim in substance — the agent's job was to specify and document them, not originate them.
- Prompt 3 supplied specific, human-identified corrections to Session 1's output (see `ai-corrections.md` CORR-001 through CORR-003) plus a candidate-proposed technology stack for the agent to evaluate — not originate — and approve or challenge (`../02-product-decisions/decision-log.md` DEC-012).
- Prompt 4 authorized building the AI-native development environment itself (`CLAUDE.md`, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.claude/settings.json`) around the now-frozen specification, while explicitly delegating several configuration-only judgment calls (MCP, hooks) to the agent — see `agent-decisions.md` "Session 3" for how each was resolved and why.
- Prompt 5 was the first implementation-authorizing prompt (Session A bootstrap); it was interrupted by Prompt 6, a real-time human stop instruction, before the checkpoint could be reached — see `session-log.md` Session 4 for the full account of what was completed vs. blocked.
- Prompt 7 resumed that same bootstrap objective after the candidate fixed the environment blockers themselves, and the checkpoint was reached and verified in that session — see `session-log.md` Session 5.
- Prompt 8 (below) was a small cleanup/checkpoint task — correcting stale post-bootstrap documentation and creating the first git commit — explicitly not Phase 5B.
- A structural-reference project (`mentoring-session-booking-main`) was present in the same Downloads folder; per Prompt 2 §14, only its top-level documentation organization (a `docs/` folder with `ARCHITECTURE.md`, `DECISION_LOG.md`, `DIAGRAMS.md`, plus a `.kiro/specs`/`.kiro/steering` spec-driven layout) was glanced at for structural awareness. No content, decisions, or implementation from that project were copied — this project's own documentation structure follows Prompt 2 §11's explicit spec instead. That same reference project's backend (Rails API + PostgreSQL + Docker Compose) also informed the Prompt 3 stack evaluation (`decision-log.md` DEC-012) as evidence of the candidate's working familiarity with the proposed stack.
