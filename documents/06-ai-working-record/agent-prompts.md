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

## Prompt 9 — Phase 5B.1: Domain Model Proposal and Review

**Source:** pasted directly into the session (candidate initially sent a truncated copy that cut off mid-section-3; the agent flagged this explicitly rather than guessing at the rest, and the candidate re-sent the complete text in the next turn).

**Session context:** First Phase 5B task. Explicitly specification/analysis only — no migrations, models, controllers, services, seeds, or tests. The deliverable is a reviewed domain model proposal to inform Phase 5B.2 implementation, not implementation itself.

**Full text (condensed; all 22 sections' substantive content preserved):**

> # Phase 5B.1 — Domain Model Proposal and Review
>
> Phase 5A/5A.1 are complete (runnable foundation, AI working record, git checkpoint). This phase is SPECIFICATION/ANALYSIS ONLY — do not write application code, migrations, models, seeds, controllers, services, or tests.
>
> **1. Objective:** design the minimum persisted domain model required to correctly implement the assignment, using the existing requirements analysis, product decisions, architecture, specifications, CLAUDE.md, and AI working record. Do not invent unnecessary requirements. Goal: a thin but correct model supporting later phases.
>
> **2. Critical business requirements to model:** guest joins with group size + phone number, no account/login, guest can reopen the page and find the same active entry, guest can leave, guest receives a code when ready to be seated. Idempotent join — a retry must never create another entry; must not assume phone number alone is an idempotency key.
>
> **3. Queue Entry State:** propose the minimum lifecycle needed for `waiting / ready / seated / left / no_show`. If a different state model is better, explain why. Define valid transitions. Do not automatically accept the example state machine without validating it against requirements.
>
> **4. Table Model:** ~40 tables, seed data. Must support table identifier, capacity, availability/occupancy, adjacency, temporary combination, one group per table, a table not assignable while occupied, combined tables behaving as one unit, combined tables becoming independently available after release. Determine whether combination should be a separate persisted seating/combination entity, an assignment entity, or another approach — choose the simplest model preserving the invariants and explain the decision.
>
> **5. Large Groups:** MVP max combination = 2 adjacent tables; do NOT build arbitrary N-table combination unless the spec clearly requires it. Document MVP vs. future (N-table combinations if requirements expand) and explain why 2-table is the appropriate two-day scope decision.
>
> **6. Seating Assignment:** must support one group → one table, or one group → two adjacent tables, in a way that lets later implementation guarantee "both tables are taken atomically, or neither is taken." Do NOT implement the allocation algorithm — only determine the persistence structure needed for it to enforce the invariant later.
>
> **7. Queue Position:** do NOT store a simple permanent position counter — seating is not FIFO; position depends on group size, currently available tables, compatible capacity, adjacency, and the fairness policy. Explain what must be persisted so a later service can calculate position dynamically.
>
> **8. Starvation/Fairness:** selected approach is Compatibility-aware weighted aging with a maximum waiting-time safeguard — do NOT implement the algorithm. Preserve the data needed for it (arrival timestamp, group size, status, readiness, relevant timestamps). Do NOT add unnecessary precomputed "weight" columns unless proven required — the weight should preferably be derived by the allocation/position service. Explain the decision.
>
> **9. Guest Identity:** anonymous identity needed because guest scans a shared QR code, joins, closes the browser, scans again, and must still see their active position. Preferred MVP direction: opaque random guest token, stored on the client, associated with the active queue entry. Explain what's persisted, what's stored in the browser, how it's scoped, when it becomes invalid, and how a future visit creates a new identity/entry. Do not use phone number as the guest authentication mechanism.
>
> **10. Idempotency:** propose how the database enforces "same join request → same queue entry → never duplicate," supporting a database-level uniqueness guarantee. Explain what makes a key unique, its lifecycle, what happens on retry, and how a new visit creates a new entry. Do not implement the endpoint.
>
> **11. Database Constraints:** identify important DB-level invariants — valid group size, valid table capacity, unique idempotency key, unique guest token where appropriate, one active seating assignment per group, one active occupant per table, valid status values, valid table combination relationships. Do not add constraints merely because they sound good — explain why each protects a requirement.
>
> **12. Indexes:** propose only indexes with a clear reason, considering: find active queue entries, find guest's active queue entry, find available tables, find tables by capacity, find adjacent tables, find seating assignment, resolve idempotency retry. For each, state the query it supports and why it matters. Do not optimize prematurely.
>
> **13. Seed Data:** propose the seed structure for ~40 tables, deterministic, realistic capacities (mostly 2-seat, mostly 4-seat, one or two larger tables). The distribution must be a deliberate decision aligned with the allocation algorithm. Define deterministic adjacency relationships. Do NOT create the seed code yet.
>
> **14. Model Alternatives:** compare, at minimum: Seating representation (table directly references queue group / separate seating assignment entity / another design); Combination representation (table pair relationship / seating unit-assignment representation / another design); Guest identity (phone number / opaque guest token / queue-entry token). Explain the selected MVP design. Prefer simplicity, correctness, and testability over theoretical flexibility.
>
> **15. Requirement Traceability:** map Requirement → Domain concept → Database field/constraint → Later service responsible, covering at least: idempotent join, anonymous guest recovery, one group per table, atomic two-table seating, table release, non-FIFO position, starvation protection, no-show, guest leave.
>
> **16. Proposed Domain Model:** produce a clear textual ERD. Do NOT assume the example given (`GuestIdentity → QueueEntry → SeatingAssignment → Table`) is correct — create the ERD from your own analysis. For each entity: purpose, fields, relationships, important constraints.
>
> **17. State Machines:** two text state diagrams — Queue Entry (valid states, valid transitions, invalid transitions) and Table/Seating (free, occupied, combined, released/split), explaining how combined tables return to independent availability.
>
> **18. Concurrency Considerations:** do not implement — identify which invariants later require transactions, row locking, unique constraints, or optimistic locking. Analyze specifically: two guests joining concurrently; two seating operations concurrently; two adjacent tables targeted by different groups; a table released while another seating operation starts; a retry of the same join arriving concurrently. Explain how the eventual implementation protects each case.
>
> **19. What We Are Deliberately NOT Modeling Yet:** explicitly list and explain why each is deferred — Redis cache, Sidekiq/background jobs, notification provider, rate limiting, detailed staff authentication, table-management UI, arbitrary N-table combinations, table-sharing preferences, advanced restaurant overrides, analytics/reporting.
>
> **20. AI Working Record:** add this prompt to `agent-prompts.md`; record the session in `session-log.md`; record important domain decisions in `agent-decisions.md`; create/update the appropriate specification artifact under the existing documentation structure. Do NOT fabricate AI mistakes. If the agent identifies an ambiguity or changes a previous assumption, record it.
>
> **21. Strict No-Code Rule:** do NOT create migrations, modify Rails models, create controllers/services/seed code, modify frontend, modify Docker, implement APIs, or write business tests. The output of this phase is the reviewed domain model proposal and its documentation.
>
> **22. Final Output:** provide — selected domain model summary; entity list; relationships; constraints; indexes; state machines; concurrency plan; seed data plan; deferred scope; requirement traceability; open decisions (only ones genuinely requiring human/product judgment); and phase status ending with: "Phase 5B.1 analysis/specification is complete. No application/domain code was implemented. Waiting for human review before Phase 5B.2 implementation." STOP.

---

## Prompt 10 — Human review feedback on the domain model proposal

**Source:** typed directly in the session, immediately following Prompt 9's Final Output.

**Full text:**

> The agent proposed the domain model. I reviewed it and caught that its proposed partial unique index could not reference the parent assignment status in PostgreSQL. I also identified that a READY reservation could hold tables indefinitely, so I introduced an expiration policy before implementation.

**How the agent responded:** confirmed the technical finding was correct (PostgreSQL partial-index predicates cannot reference another table's column), fixed `domain-model-proposal.md` throughout with a corrected design (at that point: remove the denormalized `status` column, delete claim rows on release), and recorded the mistake honestly as CORR-004 in `ai-corrections.md`. For the expiration policy, rather than inventing the specifics (duration, what happens on expiry, sweep mechanism), the agent asked three clarifying questions.

---

## Prompt 11 — Locked expiration decisions and finalization (received in two parts)

**Source:** typed directly in the session. The candidate's first message attempting to answer the clarifying questions was cut off mid-paste (ended mid "Decision 1," no closing sections) — the agent checked `~/Downloads/` for a matching file, found none, and asked the candidate to resend rather than acting on an incomplete instruction set (matching the same protocol used earlier in Session 7 for a similarly truncated paste). The candidate then sent the complete version.

**Full text (complete version):**

> # Continue Phase 5B.1 — Complete the Finalization
>
> The previous Phase 5B.1 prompt was accidentally truncated while being pasted. It ended during Decision 1. Do NOT make any changes based on the incomplete prompt yet. Continue from the following locked decisions:
>
> ## Locked READY Expiration Policy
>
> **1. Expiration outcome:** `WAITING → READY → (5-minute timeout) → NO_SHOW → reserved tables released atomically`. Do NOT use `READY → WAITING` for the MVP.
>
> **2. Expiration evaluation:** lazy evaluation. Do NOT introduce Sidekiq, a scheduler, or a background sweep for READY expiration. Evaluate overdue READY reservations during relevant operations — guest position/read, staff queue/table view, guest join, allocation/availability calculation, seating-related operations. Before an allocation decision is made, stale READY reservations affecting the relevant tables must be expired and their tables released.
>
> **3. Expiration duration:** READY timeout = 5 minutes. Tunable configuration value, not deeply hard-coded into business logic.
>
> **4. Trade-off (to document verbatim):**
> > A READY reservation expires after 5 minutes and becomes NO_SHOW if staff has not confirmed the seating code. This prevents tables from being held indefinitely and keeps the MVP state machine simple. Lazy expiration avoids introducing scheduler/background-job infrastructure solely for this timeout. The trade-off is that a guest may lose their place if the delay was caused by staff rather than the guest. A future version could distinguish guest timeout from staff-caused expiration and return the guest to WAITING while preserving the original waiting timestamp.
>
> ## Important technical correction
>
> Review the previously proposed constraint: "partial unique on seating_assignment_tables.table_id WHERE status IN (pending, active)." Do NOT implement this literally if `status` belongs to the parent `seating_assignments` table — PostgreSQL partial indexes cannot reference a column from another table. Design a technically valid database-level invariant. Evaluate a structure such as `seating_assignment_tables(id, seating_assignment_id, table_id, released_at)` with `UNIQUE(table_id) WHERE released_at IS NULL`, or another technically correct equivalent. Validate the design against: pending assignments; active assignments; release; expiration; historical assignments; atomic two-table seating.
>
> ## Other already-approved decisions (retain unless a correctness issue is found)
>
> Entities: `StaffUser`, `Table`, `TableAdjacency`, `QueueEntry`, `SeatingAssignment`, `SeatingAssignmentTable` — do not add `GuestIdentity`, `IdempotencyRecord`, or `NotificationJob` without a demonstrated need. Queue lifecycle: `WAITING → READY → SEATED`, `WAITING → LEFT`, `WAITING → NO_SHOW`, `READY → LEFT`, `READY → NO_SHOW`, `READY → SEATED`. Table combination: max 2 tables for MVP, must be adjacent, both reserved atomically or neither, combined status derived from the seating assignment, releasing makes both independently available. Table seed: 40 tables (20×2, 18×4, 2×6), not permanently dedicated to particular group sizes. Guest identity: opaque random guest token. Idempotency: database-level unique key, phone number alone must not be the mechanism. Queue position: not persisted as a counter — calculated later from group size, available tables, compatible capacity, adjacency, compatibility-aware weighted aging, and the maximum-waiting-time safeguard. Scope: no Redis, Sidekiq, notification provider, rate limiting, detailed staff auth, table-management UI, arbitrary N-table combinations, table sharing, advanced overrides, or analytics.
>
> ## Required work
>
> Update `documents/05-specifications/domain-model-proposal.md`. Also update relevant architecture/data-model documentation where stale Phase 3 assumptions conflict with the finalized model. Update `agent-prompts.md`, `session-log.md`, `agent-decisions.md`. Record the READY expiration decisions and the PostgreSQL constraint correction honestly. Do NOT fabricate AI mistakes.
>
> ## Strict no-code rule
>
> Do NOT create or modify Rails models, migrations, controllers, services, APIs, seed code, frontend code, domain tests, Redis, or Sidekiq. This is still specification finalization.
>
> ## Final response
>
> Report: locked decisions; final domain model; database invariants; expiration policy; 40-table seed strategy; requirement traceability; open decisions; AI working-record files updated. End with: "Phase 5B.1 specification is finalized and ready for implementation. No application/domain code was implemented in this phase. Waiting for authorization to begin Phase 5B.2." STOP.

---

## Prompt 12 — Phase 5B.1.5: Specification Consistency Pass

**Source:** typed directly in the session, as a new governing document, after Phase 5B.1's finalization.

**Session context:** The Session 9 report explicitly flagged, as a known gap, that `functional-spec.md`, `allocation-spec.md`, `api-spec.md`, `test-strategy.md`, and four diagrams still described the pre-`ready` synchronous-seating model. This prompt authorized the follow-up pass to close that gap — still specification/documentation only, no code.

**Full text (condensed; all 13 sections' substantive content preserved):**

> # Phase 5B.1.5 — Specification Consistency Pass
>
> Phase 5B.1 domain-model design is finalized (`domain-model-proposal.md`, `03-architecture/domain-model.md`, `data-model.md`). The most important finalized changes: `QueueEntry` now has a `READY` state; allocation selects/reserves the table configuration *before* staff acts; `READY` displays a seating code to the guest; staff entering the code confirms the already-created reservation; `READY` expires after 5 minutes → `NO_SHOW`, evaluated lazily, no scheduler; `SeatingAssignment`+`SeatingAssignmentTable` (with `released_at`, `UNIQUE(table_id) WHERE released_at IS NULL`) replace `TableCombination`; `QueueEntry` holds `active_visit_token`/`idempotency_key` directly, no separate `GuestIdentity`/`IdempotencyRecord`; max 2-table combination; seed distribution 20×2/18×4/2×6.
>
> **Objective:** bring ALL implementation-facing specifications and diagrams into consistency with the finalized model. Still specification/documentation only — do NOT write application code.
>
> **1. Documents to audit:** everything under `01-requirements/` through `06-ai-working-record/`, focused especially on `functional-spec.md`, `allocation-spec.md`, `api-spec.md`, `test-strategy.md`, and the four diagrams identified in the Session 9 report.
>
> **2. Identify contradictions FIRST:** before modifying anything, produce a table (Document | Old assumption | Finalized assumption | Action). Do not silently modify documents before this. Named contradiction categories to check specifically: the READY lifecycle (`waiting → seated` vs. `waiting → ready → seated`); staff seat-by-code (allocating at code-entry time vs. allocation-already-happened, staff-only-confirms); table representation (`TableCombination`/`Table.status` vs. `SeatingAssignment`+`SeatingAssignmentTable`, derived availability); idempotency (`IdempotencyRecord` table vs. `QueueEntry.idempotency_key` column); guest identity (`GuestIdentity`/`ActiveVisitToken` entity vs. `QueueEntry.active_visit_token` column); table exclusivity (`SeatingAssignmentTable.released_at` with `UNIQUE(table_id) WHERE released_at IS NULL`); READY expiration (5 min → `NO_SHOW` → atomic release, lazy, no scheduler).
>
> **3. Update `functional-spec.md`:** guest join creates `QueueEntry = waiting` and returns the token, does not claim immediate allocation. Guest position: dynamic; if `READY`, return `status: ready` + `seating_code`. Staff seat by code: resolve code → confirm entry is `READY` → confirm the `SeatingAssignment` is still valid/not expired → transition assignment to `active` and entry to `seated`, atomically. Staff must NOT perform the original allocation decision. Document the 5-minute timeout, lazy evaluation, automatic `NO_SHOW`, atomic release.
>
> **4. Update `allocation-spec.md`:** the allocation service finds waiting groups, finds compatible available configurations, applies aging + the 20-minute starvation safeguard, selects the group/configuration, atomically creates `SeatingAssignment`+`SeatingAssignmentTable` rows, moves the entry `waiting → ready`, generates the seating code — it does NOT move the group to `seated`; staff confirmation does that. Update any references to `Table.status`, `TableCombination`, old idempotency/guest-identity entities that conflict with the finalized model.
>
> **5. Update `api-spec.md`:** staff seat endpoint accepts a code belonging to a `READY` entry, not `WAITING`. Guest current-position response supports `waiting`/`ready`/`seated`/`left`/`no_show`; for `ready`, include the seating code. Document conflict behavior for expired code, already-released reservation, already-used code, entry not `READY`. Do not invent new APIs unless required by the existing assignment.
>
> **6. Update `test-strategy.md`:** add/modify hard-path tests for the `READY` transition, staff confirmation, invalid code, `READY` expiration, lazy expiration not permanently blocking tables, concurrent allocation, combined assignment atomicity, idempotency under concurrency. Do not write the tests yet — only the specification.
>
> **7. Update diagrams:** everywhere involving guest join, guest lifecycle, seating flow, combined-table allocation, staff seat-by-code, queue state machine, table state/assignment. Do not redraw unrelated diagrams. Diagrams must consistently show `waiting → allocation → ready → staff confirmation → seated` and `ready → (timeout) → no_show → release`.
>
> **8. Preserve historical decision records:** do NOT delete the fact that the previous model existed. The AI working record should preserve what the previous proposal was, why `READY` was introduced, why `TableCombination`/`IdempotencyRecord`/`GuestIdentity` were replaced/removed, why the PostgreSQL constraint was corrected. Final specifications should be clean and implementation-ready; the AI working record should preserve the evolution.
>
> **9. Requirement traceability:** after updating, verify every must-have requirement still maps to a specification — explicitly verify REQ-GUEST-001 through 005, REQ-STAFF-004/005/006, REQ-TABLE-002/005, REQ-QUEUE-001/002/003, REQ-INFRA-001/002. Do not change requirements to fit the implementation. If a requirement genuinely conflicts with the finalized model, STOP and report it.
>
> **10. No-code rule:** no migrations, Rails models, controllers, services, APIs, seeds, frontend changes, Redis, or Sidekiq.
>
> **11. AI working record:** record as a separate session in `agent-prompts.md`, `session-log.md`, `agent-decisions.md`. Record that the consistency pass was required because the finalized domain model superseded earlier Phase 3 assumptions. Do not fabricate mistakes.
>
> **12. Final verification:** search for stale references to `TableCombination`, `IdempotencyRecord`, `GuestIdentity`, `idempotency_records`, `Table.status` as authoritative occupancy, `waiting → seated` direct, staff-allocates-a-waiting-group-directly. For each remaining occurrence, classify as (1) historical documentation that should remain, (2) future/deferred documentation, or (3) an actual contradiction that must be fixed. Do not blindly replace historical AI-working-record references.
>
> **13. Final report:** contradictions found; documents updated; documents intentionally unchanged (and why); final lifecycle diagram; final allocation → ready → confirmation flow; final table representation (`SeatingAssignment`+`SeatingAssignmentTable`+`released_at`); final expiration flow; remaining open decisions; verification confirmation; end with "Phase 5B.1.5 specification consistency pass is complete. No application/domain code was implemented. The specifications are ready for human review before Phase 5B.2." STOP.

---

## Prompt 13 — Phase 5B.2: Domain Persistence Implementation

**Source:** `Phase_5B_2_Prompt.md` (candidate-authored, read from `~/Downloads/`). A first attempt to paste this prompt directly into the session was truncated mid-§19 "Migration Safety" — the agent flagged it and did not act on the incomplete version (per the same protocol used for two earlier truncated pastes in this project); the candidate then supplied the complete file.

**Session context:** the first prompt in the project explicitly authorizing application code. Scoped tightly to the persistence foundation only — migrations, models, constraints, seed data, and domain tests — explicitly excluding APIs, the allocation algorithm, staff confirmation, and all infrastructure (Redis/Sidekiq/frontend).

**Full text (condensed; all 44 sections' substantive content preserved):**

> # Phase 5B.2 — Domain Persistence Implementation
>
> STATUS: IMPLEMENTATION AUTHORIZED. Phase 5A/5A.1/5B.1/5B.1.5 complete; human review approved the finalized domain model. Authorized: **Phase 5B.2 — Domain Persistence + Migrations + Seed Data + Domain Tests** — the first real backend/domain implementation phase.
>
> **§0 Human-driven development rule:** do not reinterpret approved product decisions — no silently changing business rules, introducing new product behavior, expanding scope, replacing approved domain decisions, or implementing future phases. A genuine contradiction between approved specs and technical reality → STOP and report before changing business design. A pure implementation detail → choose the simplest correct implementation and document it.
>
> **§1 Read first:** `CLAUDE.md`, all of `documents/`, `backend/`, `frontend/`, `docker-compose.yml`; specifically `domain-model-proposal.md`, `domain-model.md`, `data-model.md`, `functional-spec.md`, `allocation-spec.md`, `api-spec.md`, `test-strategy.md`. Understand the existing Rails project structure before creating files.
>
> **§2 Implementation checklist** (produce before writing code): the six entities; migrations; DB constraints; indexes; associations; validations; token generation; idempotency uniqueness; seating-code persistence; READY expiration fields; table exclusivity; deterministic seed + adjacency seed; domain tests; clean-DB verification; documentation; AI working record; git checkpoint. Do not start Phase 5B.3 after completing this checklist.
>
> **§3 Final domain model:** exactly `StaffUser`, `Table`, `TableAdjacency`, `QueueEntry`, `SeatingAssignment`, `SeatingAssignmentTable`. Do NOT introduce `GuestIdentity`, `IdempotencyRecord`, `NotificationJob`, `TableCombination` unless a genuine technical blocker is discovered — if so, STOP and report before introducing a new entity.
>
> **§4 StaffUser:** persist email + securely-hashed password credential, unique email; seed a demo account only if the existing spec expects one. Do NOT implement login API, sessions, JWT, roles, or UI — later phase.
>
> **§5 Table:** id, stable identifier (`T01`...`T40`), capacity, timestamps; `capacity > 0`. Do NOT create authoritative mutable fields (`occupied`/`available`/`combined`/`current_group_id`) — occupancy is derived through `Table → SeatingAssignmentTable → SeatingAssignment`.
>
> **§6 TableAdjacency:** no self adjacency, no duplicate pair, deterministic seed, symmetric semantics, FKs to Table, appropriate uniqueness. Ensure reverse duplicates cannot represent a second logical relationship — prefer a canonical pair representation if simpler and spec-consistent.
>
> **§7 QueueEntry:** `group_size`, `phone`, `active_visit_token`, `idempotency_key`, `status`, `joined_at`, `ready_at`, timestamps. Statuses `waiting/ready/seated/left/no_show`. Approved transitions: `waiting→ready`, `waiting→left`, `waiting→no_show`, `ready→seated`, `ready→left`, `ready→no_show`, `seated→left`. No APIs or allocation yet.
>
> **§8 Group size:** `> 0`; no invented maximum.
>
> **§9 Anonymous guest token:** opaque, unpredictable, cryptographically strong, non-sequential, not derived from phone or DB id; unique constraint. No frontend storage yet.
>
> **§10 Idempotency:** `QueueEntry.idempotency_key`, no `IdempotencyRecord` entity. Invariant: same key → cannot create two entries. Phone is not the mechanism. Persist only the foundation, not the join API — implement exactly the approved scope.
>
> **§11 SeatingAssignment:** `queue_entry_id`, `status`, `seating_code`, `ready_at`/`created_at` as specified, `expires_at`, `activated_at`, `released_at`, timestamps. Statuses `pending` (reserved, guest READY) / `active` (staff confirmed, group SEATED) / `released` (left or expired/cancelled). No allocation or staff confirmation yet.
>
> **§12 READY flow:** `QueueEntry(waiting) → allocation service → SeatingAssignment(pending) + SeatingAssignmentTable row(s) + seating_code → QueueEntry(ready) → guest sees code → staff enters code → SeatingAssignment(active) + QueueEntry(seated)`. Staff confirmation does NOT perform allocation.
>
> **§13 Seating code:** persist it; use the approved format if one exists, else the minimum safe implementation, documented as pending for the API phase; add a lookup index. No staff endpoint yet.
>
> **§14 READY expiration:** locked decision, timeout = 5 minutes. Persist `ready_at`/`expires_at`. Do NOT create Sidekiq/scheduler/cron/background sweep — expiration is lazy, implemented later; this phase only persists the timestamps.
>
> **§15 SeatingAssignmentTable:** `seating_assignment_id`, `table_id`, `released_at`, timestamps. 1 or 2 tables per assignment for MVP.
>
> **§16 Critical table exclusivity:** the database must guarantee a table belongs to at most one currently reserved/occupied assignment. Final approved approach: `released_at IS NULL` with `UNIQUE(table_id) WHERE released_at IS NULL` (partial unique index). Do NOT create a partial index predicated on `SeatingAssignment.status` — PostgreSQL partial-index predicates must use columns of the indexed table itself. Historical rows preserved.
>
> **§17 Historical assignments:** do NOT delete `SeatingAssignmentTable` rows on release — use `released_at = timestamp`; a released table can then be reused.
>
> **§18 Atomic two-table preparation:** the model must support a group of 6 → T21+T22 as one logical `SeatingAssignment`, both claim rows belonging to the same assignment. Do NOT implement the allocation transaction yet — no complicated locking framework; the later allocation service will use transactions and row locks.
>
> **§19 Maximum two tables:** MVP cap = 2. Enforce at model/domain level if appropriate without unnecessary DB complexity. No arbitrary N-table grouping.
>
> **§20 QueueEntry ↔ Assignment:** approved rule is `QueueEntry 1 — 0..1 active/pending assignment`; historical released assignments may remain. Do not use a global unique `queue_entry_id` that would prevent historical released assignments — prefer the appropriate partial unique index for *current* assignments.
>
> **§21 Seating code uniqueness:** an active/pending code resolves to exactly one current reservation; if uniqueness is only required among active/pending assignments, use the corresponding partial unique index — don't make historical codes globally unique forever unless required.
>
> **§22 Foreign keys:** evaluate/implement FKs for `SeatingAssignment.queue_entry_id`, `SeatingAssignmentTable.seating_assignment_id`/`table_id`, `TableAdjacency.table_id`/`adjacent_table_id`. No destructive cascading deletes that would silently destroy historical seating information unless explicitly approved.
>
> **§23 DB check constraints:** `Table.capacity > 0`, `QueueEntry.group_size > 0`, valid statuses, `TableAdjacency.table_id != adjacent_table_id`. Use DB constraints where they protect correctness under concurrency; don't blindly duplicate every Rails validation as a DB constraint.
>
> **§24 Index strategy:** only justified indexes — active guest token lookup, idempotency retry lookup, seating code lookup, active queue scan, table availability, adjacency lookup. No capacity index (~40 tables). Inspect generated indexes after migration.
>
> **§25 Rails associations:** `Table has_many seating_assignment_tables, has_many seating_assignments through ..., has_many adjacency relationships`; `TableAdjacency belongs_to table/adjacent_table`; `QueueEntry has_many seating_assignments`; `SeatingAssignment belongs_to queue_entry, has_many seating_assignment_tables, has_many tables through ...`; `SeatingAssignmentTable belongs_to seating_assignment/table`. Exact approved cardinality; avoid unnecessary callbacks/metaprogramming.
>
> **§26 Model validations:** positive group size, positive capacity, valid statuses, required associations/fields. Do NOT rely on Rails validations alone for concurrency-sensitive uniqueness — DB constraints remain authoritative.
>
> **§27 State machine:** follow an existing approved mechanism if the repo already uses one; otherwise don't introduce a large dependency solely for this phase. Persisted statuses must match the approved state model. No API/service orchestration yet.
>
> **§28 Deterministic 40-table seed:** exactly 20×2/18×4/2×6, `T01`...`T40` or the approved equivalent, deterministic and safely rerunnable where practical. No random generation.
>
> **§29 Deterministic adjacency seed:** `T01↔T02` ... `T19↔T20` (10 pairs among 2-seat), `T21↔T22` ... `T37↔T38` (9 pairs among 4-seat), `T39`/`T40` standalone. No additional adjacency.
>
> **§30 Table categories are not reserved pools:** the 20/18/2 distribution is capacity data, not permanent allocation pools — do not encode "2-person group → only 2-seat tables" etc. No allocation algorithm in this phase.
>
> **§31 Domain tests:** per entity (QueueEntry, Table, TableAdjacency, SeatingAssignment, SeatingAssignmentTable, guest token, seating code) — the specific cases listed match what was actually implemented (see Session 11 below). Seed: verify exactly 40/20/18/2 and the deterministic adjacency.
>
> **§32 Database concurrency/invariant tests:** same idempotency key → two attempts cannot persist two QueueEntries; same table → two current claims cannot persist; released table → can be claimed again. Do not implement the complete concurrent allocation algorithm.
>
> **§33 Clean database verification:** `rails db:drop db:create db:migrate db:seed` (or Docker equivalent) from a clean DB; verify 40 tables, correct capacity distribution, correct adjacency, constraints, indexes. Do not rely on manually modified local DB state.
>
> **§34 Schema review:** inspect the actual generated schema after migration — foreign keys, unique indexes, partial unique indexes and their predicates, check constraints, no authoritative occupancy field, no obsolete `TableCombination`/`IdempotencyRecord`/`GuestIdentity` tables. Do not assume Rails generated the intended SQL.
>
> **§35 Rails console/SQL verification**, using disposable/test data: (1) create a queue entry + assignment claiming T01, verify T01 can't be claimed by another current assignment; (2) set `released_at`, verify T01 can be claimed again; (3) attempt two current claims on T01, verify the database rejects the second; (4) create one assignment using T21+T22, verify both rows belong to the same assignment. Do not leave manual test records in the final seed database.
>
> **§36 Test suite:** run the complete relevant backend suite, not only new model tests. Report total/passed/failed/skipped. Investigate failures before claiming completion — do not hide or suppress failures.
>
> **§37 Documentation:** update implementation-facing docs only where actual implementation details need recording (potential files: `domain-model.md`, `data-model.md`, `domain-model-proposal.md`). Do not rewrite product decisions unnecessarily or historical AI records.
>
> **§38 AI working record:** update `agent-prompts.md`/`session-log.md`/`agent-decisions.md` — this prompt, the implementation session, implementation decisions, verification results, any genuine AI mistakes and how they were detected/corrected. Do not manufacture mistakes; if none, say so.
>
> **§39 If a genuine AI mistake occurs:** stop, identify the affected requirement/spec, explain the error, correct it, add a regression test if appropriate, record it in `ai-corrections.md`. Do not fabricate correction entries.
>
> **§40 Security/secrets:** check for passwords, API keys, tokens, `.env` files, machine-specific secrets before committing. No secrets committed; demo credentials (if any) use safe values, documented.
>
> **§41 Git checkpoint:** review `git status`/`git diff`/`git diff --stat`; verify no secrets, no unnecessary generated files, `documents/` and `.claude/` remain tracked; run tests and clean-DB verification; then commit `feat: implement waitlist domain model` (not if broken). After: `git status`, `git log --oneline --max-count=3`.
>
> **§42 Strict phase boundary — do NOT implement:** guest APIs (join/position/leave), staff APIs (login/queue/tables/seat/release/no-show), allocation (compatibility scoring, weighted aging, starvation policy, table matching, two-table selection, allocation service, queue-position calculation), infrastructure (Redis, Sidekiq, background workers, notification providers, WebSockets/SSE, rate limiting), frontend (guest join form, guest position page, staff dashboard, login screen, seating flow). Later phases.
>
> **§43 Success criteria:** the 23-item checklist (six entities implemented; migrations clean from empty DB; models/associations work; constraints/indexes implemented; token/idempotency/seating-code/expiration persistence; table exclusivity; 2-table assignment support; released tables reusable; historical rows remain; 40 deterministic tables in the exact 20/18/2 distribution; deterministic adjacency; domain tests pass; clean-DB verification passes; existing tests still pass; AI working record updated; git checkpoint created; no future-phase functionality).
>
> **§44 Final report format:** PASS/BLOCKED status; files created; files modified; domain model diagram; database constraints (esp. table exclusivity); indexes + supported queries; state model; seed verification (counts); test report (total/passed/failed/skipped); clean-DB verification performed; git (commit/message/working tree); AI working record files updated + genuine corrections; explicit confirmation of what was NOT implemented (guest/staff APIs, allocation, weighted aging, starvation algorithm, Redis, Sidekiq, notifications, live updates, rate limiting, frontend business flows). End exactly with: "Phase 5B.2 is complete. The persistent domain foundation, constraints, deterministic seed data, and domain tests are implemented and verified. No Phase 5B.3+ business/API functionality was implemented in this phase." STOP.

---

## How these prompts were used

- Prompt 1 produced the independent analysis in `../01-requirements/` (originally delivered as an in-conversation analysis; formalized into the requirements documents during the Prompt 2 session).
- Prompt 2 supplied the already-approved decisions that populate `../02-product-decisions/decision-log.md`, `seating-allocation-policy.md`, and `starvation-policy.md` verbatim in substance — the agent's job was to specify and document them, not originate them.
- Prompt 3 supplied specific, human-identified corrections to Session 1's output (see `ai-corrections.md` CORR-001 through CORR-003) plus a candidate-proposed technology stack for the agent to evaluate — not originate — and approve or challenge (`../02-product-decisions/decision-log.md` DEC-012).
- Prompt 4 authorized building the AI-native development environment itself (`CLAUDE.md`, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.claude/settings.json`) around the now-frozen specification, while explicitly delegating several configuration-only judgment calls (MCP, hooks) to the agent — see `agent-decisions.md` "Session 3" for how each was resolved and why.
- Prompt 5 was the first implementation-authorizing prompt (Session A bootstrap); it was interrupted by Prompt 6, a real-time human stop instruction, before the checkpoint could be reached — see `session-log.md` Session 4 for the full account of what was completed vs. blocked.
- Prompt 7 resumed that same bootstrap objective after the candidate fixed the environment blockers themselves, and the checkpoint was reached and verified in that session — see `session-log.md` Session 5.
- Prompt 8 (below) was a small cleanup/checkpoint task — correcting stale post-bootstrap documentation and creating the first git commit — explicitly not Phase 5B.
- Prompt 9 (below) was the first Phase 5B task — a specification/analysis-only domain model proposal, no code — delivered as `05-specifications/domain-model-proposal.md`.
- Prompt 10 (below) was human review feedback on that proposal — a real technical correction (CORR-004) and a product decision (the READY expiration policy) whose specifics the agent asked for rather than assumed.
- Prompt 11 (below), pasted in two parts (the first accidentally truncated, caught and flagged before acting on it, then completed by the candidate), locked in the expiration policy's exact shape and the corrected constraint design, and authorized finalizing the specification — including, for the first time, updating `03-architecture/domain-model.md` and `data-model.md` directly rather than only recommending it.
- Prompt 12 (below) closed the gap Session 9 had explicitly flagged and left open — it authorized a full consistency pass over every implementation-facing specification and diagram that still described the pre-`ready` model, which Session 9's own governing message had scoped away from.
- Prompt 13 (below) — the candidate's first attempt to paste it was truncated mid-"Migration Safety" section, flagged and not acted on; the complete version arrived as a file, `Phase_5B_2_Prompt.md`, and is recorded verbatim below. This was the first prompt in the entire project to actually authorize writing application code.
- A structural-reference project (`mentoring-session-booking-main`) was present in the same Downloads folder; per Prompt 2 §14, only its top-level documentation organization (a `docs/` folder with `ARCHITECTURE.md`, `DECISION_LOG.md`, `DIAGRAMS.md`, plus a `.kiro/specs`/`.kiro/steering` spec-driven layout) was glanced at for structural awareness. No content, decisions, or implementation from that project were copied — this project's own documentation structure follows Prompt 2 §11's explicit spec instead. That same reference project's backend (Rails API + PostgreSQL + Docker Compose) also informed the Prompt 3 stack evaluation (`decision-log.md` DEC-012) as evidence of the candidate's working familiarity with the proposed stack.
- Prompt 14 (below) authorized the first real business API — guest join with idempotency — supplied complete, in one piece, as `Phase_5B_3_Guest_Join_API_Prompt(1).md`, no truncation this time.
- Prompt 15 (below) authorized the next vertical slice — guest current-visit status and an informational (deliberately non-final) queue position — supplied complete as `Phase_5B_4_Guest_Current_Queue_Status_Position_Prompt(1).md`.
- Prompt 16 (below) authorized an analysis/specification-only phase — locking the allocation algorithm's exact formulas, eligibility rules, and worked examples before any allocation code is written — supplied complete as `Phase_5B_5_1_Allocation_Algorithm_Reconciliation_Prompt(1).md`. No application code was authorized or written in this phase.
- Prompt 17 (below) authorized the first allocation application code — a pure, side-effect-free decision engine implementing the now-locked algorithm, explicitly stopping short of any database mutation, table locking, or `SeatingAssignment` creation — supplied complete as `Phase_5B_5_2_Pure_Allocation_Decision_Engine_Prompt.md`.
- Prompt 18 (below) authorized connecting that pure engine to the real database — table locking, atomic reservation, `SeatingAssignment`/`SeatingAssignmentTable` creation, `seating_code` generation — for exactly one candidate per call, explicitly stopping short of any automatic trigger wiring — supplied complete as `Phase_5B_5_3_Transactional_Allocation_Table_Reservation_Prompt(1).md`.
- Prompt 19 (below) authorized connecting the already-tested allocation components to real business events (Guest Join, Release, No-show, Guest Leave) and adding a repeated-allocation orchestrator, explicitly requiring genuine specification/implementation gaps (no release or leave code path exists yet) to be reported as deferred rather than invented — supplied complete as `Phase_5B_5_4_Allocation_Trigger_Integration_Prompt(1).md`.
- Prompt 20 (below) authorized the staff-facing confirmation step — READY+PENDING → SEATED+ACTIVE by `seating_code` — explicitly forbidding any new allocation, table selection, or a full staff-authentication subsystem, while requiring the deferred-authentication status to be clearly reported rather than silently built or silently ignored — supplied complete as `Phase_5B_6_Staff_Seating_Confirmation_Prompt(1).md`.
- Prompt 21 (below) authorized the project's first frontend vertical slice — a guest join screen wired to the real, already-implemented backend — explicitly scoped to that one screen, forbidding any change to backend business logic, and requiring real browser/API/database verification rather than unit tests alone — supplied complete as `Claude_Prompt_P0_Guest_Join_Vertical_Slice.md`.
- Prompt 22 (below) authorized Guest Leave — the fourth and final approved allocation trigger (Phase 5B.5.4's own deferred item) — as the next P0 feature, explicitly forbidding any staff functionality and requiring the same real browser/API/database verification standard as Prompt 21 — supplied complete as `P0_Guest_Leave_Claude_Prompt.md`.
- Prompt 23 (below) authorized a P0 Staff Login stub — the minimum authentication boundary needed by `POST /staff/seat` and any future Staff API — explicitly forbidding any production-grade auth system (OAuth/SSO/MFA/JWT infrastructure) and any other Staff functionality, and requiring secret-safety checks given the GitHub repository is now public — supplied complete as `P0_Staff_Login_Exact_Claude_Prompt.md`.
- Prompt 24 (below) authorized the P0 Staff Queue vertical slice — `GET /staff/queue`, a read-only view reusing the existing Staff auth mechanism and DEC-015 expiration logic, plus a minimal frontend screen — explicitly forbidding Staff Table/Release/No-show and any allocation-algorithm change, and requiring a short plan before implementation — supplied complete as `P0_Staff_Queue_Claude_Prompt(1).md`.

---

## Prompt 14 — Phase 5B.3: Guest Join API + Idempotency

**Source:** `Phase_5B_3_Guest_Join_API_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** the first prompt in the project authorizing a real, guest-facing business API. Target vertical slice: `POST /guest/queue-entries → QueueEntry → idempotency → anonymous guest token → API response`. Explicitly excludes the allocation engine, queue position, guest leave, all staff APIs, and all infrastructure (Redis/Sidekiq/notifications/live updates/rate limiting/frontend).

**Full text (condensed; all 35 numbered sections' substantive content preserved):**

> **§0/§1 Human-driven development rule:** product decisions are already approved — do not reinterpret them, silently introduce new business rules, or expand this phase into the complete application. A genuine contradiction between approved spec and implementation reality → STOP and report before changing business design. Normal implementation-level decisions that don't change business behavior are allowed.
>
> **§2 Read first:** `CLAUDE.md`, all of `documents/01–06`, at minimum `functional-spec.md`, `api-spec.md`, `domain-model-proposal.md`, `domain-model.md`, `data-model.md`, `test-strategy.md`; also inspect the existing Phase 5B.2 implementation (`backend/app/models/`, `db/migrate/`, `db/schema.rb`, `config/routes.rb`, `test/`). Use whichever test framework already exists — do not introduce a new one.
>
> **§3 Phase objective — implement ONLY:** guest join endpoint; QueueEntry creation; anonymous guest token generation; idempotent retry handling; request validation; API response; controller/service tests; DB-backed concurrency/idempotency tests where practical; manual curl verification; documentation + AI-working-record updates; git checkpoint.
>
> **§4 Endpoint:** conceptually `POST /guest/join`, but follow the existing project's namespacing/versioning convention if one already exists, and do NOT invent a different URL structure if `api-spec.md` already defines one — only fall back to a fresh versioned route (e.g. `POST /api/v1/guest/join`, documented) if the spec doesn't yet define an exact route.
>
> **§5 Request:** `{ group_size, phone, idempotency_key }` conceptually — exact parameter names must follow `api-spec.md` if they differ. Required: group size, phone number, idempotency key. Do NOT require login/password/email/guest account/staff credentials.
>
> **§6 Validation:** `group_size` must be `> 0`, no invented maximum unless the approved spec already defines one. `phone` must be present; only reasonable validation, no elaborate phone-format system, don't reject legitimate numbers for overly strict formatting. `idempotency_key` must be present; never silently server-generated if the client omitted it.
>
> **§7 Anonymous guest identity:** on a genuinely new join, generate an opaque `active_visit_token` — cryptographically strong, unpredictable, non-sequential, not derived from the DB id or phone number. Returned to the guest. Never expose the internal `QueueEntry` id as the guest identity.
>
> **§8 New-join behavior:** validate → create `QueueEntry` (`status=waiting`, generate token, store `group_size`/`phone`/`idempotency_key`/`joined_at`) → return response. No table allocated, no `SeatingAssignment`, no seating code. Guest remains `waiting`.
>
> **§9 Response:** normally `201 Created`; at minimum `{ active_visit_token, status }` (plus a public identifier only if the approved API design calls for one). Never return table allocation, seating code, staff information, or DB internals.
>
> **§10/§11 Idempotent retry (critical):** a retry with the same `idempotency_key` MUST NOT create a second `QueueEntry` — must return the same logical result (same token, same status), never a new token. The DB uniqueness constraint on `idempotency_key` is authoritative; `SELECT → if not found → INSERT` alone is NOT sufficient (concurrent requests can both observe "not found") — must be safe under two genuinely concurrent requests sharing one key, using the DB constraint plus appropriate transaction/error handling.
>
> **§12 Concurrent idempotency test required:** two sequential requests do not count as a concurrency test — must demonstrate two truly concurrent requests with the same key produce exactly one `QueueEntry`; if true multithreading is hard in the existing test setup, implement the strongest realistic DB-backed test available and document its limitation explicitly.
>
> **§13 Conflicting idempotency retry:** same key, different `group_size`/`phone` on retry — MUST NOT silently mutate the original entry. Use the simplest safe behavior consistent with `api-spec.md` (normally `409 Conflict` with an explanatory error); follow `api-spec.md` if it already defines something else. Add a test.
>
> **§14 Same phone number:** do NOT make phone unique — two legitimate guests may share a phone number; these are not automatically the same entry. Idempotency is keyed on `idempotency_key`, never on phone. Add a test if appropriate.
>
> **§15 Multiple visits:** a returning guest on a different day (new `idempotency_key`) gets a separate `QueueEntry` and a separate token. Phone number is never a permanent guest identity; no guest account.
>
> **§16 Active visit token:** must be persisted on the new entry. A subsequent request using the token is a future-phase recovery mechanism — do NOT implement the full guest position/recovery API in this phase unless `api-spec.md` explicitly requires it for the join response itself.
>
> **§17 No allocation:** this phase MUST NOT inspect table availability, choose a table/adjacent tables, create `SeatingAssignment`/`SeatingAssignmentTable`, compute queue position, weighted priority, or starvation, or generate a seating code. After joining: `status == waiting` and `SeatingAssignment` count `== 0` for that entry — add a test proving it.
>
> **§18 No FIFO / no position yet:** do NOT implement queue position in this endpoint — seating is not FIFO; the allocation algorithm (compatibility-aware weighted aging + max-wait safeguard) determines eligibility later, not here.
>
> **§19 Transaction boundary:** `QueueEntry` creation should be atomic (validate → create → commit); the token must never be returned unless the record actually persisted. No unnecessary transaction complexity — the DB uniqueness constraint is what actually handles concurrent idempotency.
>
> **§20 Error responses:** consistent JSON errors for invalid group size (400/422 per existing convention), missing phone, missing idempotency key, conflicting-key retry (409, per the API-approved conflict behavior), and unexpected errors (a safe generic 500 — never SQL, stack traces, DB internals, or secrets).
>
> **§21 HTTP/JSON convention:** follow the existing project convention; do not introduce a second response format; if none exists, use a simple consistent structure and document it.
>
> **§22/§23 Controller vs. service vs. model:** keep the controller thin (HTTP in, HTTP out, status code only); a join/application service owns request-level idempotency handling, the creation flow, retry-vs-conflict determination, and the transaction boundary; the model owns persistence, validations, associations, DB constraints. No business orchestration in routes; no giant idempotency logic embedded directly in the controller — but don't invent unnecessary service layers if the existing architecture already uses another pattern.
>
> **§24 Required tests:** happy path (201, entry created, `waiting`, token returned); group_size 0 and negative rejected; missing phone rejected; same key twice → one entry, same logical response; concurrent same key → exactly one entry; conflicting retry → error + original entry unchanged; same phone + different keys → two legitimate entries; new key → new entry + new token; anonymous token exists/non-empty/not-the-DB-id/never collides between two new entries; no-allocation (`waiting`, zero `SeatingAssignment`, zero `SeatingAssignmentTable`).
>
> **§25 API verification:** after tests pass, run the actual app and demonstrate via curl: first join (show the real response), exact retry (verify no second entry, same token/result), conflicting retry (verify the documented conflict behavior). Do not leave demo data in the final seed database — use disposable data, cleaned up afterward.
>
> **§26 Clean database verification:** from a fully clean DB (`db:drop db:create db:migrate db:seed` or Docker equivalent), start the backend, call the endpoint, and verify the HTTP response, `QueueEntry` persistence, `waiting` status, token persistence, idempotency-key persistence, and zero `SeatingAssignment`.
>
> **§27 Documentation:** update `documents/05-specifications/api-spec.md` only where needed to reflect the actual implemented endpoint — endpoint, request, response, status codes, idempotency behavior, conflicting-idempotency behavior, anonymous-token behavior, explicit non-allocation behavior. Do NOT document future endpoints as implemented.
>
> **§28 Requirement traceability:** verify this phase satisfies the relevant guest-join/idempotency requirements; clearly distinguish "implemented now" from "persistence foundation only / later phase"; do not claim guest position/recovery is complete when it isn't.
>
> **§29 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md` with this prompt, the implementation session, API decisions, idempotency handling, test results, manual curl verification, and any genuine AI corrections. Do not fabricate mistakes.
>
> **§30 If a genuine AI mistake occurs:** stop, identify the affected requirement/spec, explain the error, correct it, add a regression test if appropriate, record it in `ai-corrections.md`. Do not fabricate correction entries.
>
> **§31 Security/secrets:** check for passwords, API keys, tokens, `.env` files, machine-specific secrets before committing; no secrets committed; safe demo values only if demo credentials are required.
>
> **§32 Git checkpoint:** review `git status`/`git diff`/`git diff --stat` — verify no secrets, no unrelated changes, no future-phase implementation, tests pass — then commit `feat: implement guest join api`; after, run `git status` and `git log --oneline --max-count=3`; working tree should be clean unless there's a clearly documented reason otherwise.
>
> **§33 Strict phase boundary — do NOT implement:** guest position (`GET /guest/position`) unless the current approved API contract explicitly requires it for the join flow itself; guest leave (`POST /guest/leave`); allocation (service, compatibility scoring, table/adjacency selection, weighted aging, starvation protection, queue position, `SeatingAssignment` creation); any staff API (login/queue/tables/seating/no-show/release); infrastructure (Redis, Sidekiq, background jobs, notification provider, WebSockets/SSE, rate limiting); any guest or staff frontend UI.
>
> **§34 Success criteria:** the 21-item checklist (endpoint implemented; valid request creates a `waiting` `QueueEntry`; token generated, persisted, non-sequential; idempotency key persisted; DB uniqueness protects idempotency; same-key retry doesn't duplicate and returns the same logical result; conflicting same-key request doesn't mutate the original; same phone usable by separate joins; new key can start a new visit; no table/`SeatingAssignment`/seating code created; API tests pass; DB/concurrency tests pass; actual curl verification done; documentation updated; AI working record updated; git checkpoint created; no Phase 5B.4+ functionality implemented).
>
> **§35 Final report format:** PASS/BLOCKED status; 1. Endpoint; 2. Request; 3. Success Response; 4. Idempotency (same-key retry, concurrent same-key, conflicting same-key, same-phone-different-keys); 5. Persistence; 6. Tests (Total/Passed/Failed/Skipped + key idempotency/concurrency tests named); 7. Manual API Verification (first join, exact retry, conflicting retry); 8. Database Verification; 9. Documentation; 10. AI Working Record; 11. Git (commit/message/working tree); 12. Scope Verification (explicit confirmation that guest position, guest leave, allocation, weighted aging, starvation, staff APIs, Redis, Sidekiq, notifications, live updates, rate limiting, and frontend business flows were NOT implemented). End exactly with: "Phase 5B.3 is complete. The guest join API, anonymous visit token, idempotency behavior, persistence, tests, and manual API verification are implemented and verified. No Phase 5B.4+ functionality was implemented in this phase." STOP.

---

## Prompt 15 — Phase 5B.4: Guest Current Queue Status + Position

**Source:** `Phase_5B_4_Guest_Current_Queue_Status_Position_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** the next vertical slice after Guest Join — `GET /guest/queue-entries/current`, identifying the visit by `active_visit_token` and returning its current state plus a guest-facing informational position. Explicitly forbids implementing the *final* allocation-priority position (compatibility scoring, weighted aging, starvation scoring, table matching) in this phase — that's Phase 5B.5.

**Full text (condensed; all 30 numbered sections' substantive content preserved):**

> **Framing:** the restaurant is NOT FIFO — do NOT blindly implement `position = count(queue_entries created before me)` as if that were the allocation algorithm. The future allocation system uses compatibility-aware weighted aging + a maximum-wait safeguard; the position API must not pretend FIFO is that algorithm.
>
> **§1 Human-driven development rule:** do not reinterpret approved product decisions, silently change business rules, or implement future allocation behavior prematurely. If a specification contradiction is found: identify it, explain it, resolve it using already-recorded decisions where possible, and STOP for human review only if the product decision itself genuinely needs to change. Normal implementation-level decisions are allowed.
>
> **§2 Read first:** `CLAUDE.md`, all of `documents/01–06`, at minimum `api-spec.md`, `functional-spec.md`, `domain-model-proposal.md`, `domain-model.md`, `data-model.md`, `test-strategy.md`, `seating-allocation-policy.md`, `starvation-policy.md`; also inspect `backend/app/`, `config/routes.rb`, `test/`, `db/schema.rb`, and review the existing Phase 5B.3 guest join implementation before writing new code. Do not introduce a second architecture pattern.
>
> **§3 First task — reconcile position semantics:** before coding, explicitly answer "what does 'position' mean to a guest in a NON-FIFO waitlist?" Do NOT assume earlier `joined_at` = ahead is equivalent to better allocation priority — those are different concepts, since the eventual engine weighs compatibility + aging + starvation protection + table availability, not chronological rank alone.
>
> **§4 Approved position approach for this phase:** implement a deliberately simple guest-facing position that does NOT claim to be final allocation priority — the simplest deterministic representation supported by the existing specification, derived from the currently-waiting queue. **CRITICAL: do NOT implement compatibility scoring, weighted aging, starvation scoring, table matching, or allocation simulation — those belong to Phase 5B.5.** If the existing requirements explicitly require a different position semantic, follow the requirement and document the distinction. The API documentation must clearly state guest position is informational, not a guarantee of seating order.
>
> **§5 Endpoint:** use the route already established by `api-spec.md` — do NOT invent a new one; conceptually `GET /guest/queue-entries/current`, but follow the approved route if it differs. Identify the guest via `active_visit_token` only — never phone number, database id, or idempotency key.
>
> **§6 Authentication model:** anonymous guest endpoint; the guest proves ownership by presenting `active_visit_token`, via whatever transport the approved API contract already specifies (e.g. `Authorization: Bearer <token>` or an `X-Visit-Token` header) — do not invent a second token mechanism.
>
> **§7 Current visit lookup:** `active_visit_token → QueueEntry → current guest state`; the token must resolve only the intended entry, using the existing database uniqueness guarantee; no unnecessary search by phone number.
>
> **§8 Success response:** for a valid current visit, return the guest's current state (conceptually `{ entry_id, status, position }`) using the exact JSON convention already established in `api-spec.md` (preserving a `data` wrapper if the spec uses one). Never expose internal table ids, `SeatingAssignment` ids, other guests' phone numbers/tokens, or database internals.
>
> **§9 Position semantics:** the guest should understand "there are approximately N entries currently ahead of you according to the current guest-facing queue representation" — NOT "you are guaranteed to be the Nth group seated," since allocation is not FIFO. Document this explicitly.
>
> **§10 Do NOT implement final allocation priority:** no `compatibility_score + waiting_time_weight + starvation_weight`, no `final_allocation_priority`, no call to a future allocation engine that doesn't exist, no inspecting table availability to compute position, no reserving tables.
>
> **§11 Waiting state:** for `status = waiting`, return the current informational position; make clear `waiting` means still in queue, not yet assigned a reservation.
>
> **§12 Ready state:** for `status = ready`, the guest already has a seating assignment — return the approved READY representation (at minimum `status = ready`; `seating_code` if the approved API allows it). Do not allocate anything here — READY means allocation already happened in a (future) allocation phase; this endpoint only reads state.
>
> **§13 Seated state:** for `status = seated`, return the appropriate current state per `api-spec.md`, without unnecessary internal assignment/table information.
>
> **§14 Left/no_show:** for terminal states, behave per the approved API spec (`404` or `200` with terminal status, whichever it defines) — do not invent behavior if already defined; document whichever is implemented.
>
> **§15 Invalid token:** return the approved safe not-found/unauthorized response; never leak "token exists but belongs to another guest" as a distinct case.
>
> **§16 Token security:** do not log the full `active_visit_token` in normal logs, avoid exposing it in error messages, never include another guest's token in any response, don't expose internal `QueueEntry` ids unless the API contract requires the public identifier.
>
> **§17 Expiration consideration:** the approved READY-expiration decision (5-minute timeout → auto no_show → tables released, evaluated lazily) must NOT be built as a background job in this phase. If this endpoint reads a READY entry and the existing specification already explicitly requires lazy expiration to be applied here, implement it; otherwise document that the full DEC-015 orchestration completes with the seating/allocation service. No Sidekiq.
>
> **§18 Performance:** use the indexed `active_visit_token` lookup, not a full queue scan, to identify the guest; use the simplest appropriate query for position given the current phase; don't optimize prematurely, but keep the query understandable given potentially hundreds of waiting groups.
>
> **§19 Controller vs. service:** keep the controller thin; preferred structure Controller → `CurrentQueueStatusService`/equivalent → `QueueEntry`; no large position algorithm directly in the controller; don't create unnecessary abstraction if the existing architecture already uses a simpler pattern.
>
> **§20 Required tests:** valid waiting guest (token → waiting entry → position returned); invalid token → 404/401; one guest cannot retrieve another's visit; READY representation; SEATED representation; LEFT behavior; NO_SHOW behavior; no-allocation (a position request must not create `SeatingAssignment`/`SeatingAssignmentTable` or reserve tables); position ordering across several waiting entries; a non-FIFO warning assertion (position is not treated as a seating-order guarantee).
>
> **§21 Position test example:** use entries A (earliest), B, C (latest) and verify the implemented informational position semantics — do NOT write a test claiming "A must always be seated before B," since final allocation is intentionally non-FIFO.
>
> **§22 API verification:** after tests pass, run the actual app; verify a waiting guest (200, `status=waiting`, position returned), an invalid token (correct error), multiple waiting guests' positions, and no side effects (`SeatingAssignment`/`SeatingAssignmentTable` counts unchanged after GETs). Clean up disposable data afterward.
>
> **§23 Documentation:** update `api-spec.md` only where needed — endpoint, authentication/token mechanism, response, position semantics, non-FIFO disclaimer, READY/SEATED/LEFT/NO_SHOW behavior, invalid-token behavior; also update requirements traceability if required. Do NOT claim final allocation priority is implemented.
>
> **§24 Requirement traceability:** explicitly distinguish implemented-now (current visit lookup, informational position, current status, token-based recovery) from deferred (compatibility-aware allocation priority, weighted aging, starvation protection, actual table selection, final seating order). Do not mark future allocation requirements complete.
>
> **§25 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md` with this prompt, the position-semantics decision, implementation decisions, test results, manual API verification, and genuine AI corrections if any. If FIFO is ever proposed as the *final* seating priority, that is a design error — do not silently accept it; record the correction if it occurs.
>
> **§26 AI correction rule:** if a genuine AI mistake occurs — identify it, explain why it conflicts with the approved design, correct it, add a regression test where appropriate, record it in `ai-corrections.md`. Do not manufacture a correction if none occurred.
>
> **§27 Git checkpoint:** review `git status`/`git diff`/`git diff --stat`; run the full relevant test suite and manual API verification; verify no secrets, no unrelated changes, no allocation code, no Redis/Sidekiq, no frontend business logic; then commit `feat: implement guest queue status api`; after, `git status` and `git log --oneline --max-count=3`; working tree should be clean.
>
> **§28 Strict phase boundary — do NOT implement:** allocation (compatibility scoring, weighted aging, starvation protection, table selection, adjacency matching, `SeatingAssignment`/`SeatingAssignmentTable` creation); `POST /guest/leave` unless already explicitly required by the approved Phase 5B.4 contract; any staff API; any infrastructure (Redis, Sidekiq, background workers, notifications, WebSockets/SSE, rate limiting); any guest or staff UI.
>
> **§29 Success criteria:** the 19-item checklist (endpoint implemented; token identifies the visit; invalid token handled safely; WAITING returned correctly; informational position returned and documented as non-guaranteed; READY/SEATED/LEFT/NO_SHOW handled per spec; no allocation/table-reservation/`SeatingAssignment` creation occurs; tests pass; manual verification completed; documentation + AI working record updated; git checkpoint created; no Phase 5B.5+ functionality implemented).
>
> **§30 Final report format:** PASS/BLOCKED status; 1. Endpoint; 2. Authentication/Token; 3. Position Semantics (and explicitly why it is NOT final allocation priority); 4. Response Examples (WAITING/READY/SEATED/terminal/invalid token); 5. Tests (Total/Passed/Failed/Skipped + important tests); 6. Manual API Verification; 7. Side-Effect Verification (no `SeatingAssignment`/`SeatingAssignmentTable` created, no table reserved); 8. Documentation; 9. AI Working Record; 10. Git (commit/message/working tree); 11. Scope Verification (explicit confirmation allocation, compatibility scoring, weighted aging, starvation protection, table selection, adjacency matching, staff APIs, guest leave, Redis, Sidekiq, notifications, live updates, rate limiting, and frontend business flows were NOT implemented). End exactly with: "Phase 5B.4 is complete. The guest current-visit/status API and informational queue position are implemented and verified. Final allocation priority and table-selection logic remain deferred to Phase 5B.5. No Phase 5B.5+ functionality was implemented in this phase." STOP.

---

## Prompt 16 — Phase 5B.5.1: Allocation Algorithm Reconciliation + Specification Lock

**Source:** `Phase_5B_5_1_Allocation_Algorithm_Reconciliation_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** analysis/specification only — no allocation service, no `SeatingAssignment` creation, no table selection, no weighted-aging/starvation code, no Redis/Sidekiq/staff APIs/frontend. Purpose: make the allocation algorithm precise enough (explicit formulas, not vague language) that Phase 5B.5.2 can implement it without inventing business rules.

**Full text (condensed; all 33 numbered sections' substantive content preserved):**

> **Framing:** 40 tables (20×2, 18×4, 2×6), adjacency (10×2+2→4, 9×4+4→8, 2 standalone 6-seat). A successful allocation creates `SeatingAssignment(pending)` → 1–2 `SeatingAssignmentTable` rows → `seating_code` → `QueueEntry → READY`; staff confirmation (`READY → SEATED`) is a separate, later operation the allocation engine must never perform.
>
> **§2 Approved algorithm direction:** compatibility-aware weighted aging + maximum-wait/starvation safeguard — NOT simple FIFO, NOT pure shortest-fit, NOT pure oldest-first, NOT an unconstrained AI runtime decision. Must remain deterministic and explainable; AI may help derive/validate the algorithm but must never become the runtime decision-maker.
>
> **§3 What this phase must answer (20 questions):** eligible configuration/group definitions; compatibility calculation; how waiting time increases priority; how starvation protection works and what happens past the threshold; the maximum-weight safeguard; how candidate group/table pairs are compared; how 1-table vs. 2-table configurations compare; what happens when two groups can use the same table; how to avoid wasting scarce capacity; how to avoid starving large groups; behavior when no/multiple configurations are available; the deterministic tie-breaker; the role of "missed compatible opportunities"; MVP vs. future fairness; where AI is useful; what must stay deterministic/rule-based; what invariants the DB transaction must guarantee.
>
> **§4 Eligibility vs. priority — do not mix these:** first determine hard legal compatibility, only then rank eligible candidates by priority. A high waiting/priority score must never make an incompatible configuration eligible — compatibility is a hard constraint, priority is a ranking mechanism among already-eligible candidates only.
>
> **§5 Table configurations:** single table valid when `capacity >= group_size`; combined only via valid seeded adjacency pairs (2+2→4, 4+4→8); never invent 3+-table combinations or new adjacency relationships.
>
> **§6 Capacity waste/compatibility:** distinguish exact fit from acceptable over-capacity (a 4-person group on a 4-seat table is a better fit than on a 6-seat table) — but do NOT make "smallest table" an absolute rule; the algorithm must balance fit, waiting time, scarcity, and starvation protection together.
>
> **§7 Scarcity:** a configuration is more valuable when it has fewer suitable alternatives (e.g. a 6-person group can only use 6-seat tables, unlike a 2-person group) — the algorithm should account for this opportunity cost, using a deterministic, explainable signal based on the *currently* available configuration/capacity landscape, not a full predictive optimization system. Document the exact formula.
>
> **§8 Waiting-time aging:** `waiting_seconds = now - joined_at`; define a bounded/normalized aging contribution (starting value, growth, maximum contribution, units, tunable config) — must not grow without bound. Treat the existing 20-minute starvation threshold as configuration.
>
> **§9 Starvation protection:** not simply "oldest always wins" — a group past the threshold receives strong priority protection for its complete configuration, but protection still respects hard compatibility; never invent impossible seating if no compatible configuration exists.
>
> **§10 Maximum-wait/maximum-weight safeguard:** make "maximum weight safeguard" precise — waiting time must not grow forever and eventually dominate every other factor unbounded; define either a maximum aging contribution or a maximum overall priority contribution, whichever is more consistent with the final model, and explain why. Must remain deterministic.
>
> **§11 Missed compatible opportunities:** define carefully — a group that was eligible for a configuration that became available, but another allocation consumed it instead. Incompatible configurations never count as missed opportunities (worked examples given, table A 4-seat vs 6-seat).
>
> **§12 Future fairness vs. MVP:** document separately. MVP now: compatibility, fit quality, scarcity, waiting-time aging, starvation protection, maximum-weight safeguard, deterministic tie-breakers. Future: cumulative missed-opportunity tracking, historical fairness, predictive demand, table-sharing, learned compatibility, adaptive weighting, multi-objective optimization, AI-assisted policy tuning — none implemented now.
>
> **§13 AI role:** AI may analyze historical outcomes, suggest weight adjustments, identify starvation patterns, detect unusual allocation patterns, simulate alternative policies offline, help tune parameters. AI must NOT directly decide at runtime ("give Table 12 to Group 7") — runtime allocation must be deterministic and explainable, the final decision comes from the explicit algorithm.
>
> **§14 Global allocation vs. first-match:** do not implement find-first-group→find-first-table→allocate. Instead consider all currently eligible candidates (waiting groups × currently available configurations) together, score them, choose the deterministic highest-priority candidate. Document the complexity and why it's acceptable at MVP scale.
>
> **§15 Single vs. combined tables:** define how a one-table candidate compares to a two-table candidate (e.g. group of 6: one 6-seat table vs. 4+4=8) — a single table is generally a better fit (less resource consumption) but the algorithm must consider scarcity/opportunity cost; do not hardcode "single always beats combined" unless the complete priority model actually justifies it. Document the actual rule.
>
> **§16 Two-table atomicity:** the eventual implementation must guarantee both tables reserved or neither — no partial combined assignment. The DB invariant is already `UNIQUE(table_id) WHERE released_at IS NULL`. The allocation transaction must: identify candidates, lock required tables in deterministic order, re-check availability, create `SeatingAssignment`, create 1–2 `SeatingAssignmentTable` rows, generate `seating_code`, transition to `READY`, commit — rolling back entirely if any table is unavailable. This phase only specifies this behavior; do NOT implement it.
>
> **§17 Concurrency:** the final algorithm must handle two allocation requests targeting the same table — use `SELECT ... FOR UPDATE` on target tables, always lock multiple tables in a deterministic order to reduce deadlock risk; the DB uniqueness constraint remains defense-in-depth. Document `READ COMMITTED` as the expected isolation level unless a strong reason exists otherwise.
>
> **§18 Allocation trigger:** document what triggers the future allocation pass (table release, guest leave, no-show, new table availability, queue join). No background scheduler — the allocation engine should be callable synchronously by the application operation that creates the opportunity; Sidekiq/background processing remains deferred.
>
> **§19 Multiple available tables:** when several configurations are simultaneously available, do NOT simply allocate in `joined_at` order — generate candidate combinations and apply the agreed scoring model; document the expected result and why.
>
> **§20 Required examples:** produce at least 12 worked examples (available tables, waiting groups, eligible candidates, compatibility/fit/scarcity/aging/starvation factors, winner, why alternatives lose), covering the 12 named scenarios: simple free-table match; only a larger table available; two groups competing for one table; small+large group vs. one large table (twice, different sizes); large group needing a combined pair; large group with both a single and a combined option simultaneously available; repeated small-group arrivals while a large group waits (starvation demonstration); a better-fitting small group vs. a starvation-protected large group (safeguard demonstration); a deterministic tie; a scarcity-driven decision; and no currently compatible configuration (no allocation, queue stays waiting).
>
> **§21 Tie-breaking:** must be deterministic, no randomness. A possible hierarchy was suggested (starvation → overall score → compatibility/waste → resource consumption → joined_at → id) but must NOT be automatically accepted — derive the final hierarchy from the approved requirements and explain it; the final implementation must always return the same winner for the same DB state and timestamp.
>
> **§22 Configuration:** identify tunable values (at minimum `starvation_threshold`, `aging_weight`, `compatibility_weight`, `scarcity_weight`, `maximum_aging_contribution`) — no magic numbers scattered through code; use a centralized configuration mechanism appropriate to the Rails project. This phase only specifies the configuration contract.
>
> **§23 AI correction/requirement traceability:** while performing this analysis, actively compare the proposed algorithm against every requirements/decision/spec document. If previous AI-generated documentation contains a contradictory allocation rule, identify it — correct the current specification, preserve the historical record, and record the correction in `ai-corrections.md` if applicable. Do not silently overwrite historical AI-working records.
>
> **§24 Documents to update:** `seating-allocation-policy.md`, `starvation-policy.md`, `allocation-spec.md`, `functional-spec.md`, `api-spec.md` — only where the final algorithm actually requires clarification or correction; also `01-requirements/traceability.md` if required. Do NOT modify unrelated historical records.
>
> **§25 Create a dedicated algorithm specification:** `documents/05-specifications/allocation-algorithm.md`, containing: purpose; inputs; hard eligibility rules; table configuration generation; compatibility calculation; fit calculation; scarcity calculation; waiting-time aging; starvation protection; maximum-weight safeguard; candidate scoring; global winner selection; tie-breaking; missed-compatible-opportunity definition; MVP vs. future fairness; AI role; concurrency requirements; transaction requirements; configuration values; complexity; 12+ worked examples; pseudocode; known limitations; future evolution.
>
> **§26 Pseudocode requirement:** must contain clear pseudocode at least as precise as the illustrative example given (`allocate(available_tables, waiting_entries)` generating configurations, building candidates via compatibility+evaluate, returning `no_allocation` if empty or `deterministic_max(candidates)` otherwise) — illustrative only; the final pseudocode must use the actual agreed scoring model.
>
> **§27 Formula requirement:** do NOT leave the algorithm as vague language ("consider waiting time and compatibility"). Define actual formulas — e.g. normalized `fit_score`/`aging_score`/`scarcity_score`/`starvation_score` components and a `total_score`. The exact formula must be derived from the requirements and justified; all weights explicit; avoid unexplained arbitrary numbers. Any MVP-parameter weight must be labeled "tunable MVP parameter" with an explanation of how it could later be tuned.
>
> **§28 Do not over-optimize:** MVP scale is ~40 tables, hundreds of waiting groups — straightforward candidate enumeration is acceptable if its complexity is reasonable. Do NOT introduce ML models, vector databases, optimization solvers, reinforcement learning, or complex distributed systems unless a requirement explicitly demands them.
>
> **§29 No application code:** at the end of this phase, models/migrations/controllers/services/routes are unchanged and allocation tests are not implemented yet — only specification/documentation/AI-working-record changes are allowed. If code changes are absolutely necessary to validate a formula, do not commit them — prefer reasoning/examples instead.
>
> **§30 Verification (before declaring completion):** re-read the finalized algorithm; run a contradiction/terminology grep against the repository; verify no stale "FIFO allocation" rule remains in an authoritative document; verify "position" remains distinguished from final allocation priority; verify the 1–2 table maximum is preserved; verify 6-seat tables remain standalone; verify 2+2/4+4 adjacency semantics; verify the starvation threshold remains configurable; verify READY semantics; verify allocation ≠ staff confirmation; verify future fairness is explicitly separated from MVP; verify AI runtime decision-making is explicitly excluded. Do not rewrite historical AI-working records just to make the grep clean.
>
> **§31 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md`; if a genuine AI error is discovered, update `ai-corrections.md` recording what was proposed, why it was wrong, the corrected rule, and the evidence/requirement that caused the correction. Do not fabricate corrections.
>
> **§32 Git:** review `git status`/`git diff`/`git diff --stat` — there must be NO application-code changes; create a documentation-only checkpoint `docs: lock allocation algorithm specification`; then verify `git status` and `git log --oneline --max-count=3`; working tree should be clean.
>
> **§33 Final report format:** PASS/BLOCKED status; 1. Final Algorithm; 2. Formula; 3. Hard Eligibility; 4. Scarcity; 5. Aging; 6. Starvation; 7. Maximum Safeguard; 8. Missed Compatible Opportunities; 9. Tie-Breaking; 10. Global Allocation; 11. Combined Tables; 12. Worked Examples (summarize ≥12); 13. MVP vs. Future (implemented-next-phase / future fairness / future AI assistance, clearly separated); 14. AI Role; 15. Concurrency; 16. Documents (every updated/created document); 17. AI Working Record; 18. Git (commit/message/working tree); 19. Scope Verification (explicit confirmation no allocation code, no table reservations, no Redis, no Sidekiq, no staff API, no frontend changes were implemented). End exactly with: "Phase 5B.5.1 is complete. The allocation algorithm has been reconciled, made deterministic and explainable, and documented with explicit formulas, eligibility rules, starvation protection, scarcity, tie-breaking, concurrency requirements, and worked examples. No allocation application code was implemented in this phase. Phase 5B.5.2 implementation is now the next authorized task." STOP.

---

## Prompt 17 — Phase 5B.5.2: Pure Allocation Decision Engine

**Source:** `Phase_5B_5_2_Pure_Allocation_Decision_Engine_Prompt.md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** the first allocation application code. Implements only the deterministic decision-making portion of allocation — "given the current WAITING entries and the currently available table configurations, which group/configuration should be selected next?" — without persisting anything. `documents/05-specifications/allocation-algorithm.md` (locked, Phase 5B.5.1) is the binding source of truth; this phase implements it, does not revise it.

**Full text (condensed; all 37 numbered sections' substantive content preserved):**

> **§1 Very important phase boundary — MUST NOT implement:** `SeatingAssignment`/`SeatingAssignmentTable` creation, table locking, `SELECT FOR UPDATE`, database reservation, `QueueEntry → READY` transition, `seating_code` generation, staff confirmation, Redis, Sidekiq, background jobs, notifications, frontend, staff APIs. Output is a pure decision — `waiting entries + available configurations → AllocationDecisionEngine → selected candidate OR no allocation` — the engine must not modify the database.
>
> **§2 Read first:** `CLAUDE.md`, `allocation-algorithm.md`, `allocation-spec.md`, `seating-allocation-policy.md`, `starvation-policy.md`, `functional-spec.md`, `api-spec.md`, `domain-model.md`, `data-model.md`, `test-strategy.md`; inspect `backend/app/models/`, `app/services/`, `test/`, `db/schema.rb`. Follow the existing Rails architecture — do not invent a second service architecture.
>
> **§3 Source of truth:** the final formulas in `allocation-algorithm.md` are authoritative — do not change the algorithm while implementing it. If a genuine contradiction is discovered between implementation and specification: stop implementing that part, explain the contradiction, do not silently change the algorithm, record it for human review. Do not "improve" the algorithm during implementation.
>
> **§4 Pure function requirement:** input state → decision → no side effects. The engine must not create/update/delete records, reserve tables, or mutate `QueueEntry`/`Table` state. Same logical input state must produce the same decision. `now` may be passed in explicitly for deterministic tests — prefer dependency injection over calling `Time.current` deep inside scoring methods.
>
> **§5 Inputs — waiting entries:** at minimum `id`, `group_size`, `joined_at`, `status`; only `WAITING` entries are eligible — do NOT include `READY`/`SEATED`/`LEFT`/`NO_SHOW` in the candidate pool, and the engine must not change their state.
>
> **§6 Table configurations:** single table or a valid adjacent pair only. Current MVP supports 1 table OR 2 adjacent tables — never 3+ or arbitrary combinations.
>
> **§7 Configuration representation:** a small internal immutable value object (`TableConfiguration`: `table_ids`, `capacity`, `table_count`) — keep it simple, don't couple the pure scoring engine to ActiveRecord persistence more than necessary.
>
> **§8 Configuration generation:** if included in this phase, must be deterministic — every free table, plus every valid free adjacency pair, no duplicate/reverse pairs (canonical ordering preserved, e.g. `[3,4]` not also `[4,3]`).
>
> **§9 Hard compatibility gate:** for every `waiting entry × configuration` candidate, `configuration.capacity >= entry.group_size` must hold, or the candidate must not be scored at all — no amount of waiting/scarcity/starvation/AI/weighting can make an incompatible configuration eligible.
>
> **§10 Fit score:** exactly `group_size / configuration.capacity` — do not invent another formula, reverse the ratio, or add arbitrary bonuses.
>
> **§11 Scarcity score:** exactly `1 / count(currently-compatible-available-configurations)`, recalculated from the current candidate/configuration set for each waiting entry — never a static assumption like "6-seat tables are always scarce."
>
> **§12 Aging score:** exactly `min(waiting_seconds / MAX_AGING_WINDOW_SECONDS, 1.0)` where `waiting_seconds = now - joined_at`; the spec's default `MAX_AGING_WINDOW_SECONDS` is the 20-minute starvation threshold — don't hardcode `1200`, use the configured value. `0.0` at join, linear growth, capped at `1.0`.
>
> **§13 Starvation protection:** derived, not stored — `protected = waiting_seconds >= STARVATION_THRESHOLD_SECONDS` (default 20 minutes). Do NOT add a starvation column, schedule an update, persist a flag, or create a background job.
>
> **§14 Starvation pool override (critical):** after hard compatibility filtering, if ANY eligible candidate is starvation-protected, `candidates_for_ranking` becomes ONLY the protected candidates; otherwise it's all eligible candidates. A protected candidate can exclude all non-protected candidates from the decision. This is NOT an additive bonus (`total_score += starvation_bonus` would contradict the locked algorithm) — do not implement it that way.
>
> **§15 Total score:** exactly `0.4 * fit_score + 0.3 * scarcity_score + 0.3 * aging_score`, weights as centralized configuration (`FIT_WEIGHT`/`SCARCITY_WEIGHT`/`AGING_WEIGHT`), not scattered magic numbers. Result bounded `0 <= total_score <= 1` given correctly normalized components.
>
> **§16 Maximum safeguard:** aging capped at `1.0` therefore `total_score <= 1.0` — do not let waiting time increase the score indefinitely, do not add an unbounded waiting-time multiplier.
>
> **§17 Global candidate generation:** do NOT implement first-entry→first-table→allocate. Instead generate `waiting entries × available configurations`, hard-compatibility-filter, score, starvation-pool-filter, deterministically rank, choose ONE winner — a global decision, not first-match.
>
> **§18 Tie-breaking:** the locked ordering — (1) higher `total_score`, (2) fewer tables consumed, (3) earlier `joined_at`, (4) lower `QueueEntry` id. No randomness, no phone number, no token, no table name, no database insertion order. Same state must always produce the same winner.
>
> **§19 Combined tables:** `capacity = table_1.capacity + table_2.capacity`, `table_count = 2`, exact same scoring formulas as single tables — do not hardcode "single always wins"; a single table wins only via a higher score or the fewer-tables tie-break on an exact tie.
>
> **§20/§21 Required worked examples:** a starvation example (6-seat table available, 2-person 2-min-waiting group vs. 6-person 21-min-waiting starvation-protected group — B must win even though A has the better fit score, covered by a test) and a scarcity example (2-seat/4-seat/6-seat all available; a 2-person group has 3 compatible configurations → scarcity 1/3, a 6-person group has 1 → scarcity 1; calculated independently per entry, never one global number).
>
> **§22 Missed opportunities:** do NOT implement tracking in this phase — no counter, no fairness debt, no history-based score modification, no new DB field. The engine simply makes the current deterministic decision.
>
> **§23 Multi-pass allocation:** the eventual process repeats choose-winner → transaction → refresh state → fresh grid → choose next winner, but THIS PHASE ONLY IMPLEMENTS ONE DECISION — return one winner or no winner; do not implement the repeat/transaction loop yet (that belongs to the transactional allocation phase).
>
> **§24 No database side effects:** must not call `save!`/`update!`/`create!`/`destroy!`/`delete!`/`touch!` inside the decision engine. May read data if necessary, but prefer passing plain/value objects in — the engine should be straightforward to unit test without a database when possible.
>
> **§25 Testing strategy (16 named tests):** exact fit; larger compatible table; incompatible configuration excluded; scarcity (1/3 and 1/1 cases); aging (0 at join, 0.5 at half window, 1 at/after max); starvation threshold (before/at); starvation pool override; exact score-formula verification; deterministic tie-breaks (fewer tables / earlier joined_at / lower id); single-vs-combined using summed capacity; no compatible candidate → no winner; global-grid winner (not first-match); the starvation scenario from §20.
>
> **§26 Property/invariant tests, where practical:** incompatible candidates never returned; score between 0 and 1; aging never exceeds 1; scarcity between 0 and 1; non-WAITING entries ignored; the engine never returns more than one winner; no database side effects; same input + same `now` = same decision.
>
> **§27 Test the actual spec examples:** translate the most important of `allocation-algorithm.md`'s 12 worked examples into executable tests. Do not alter expected outcomes merely to make tests pass — if a worked example conflicts with the implementation, stop and report the contradiction.
>
> **§28 Architecture:** a clear application service/value-object structure appropriate to the existing Rails codebase (a reasonable shape: `AllocationDecisionEngine → Candidate → TableConfiguration`) — inspect the existing architecture first, don't create unnecessary layers. The important boundary: pure decision ≠ database allocation transaction.
>
> **§29 Time handling:** inject `now` (e.g. `engine.decide(waiting_entries:, configurations:, now:)`) for exact deterministic tests — never real wall-clock time inside unit tests.
>
> **§30 Configuration:** centralized configuration for `FIT_WEIGHT`/`SCARCITY_WEIGHT`/`AGING_WEIGHT`/`STARVATION_THRESHOLD_SECONDS`/`MAX_AGING_WINDOW_SECONDS`, defaults `0.4`/`0.3`/`0.3`/20 min/20 min. Use the existing project configuration mechanism if one exists; don't introduce a heavyweight framework.
>
> **§31 Documentation:** update the relevant specification only if the actual implementation requires clarification — do NOT change the locked formulas; document the implementation location (e.g. an implementation-status note in `allocation-algorithm.md`); do not rewrite the algorithm merely to match code style.
>
> **§32 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md` with this prompt, implementation decisions, test results, any specification issues, genuine AI corrections; if a genuine mistake occurs, also update `ai-corrections.md`. Do not fabricate mistakes.
>
> **§33 Important correction rule:** if implementing would require changing the approved algorithm — STOP, do NOT auto-"fix" the specification, report the specification rule / implementation conflict / proposed change / reason, and wait for human approval.
>
> **§34 Git:** review `git status`/`git diff`/`git diff --stat` — verify only Phase 5B.5.2 files changed (no migrations, no API behavior, no table reservations, no Redis, no Sidekiq, no frontend, no staff API); run the relevant tests and full test suite; commit `feat: implement allocation decision engine`; then `git status`/`git log --oneline --max-count=3`; working tree should be clean.
>
> **§35 Success criteria:** the 26-item checklist (pure engine implemented; WAITING-only pool; single/combined configurations supported, never 3+; hard compatibility gate; exact fit/scarcity/aging formulas; derived starvation with pool override; exact weighted score bounded at 1; deterministic tie-breaking; global candidate grid; one-winner-or-none result; injected deterministic time; no DB mutation/locking/`SeatingAssignment`/READY-transition/`seating_code`; unit tests for all critical rules; worked-example tests; full existing suite passes; documentation/AI-working-record/git checkpoint done).
>
> **§36 Strictly not implemented — confirm remain absent:** `SeatingAssignment`/`SeatingAssignmentTable` persistence, `SELECT FOR UPDATE`, table reservation, `QueueEntry → READY`, `seating_code` generation, the allocation-trigger loop, release/no-show/leave integration, staff confirmation, Redis, Sidekiq, notifications, live updates, frontend, staff APIs, missed-opportunity tracking, fairness debt, predictive demand, runtime AI allocation.
>
> **§37 Final report format:** PASS/BLOCKED status; 1. Implementation (engine class/service, value objects, configuration, candidate-generation location); 2. Algorithm (compatibility/fit/scarcity/aging/starvation/total-score/tie-breaking summary); 3. Tests (Total/Passed/Failed/Skipped + most important tests); 4. Worked Examples (which spec examples were converted to tests); 5. Determinism (how injected time and deterministic tie-breaking were verified); 6. Side Effects (explicit confirmation: no DB writes, no table locks, no assignments, no READY transitions); 7. Documentation; 8. AI Working Record; 9. Git (commit/message/working tree); 10. Scope Verification (explicit confirmation transactional allocation and reservation are NOT implemented yet). End exactly with: "Phase 5B.5.2 is complete. The pure deterministic allocation decision engine is implemented and tested against the locked allocation algorithm. It selects at most one winning group/configuration without mutating the database. Transactional table reservation, SeatingAssignment creation, READY transition, and allocation-trigger integration remain deferred to the next phase. No Phase 5B.5.3+ functionality was implemented in this phase." STOP.

---

## Prompt 18 — Phase 5B.5.3: Transactional Allocation + Atomic Table Reservation

**Source:** `Phase_5B_5_3_Transactional_Allocation_Table_Reservation_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** connects the existing pure `Allocation::DecisionEngine` to the real PostgreSQL database — the goal is to safely turn ONE selected candidate into `SeatingAssignment(pending)` + 1–2 `SeatingAssignmentTable` rows + `seating_code` + `QueueEntry → READY`, atomically, with real concurrency protection. Explicitly one transactional operation per call — no automatic triggering, no repeated allocation passes, no staff/guest-facing APIs.

**Full text (condensed; all 32 numbered sections' substantive content preserved):**

> **§1 Strict phase boundary — do NOT implement:** automatic allocation after join/release/no-show/leave, repeated allocation passes, guest leave API, staff APIs/confirmation, Redis, Sidekiq, background jobs, notifications, WebSockets/SSE, frontend, rate limiting, missed-opportunity tracking, fairness debt, predictive demand, runtime AI allocation. This service allocates at most one candidate per call; the future orchestration phase will call it repeatedly.
>
> **§2 Read first:** `CLAUDE.md`, `allocation-algorithm.md`, `allocation-spec.md`, `domain-model-proposal.md`, `api-spec.md`, `functional-spec.md`, `test-strategy.md`, `domain-model.md`, `data-model.md`; inspect `backend/app/services/allocation/`, `app/models/`, `test/services/allocation/`, `db/schema.rb`. Understand the existing `DecisionEngine`/`ConfigurationGenerator`/`TableConfiguration`/`Candidate`/`Policy` — do not replace or rewrite the pure decision engine.
>
> **§3 Required architecture:** `ConfigurationGenerator → DecisionEngine → Transaction/Reservation Service → PostgreSQL transaction`. `DecisionEngine` remains pure. The new transactional service is responsible for: obtaining current `WAITING` entries; obtaining current available configurations; asking `DecisionEngine` for one winner; beginning a transaction; locking target table rows; re-checking table availability; re-checking the `QueueEntry` is still `WAITING`; creating `SeatingAssignment(pending)`; creating 1–2 `SeatingAssignmentTable` rows; generating `seating_code`; changing `QueueEntry` `WAITING → READY`; committing atomically. No DB transaction logic inside `DecisionEngine`.
>
> **§4 Service boundary:** an appropriately-named service (e.g. `Allocation::TransactionService`/`ReservationService`), public behavior conceptually `allocate_one(now:)`/`call(now:)`, returning a clear result — success / no eligible candidate / stale candidate-concurrency loss. No unnecessarily complex result framework.
>
> **§5 One candidate only:** select and persist only ONE winner per invocation. If the winner becomes unavailable due to a race, do NOT silently choose a second candidate this phase — return a concurrency-loss/stale-candidate result; the future orchestration phase may regenerate the grid and call again.
>
> **§6 Fresh state and database authority:** the `DecisionEngine`'s proposed winner is a snapshot-based proposal, not a guaranteed reservation — the database transaction (lock → re-check → reserve or reject) is the final authority. Never trust pre-lock availability.
>
> **§7 Table locking:** `SELECT ... FOR UPDATE` through ActiveRecord's mechanism; lock all of a combined candidate's tables; always normalize multiple table ids into ascending order before locking, to reduce deadlock risk. Add a test for lock-order normalization where practical.
>
> **§8 Table occupancy source of truth:** do NOT introduce or use `Table.status` — occupancy is derived from `SeatingAssignmentTable` rows with `released_at IS NULL`; `UNIQUE(table_id) WHERE released_at IS NULL` is defense-in-depth, not a substitute for locking and re-checking.
>
> **§9 Availability re-check:** after acquiring locks, check every selected table; if any has an active (`released_at IS NULL`) claim, the candidate cannot be committed — for a combined candidate, a free-A/occupied-B split must leave NO assignment, NO assignment-table row for A, and no `QueueEntry` state change at all.
>
> **§10 QueueEntry re-check:** inside the transaction, verify the selected entry is still `waiting`; if it's now `ready`/`seated`/`left`/`no_show`, do not create an assignment and do not select another candidate this phase — return a stale-candidate result. Lock the `QueueEntry` row as part of the transaction if appropriate; document and keep the chosen lock order consistent.
>
> **§11 Transaction:** all persistence happens inside ONE transaction — begin, lock table(s) in ascending id order, re-check table availability, re-check `QueueEntry` status, create `SeatingAssignment(pending)`, create 1–2 `SeatingAssignmentTable` rows, generate `seating_code`, `QueueEntry` `WAITING → READY`, commit. Any step failing → rollback, no partial allocation may remain.
>
> **§12 SeatingAssignment:** create with `queue_entry_id` = winning entry, `status = pending`, using only already-defined schema fields — never create it `active`. Allocation performs `waiting → ready` only; staff confirmation later performs the seating transition.
>
> **§13 Assignment-table rows:** exactly 1 (single) or 2 (combined) rows, both referencing the same `seating_assignment_id`, both with `released_at = NULL`. Never delete historical rows.
>
> **§14 Combined allocation atomicity (mandatory):** a free+occupied pair must produce no `SeatingAssignment`, no assignment-table row for the free table, that table remains free, `QueueEntry` remains `waiting` — the transaction must roll back entirely.
>
> **§15 Seating code:** inspect the current approved contract (`domain-model-proposal.md`, `allocation-spec.md`, `api-spec.md`, existing code); use the repository's existing implementation/contract, don't invent a conflicting public format. Must be server-generated, not DB-id-derived, unique, satisfying the existing partial unique constraint, available once `READY`. If OPEN-005 is still explicitly unresolved and the current spec permits a placeholder, use the smallest safe implementation and record the decision — do not silently turn OPEN-005 into a new product decision. On a collision, safely retry generation inside the transaction rather than overwriting another guest's code.
>
> **§16 Allocation idempotency/duplicate assignments:** this is NOT the guest join idempotency mechanism — do not use `idempotency_key` as an allocation transaction key unless the spec explicitly requires it. The selected `QueueEntry` must never receive a second active/pending assignment; the DB partial unique constraint on `seating_assignments.queue_entry_id WHERE status <> 'released'` remains authoritative. A duplicate race → a concurrency/stale result, never a duplicate active assignment.
>
> **§17 Concurrency scenario:** two allocation requests targeting the same table — A locks, verifies free, creates the reservation, commits; B then waits, obtains the lock, re-checks, sees it occupied, creates nothing. Exactly one active reservation results. Do not rely only on mocks — at least one test must exercise real PostgreSQL concurrency.
>
> **§18 Combined-table concurrency:** two concurrent transactions attempting the same pair must both lock in the same order; only one can successfully reserve both; never a split where transaction A owns one table and B owns the other for the same combined allocation — all-or-nothing.
>
> **§19 Isolation:** `READ COMMITTED` (established); do not introduce `SERIALIZABLE` without a demonstrated requirement. Concurrency model: row locks + post-lock availability check + DB uniqueness constraint + atomic transaction.
>
> **§20 Database constraint errors:** a genuine unique-constraint violation due to a race → rollback and return an appropriate concurrency-loss/stale result. Do not silently swallow unexpected database errors; do not broadly rescue all exceptions and report them as "no availability."
>
> **§21 Required tests (18 named):** single 2/4/6-seat allocation; 2+2 and 4+4 combined allocation; non-adjacent pair never forms a configuration; an occupied table can't be stolen; combined partial availability produces no allocation and no partial reservation; a `QueueEntry` that's no longer `waiting` before commit → no assignment; an existing pending/active assignment prevents a duplicate; seating-code properties (non-null, unique, not DB-id-derived) and collision-safe regeneration; rollback leaves zero partial records (single and combined cases); exactly one assignment per call even with multiple eligible groups/tables; two real-thread same-table and same-adjacent-pair races each resolve to exactly one success with no duplicate/partial reservation; all existing `DecisionEngine` tests remain green.
>
> **§22 Transactional testing rule:** use the existing testing strategy; for real-thread concurrency, don't use a single shared connection, use separate DB connections where necessary, avoid `use_transactional_tests` where it prevents concurrent visibility, and explicitly clean up test data. The concurrency test must exercise real PostgreSQL behavior, not mocked locks.
>
> **§23 Manual verification:** after tests pass, verify against the running local application/database with disposable data — single allocation (`WAITING → allocate_one → READY`, checking `QueueEntry.status`/`SeatingAssignment.status`/`seating_code`/assignment-table rows), combined allocation (both tables reserved by the same assignment), an occupied table (can't be stolen), rollback (no partial records survive a forced failure). Clean up afterward — do not disturb the 40-table seed configuration or existing project data.
>
> **§24 Do not connect allocation triggers:** do NOT modify guest join, release, no-show, or leave flows to automatically call allocation — that belongs to the next orchestration phase.
>
> **§25 Documentation:** update only what's necessary — at minimum the implementation status in `allocation-algorithm.md` and/or `allocation-spec.md`: transactional allocation implemented, one candidate per call, table locking, deterministic lock ordering, post-lock availability re-check, `QueueEntry` re-check, atomic 1/2-table reservation, `SeatingAssignment` status pending, `QueueEntry → READY`, `seating_code` generation, stale/concurrency-loss behavior. Do NOT claim trigger integration is complete.
>
> **§26 Traceability:** update `01-requirements/traceability.md` only for requirements actually satisfied this phase — clearly distinguish implemented (transactional reservation, atomic combined seating, pending assignment, `READY` transition) from deferred (automatic trigger integration, repeated allocation passes, staff confirmation, guest leave, release/no-show integration).
>
> **§27 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md` with this prompt, transaction design, lock ordering, concurrency behavior, tests, manual verification. If a genuine AI mistake occurs, update `ai-corrections.md`. Do not fabricate corrections.
>
> **§28 Important correction rule — STOP and correct if Claude proposes:** `Table.status = occupied`; locking only one table of a combined candidate; creating the assignment outside the transaction; skipping the post-lock availability check; silently choosing another candidate after a race; `QueueEntry waiting → seated`. These violate the finalized architecture or this phase boundary.
>
> **§29 Git:** review `git status`/`git diff`/`git diff --stat` — verify no frontend/Redis/Sidekiq/staff-APIs/guest-leave/trigger-integration/unrelated migrations/unrelated documentation changes; run allocation tests, transactional tests, full test suite, real PostgreSQL concurrency tests, manual verification; commit `feat: implement transactional allocation`; then `git status`/`git log --oneline --max-count=3`; working tree must be clean.
>
> **§30 Success criteria:** the 19-item checklist (transactional service implemented; existing `DecisionEngine` reused; at most one candidate per call; table(s) locked, multiple ids in ascending order; availability and `QueueEntry` re-checked after locking; `SeatingAssignment` created pending; 1–2 `SeatingAssignmentTable` rows, `released_at` stays `NULL`; `seating_code` generated per the approved contract; `QueueEntry` `WAITING → READY`; combined allocation atomic, partial impossible; real concurrency race tested; DB uniqueness constraint remains defense-in-depth; rollback leaves no partial records; existing tests green; new transactional tests pass; manual verification completed; documentation/AI-working-record/git checkpoint done).
>
> **§31 Strictly not implemented — confirm remain absent:** automatic allocation on join/release/no-show/leave, repeated allocation loop, staff confirmation API, staff seating workflow, guest leave API, Redis, Sidekiq, notifications, live updates, frontend, rate limiting, missed-opportunity tracking, fairness debt, predictive demand, runtime AI allocation.
>
> **§32 Final report format:** PASS/BLOCKED status; 1. Service (class, public method, responsibility); 2. Transaction Flow; 3. Locking (mechanism, order, availability re-check, `QueueEntry` re-check); 4. Atomicity (single and combined); 5. Concurrency (real PostgreSQL results); 6. Tests (Total/Passed/Failed/Skipped + critical tests); 7. Manual Verification (actual scenarios/results); 8. Database State (assignment status, entry status, row count, `released_at`, `seating_code`); 9. Documentation; 10. AI Working Record; 11. Git (commit/message/working tree); 12. Scope Verification (automatic trigger integration, repeated allocation passes, staff confirmation, guest leave, Redis, Sidekiq, notifications, frontend all confirmed deferred). End exactly with: "Phase 5B.5.3 is complete. Transactional allocation and atomic table reservation are implemented and verified. A selected candidate can safely become a pending SeatingAssignment with one or two reserved tables and QueueEntry → READY, with PostgreSQL concurrency protection and rollback guarantees. Automatic allocation triggers, repeated allocation passes, staff confirmation, and other Phase 5B.5.4+ functionality remain deferred. No Phase 5B.5.4+ functionality was implemented in this phase." STOP.

---

## Prompt 19 — Phase 5B.5.4: Allocation Trigger Integration + Repeated Allocation Orchestrator

**Source:** `Phase_5B_5_4_Allocation_Trigger_Integration_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** connects the already-tested `DecisionEngine`/`ConfigurationGenerator`/`ReservationService` to the real business events that should trigger allocation, and adds the repeated-allocation loop `allocation-algorithm.md` §12 always specified but Phase 5B.5.3 deliberately deferred (one candidate per `ReservationService` call only).

**Full text (condensed; all 41 numbered sections' substantive content preserved):**

> **§1 Read first:** `CLAUDE.md`, `allocation-algorithm.md`, `allocation-spec.md`, `functional-spec.md`, `api-spec.md`, `seating-allocation-policy.md`, `starvation-policy.md`, `test-strategy.md`, `domain-model.md`, `data-model.md`, `01-requirements/traceability.md`; inspect `backend/app/services/`, `app/services/allocation/`, `app/controllers/`, `app/models/`, `test/services/`, `test/controllers/`, `config/routes.rb`. Understand how Guest Join currently works and how `QueueEntry` state changes. Do NOT replace `DecisionEngine`/`ConfigurationGenerator`/`ReservationService` — already implemented and tested.
>
> **§2 Core goal:** `EVENT → Allocation Orchestrator → DecisionEngine → ReservationService → successful allocation → recompute current state → DecisionEngine again → ReservationService again → repeat until no allocation is possible`. The first phase where the system performs MULTIPLE allocations from one trigger; the candidate grid must be regenerated after every successful allocation.
>
> **§3 Important global-allocation rule:** do NOT do first-waiting-guest → first-available-table → allocate → next-guest. Every pass must use the current `WAITING` entries × current available configurations → global candidate grid → starvation filtering → scoring → deterministic winner → transactional reservation; then, after a successful reservation, refresh state, build a completely fresh grid, choose the next winner. Mandatory.
>
> **§4 Orchestrator:** a clear orchestration service (e.g. `Allocation::Orchestrator`/`Allocation::AllocateAvailable` — inspect the codebase and choose the appropriate name) responsible for triggering allocation, repeatedly calling `ReservationService`, stopping when no allocation is possible, stopping/recomputing correctly after concurrency loss, and returning a summary of allocations performed. Do NOT put scoring logic or database reservation logic into the orchestrator — it composes existing components.
>
> **§5 One pass vs. full orchestration:** `ReservationService` allocates at most ONE candidate; the new `Orchestrator` may invoke it repeatedly — loop: call `ReservationService`; on success, count it and continue; on `no_candidate`, stop; on `stale_candidate`/concurrency loss, recompute and continue safely; on unexpected error, propagate/fail — do not hide unexpected database failures.
>
> **§6 Fresh recomputation:** after every successful allocation, do NOT reuse the old candidate list — re-read current state and rebuild waiting entries, available configurations, and the candidate grid, then call `DecisionEngine` again. Required because the previous allocation changes available tables, available combined configurations, scarcity values, compatibility counts, candidate scores, the starvation pool, and possibly queue ordering.
>
> **§7 Scarcity must be recomputed:** consuming one table changes remaining groups' scarcity (e.g. 1/3 → 1/2) — the orchestrator must not cache candidate scores across passes; every pass recalculates them.
>
> **§8 Starvation must be recomputed:** derived from `now - joined_at`, never stored. For one orchestration call, pass a consistent `now` value if the current specification requires deterministic evaluation; if the operation takes significant time, inspect the existing policy before deciding whether `now` should stay fixed for the whole orchestration or refresh per pass. Do NOT invent a new starvation policy — document the chosen behavior if needed.
>
> **§9 Allocation events:** the approved trigger set is Guest Join, Release, No-show, Guest Leave — inspect the current specifications to confirm exact event semantics before changing code. These four may invoke the allocation orchestrator after their state-changing operation successfully commits.
>
> **§10 Transaction boundary for triggers:** do NOT call the orchestrator before the triggering state change is safely persisted — the trigger must see the committed/current state (e.g. Guest Leave must first become `LEFT`, then allocation evaluates the newly-free state; release → assignment released → allocation). Do not create an inconsistent intermediate state where allocation sees stale occupancy.
>
> **§11 Important transaction rule:** do not casually place the entire orchestration loop inside one giant database transaction — each `ReservationService` call already has its own atomic transaction. Preferred flow: trigger transaction/state change → commit → `Allocation::Orchestrator` → reservation transaction → commit → next pass → reservation transaction → commit. Inspect the existing service architecture first; if an existing trigger service already controls a transaction, do not introduce nested/duplicated transaction semantics without a clear reason.
>
> **§12 Guest Join integration:** existing behavior (201 new / 200 exact idempotent retry / 409 conflicting retry / 422 invalid group size) must remain correct. After a successful NEW join, `QueueEntry` is created `WAITING`, the allocation trigger may run, and if compatible capacity exists the entry may become `READY`, otherwise it remains `WAITING`. An idempotent retry of an already-existing join must NOT accidentally create another allocation — existing idempotency behavior must remain unchanged.
>
> **§13 Join response:** inspect the current API specification carefully — do NOT change the response contract simply because allocation may now happen. If the spec already defines READY response behavior, follow it; if a new join can synchronously become READY, verify what the approved API contract requires the endpoint to return. If this creates a genuine specification conflict: STOP, document the conflict, do not silently change the API.
>
> **§14 Release integration:** release assignment/tables → committed state → allocation orchestrator → fill newly available capacity. The released assignment's historical rows must remain (never delete `SeatingAssignmentTable` rows); set `released_at` per the existing release specification. Do not alter the release state machine beyond what the current specification requires.
>
> **§15 No-show integration:** two existing no-show paths — staff/manual, and READY expiration under DEC-015 — both eventually produce `QueueEntry → NO_SHOW` and release the assignment/table(s). After that release is committed, `Allocation::Orchestrator` may fill the newly available configuration. Do NOT introduce a background scheduler; READY expiration remains lazy, 5-minute configured timeout, auto `NO_SHOW`, tables released atomically — do not change DEC-015.
>
> **§16 Guest Leave:** inspect the current specification for the guest-leave operation. When a waiting/ready guest leaves, `QueueEntry → LEFT`; if the guest was `READY` (had reserved tables), release the assignment/tables → commit → allocation orchestrator; if only `WAITING`, no table release is required but the system may need to recompute since queue state changed. Follow the finalized domain/specification rules. Do NOT invent a new leave API if it hasn't yet been authorized by the current phase/specification. If Guest Leave is not yet specified sufficiently to implement safely: STOP that part, report the exact missing decision, continue only with explicitly supported triggers.
>
> **§17 READY expiration:** already defined (`READY` → after configured timeout → `NO_SHOW` → release tables → allocation), remains lazy. When an operation touches an overdue `READY` entry, it may transition it to `NO_SHOW` and release its tables per existing DEC-015 behavior; after that committed release, allocation may run. Do NOT add cron/Sidekiq/scheduler/background sweep in this phase.
>
> **§18 Repeated allocation loop (conceptual):** `allocations = []; loop { result = ReservationService.call(now: now); case result; when success: allocations << result, next; when no_candidate: break; when stale_candidate: next (regenerate/retry safely); else: raise/propagate }; return allocations` — but inspect the exact result objects `ReservationService` actually returns and use those rather than inventing incompatible result types.
>
> **§19 Termination guarantee:** must terminate when no compatible candidate remains, all available capacity is exhausted, or no `WAITING` entries remain. Do not create an infinite retry loop; a stale/concurrency result should retry only under a safe condition — if repeated stale results occur without state progress, protect against infinite looping. A reasonable safeguard is a bounded retry count for concurrency-loss cases, but do not introduce arbitrary limits that prevent normal multi-allocation behavior. Inspect the existing specifications and choose a defensible approach.
>
> **§20 No candidate is a normal result:** no `WAITING` entry, no available configuration, or no compatible pair → orchestration completes successfully with zero additional allocations. NOT an exception.
>
> **§21 Allocation summary:** return enough information for tests/future callers (e.g. `allocations_count`, `allocated_queue_entry_ids`, `assignment_ids`) using the repository's existing conventions; do not expose unnecessary internal scoring details through public APIs.
>
> **§22 Do not change DecisionEngine:** already tested with 155 tests — do not move scoring logic into the orchestrator, do not alter the fit/scarcity/aging formulas, starvation override, or tie-breaking unless a genuine specification contradiction is found; if one is found, STOP and report it.
>
> **§23 Do not change ReservationService:** already tested with 173 tests — do not duplicate its transaction logic or create another table-locking mechanism; the orchestrator should call it.
>
> **§24 Event ordering:** for every trigger — business state change → persistence/commit → allocation orchestration — ensuring allocation sees the state change that caused it (e.g. release table → commit → allocate next guest, never the reverse).
>
> **§25 Concurrency:** the orchestrator itself does not need to lock tables — `ReservationService` already provides `SELECT FOR UPDATE`, availability re-check, the unique DB constraint, and an atomic transaction. The orchestrator must simply react correctly to success/no_candidate/stale_candidate. Do not introduce global mutexes or application-wide locks.
>
> **§26 Important multi-allocation test:** Groups A=2/B=4/C=6 waiting, 2-seat/4-seat/6-seat available — calling the orchestrator should produce multiple appropriate allocations, each pass recomputing the candidate grid, no table reserved twice, all resulting assignments pending, allocated entries `READY`, no more compatible candidate when the loop finishes. Do not assert a particular outcome unless it follows from the locked scoring algorithm — use the actual formulas to determine expected winners.
>
> **§27 Scarcity recomputation test (critical regression):** construct a scenario where pass 1's winner changes scarcity values for pass 2; verify pass 2 uses newly calculated scarcity rather than cached scores.
>
> **§28 Combined-table recomputation test:** Group 8 + Group 4, available a standalone 4-seat plus a 4-seat adjacent pair — after one allocation consumes a table, the combined-configuration availability must be regenerated; verify stale configurations are not reused.
>
> **§29 Starvation test:** a protected waiting group and a non-protected waiting group — verify the starvation override remains effective across orchestration passes; do not implement starvation as a stored field.
>
> **§30 Guest Join tests:** existing tests must keep passing; add: join with no compatible table (201, stays waiting); join with compatible capacity (join → allocation → becomes ready); idempotent retry (no second entry, no second allocation); multiple joins (orchestrator creates no duplicate assignments).
>
> **§31 Release tests:** if release functionality already exists — release → allocation → next compatible group becomes ready; verify `released_at` populated, historical row remains, the newly allocated assignment is separate, no table double-booked.
>
> **§32 No-show tests:** no-show → release → allocation; also READY expiration → lazy expiration → no_show → release → allocation. Do not add background jobs.
>
> **§33 Leave tests:** if guest-leave functionality is already sufficiently specified/implemented — leave → state change → release if necessary → allocation; verify no duplicate allocation. If leave is not yet sufficiently specified, do not invent it — report it as deferred.
>
> **§34 API testing:** run the existing guest join/status API tests; if join can now synchronously produce READY, verify the actual response against the authoritative `api-spec.md`. Do not casually modify the API response shape.
>
> **§35 Documentation:** update `allocation-algorithm.md`, `allocation-spec.md`, `api-spec.md`, `01-requirements/traceability.md` only where necessary — clearly document Phase 5B.5.4 implementation status, trigger events, repeated allocation behavior, fresh recomputation after each success, stale-candidate handling, termination behavior. Do NOT claim staff confirmation is implemented.
>
> **§36 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md`; if a genuine AI mistake occurs, update `ai-corrections.md`. Do not fabricate corrections.
>
> **§37 Important correction rule — STOP and correct if Claude attempts to:** cache candidate scores across passes; allocate using `joined_at` order instead of `DecisionEngine`; bypass `ReservationService`; put table locking in the orchestrator; add Sidekiq/Redis; create a background READY-expiration sweep; silently change the API contract.
>
> **§38 Git:** review `git status`/`git diff`/`git diff --stat` — verify changes are limited to this phase; run allocation unit tests, reservation tests, orchestration tests, guest API tests, full test suite, real concurrency tests; commit `feat: integrate allocation triggers`; then `git status`/`git log --oneline --max-count=3`; working tree must be clean.
>
> **§39 Success criteria:** the 27-item checklist (orchestrator implemented; existing `DecisionEngine`/`ReservationService` reused; at most one reservation per `ReservationService` call; multiple allocations possible per orchestration call; candidate grid regenerated after every success; scarcity/aging/starvation recomputed every pass; no stale candidate list reused; no first-match/FIFO shortcut; no application-wide lock; no background scheduler/Redis/Sidekiq; Guest Join integrated if fully specified; Release integrated if already available; No-show integrated if already available; Guest Leave integrated only if sufficiently specified; trigger runs after required state change is committed; no-candidate is normal termination; concurrency-loss handling cannot loop forever; multi-allocation/scarcity/combined-recomputation/starvation tests pass; existing tests remain green; documentation/AI-working-record/git checkpoint done).
>
> **§40 Strictly not implemented — confirm remain absent:** staff confirmation API, staff seating workflow, staff authentication, Redis, Sidekiq, background notification jobs, notifications, live updates, frontend business flows, rate limiting, analytics, missed-opportunity tracking, fairness debt, predictive demand, runtime AI allocation.
>
> **§41 Final report format:** PASS/BLOCKED status; 1. Orchestrator (class, public method, responsibilities); 2. Trigger Integration (which of Guest Join/Release/No-show/Guest Leave were actually integrated, explicitly stating "deferred" for anything not sufficiently specified); 3. Repeated Allocation (pass 1 → reservation → fresh state → pass 2 → ... → no candidate → stop); 4. Recalculation (how availability/compatibility/scarcity/aging/starvation are recomputed); 5. Concurrency (how stale/concurrency-loss results are handled); 6. Tests (Total/Passed/Failed/Skipped + critical orchestration tests); 7. API Verification (guest join/status behavior and any response-contract implications); 8. Documentation; 9. AI Working Record; 10. Git (commit/message/working tree); 11. Scope Verification (staff APIs, Redis, Sidekiq, notifications, live updates, frontend, future fairness/AI functionality all confirmed deferred). End exactly with: "Phase 5B.5.4 is complete. Allocation trigger integration and repeated allocation orchestration are implemented and verified. Business events can now invoke the existing deterministic decision engine and transactional reservation service, with a fresh candidate grid recomputed after each successful allocation. Staff confirmation, Redis/Sidekiq, notifications, live updates, frontend business flows, and other Phase 5B.6+ functionality remain deferred. No Phase 5B.6+ functionality was implemented in this phase." STOP.

---

## Prompt 20 — Phase 5B.6: Staff Seating Confirmation

**Source:** `Phase_5B_6_Staff_Seating_Confirmation_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message.

**Session context:** the staff action that takes a READY reservation and confirms the guest has actually been seated — `QueueEntry: READY → SEATED`, `SeatingAssignment: PENDING → ACTIVE`. Allocation itself is already implemented (Phase 5B.5.x) and explicitly must not be reimplemented or re-invoked here.

**Full text (condensed; all 35 numbered sections' substantive content preserved):**

> **§1 Read first:** `CLAUDE.md`, `api-spec.md`, `functional-spec.md`, `allocation-spec.md`, `allocation-algorithm.md`, `domain-model.md`, `data-model.md`, `test-strategy.md`, `01-requirements/traceability.md`; inspect `backend/app/models/`, `app/services/`, `app/services/allocation/`, `app/controllers/`, `config/routes.rb`, `test/`, `db/schema.rb`. Look specifically for: existing `StaffUser` model, staff-authentication assumptions, `seating_code` field, `SeatingAssignment`/`QueueEntry` state, existing API/error conventions. Do not invent an architecture that conflicts with existing conventions.
>
> **§2 Phase boundary — implement ONLY** READY→staff-confirms→SEATED and `pending`→`active`. Do NOT implement: staff authentication system, staff registration, passwords/login/JWT, staff management, release endpoint, guest leave endpoint, notifications, Redis, Sidekiq, live updates, frontend, analytics, rate limiting, staff UI, table-management UI, new allocation algorithm/scoring, repeated allocation logic, runtime AI. If authentication is required by the spec but not yet implemented, do NOT build a complete authentication subsystem — use the existing documented authentication boundary or explicitly report that authentication remains deferred.
>
> **§3 Core business flow:** join → allocation → READY/PENDING → seating_code generated → guest sees code → staff enters code → validate READY/PENDING → SEATED/ACTIVE. The staff action must NOT allocate a table, must NOT select a different table, must NOT create another assignment — it only confirms the assignment allocation already created.
>
> **§4 API contract:** inspect the authoritative `api-spec.md` first — if the staff confirmation endpoint is already specified, follow it exactly; if not, do not silently invent a public contract (identify the missing decision, check related requirements, document a clearly-implied contract, or stop and report the ambiguity). Illustrative-only shape given: `POST /staff/.../seating/confirm` with `{ seating_code }` — the repository's authoritative spec wins.
>
> **§5 Seating code lookup:** the seating code is the lookup key, via the existing unique partial index/constraint (`seating_code WHERE seating_code IS NOT NULL`). Do NOT look up by `QueueEntry` id, phone number, `active_visit_token`, `idempotency_key`, or table id.
>
> **§6 Valid state:** confirmation is valid only when `QueueEntry.status == ready` AND `SeatingAssignment.status == pending`, both representing the same reservation. Expected transition: `ready → seated` / `pending → active`, atomically.
>
> **§7 Invalid states:** must NOT succeed for `WAITING`/`SEATED`/`LEFT`/`NO_SHOW` entries or a `RELEASED`/`ACTIVE` assignment — return the appropriate documented conflict/not-found response; don't invent a new error taxonomy if one already exists.
>
> **§8 Atomic transaction:** one transaction — begin, locate by `seating_code`, lock relevant rows, re-check `assignment.status == pending` and `queue_entry.status == ready`, update assignment→active and entry→seated, commit; rollback on any failure. Never leave `assignment=active`+`queue_entry=ready` or `assignment=pending`+`queue_entry=seated` after a successful transaction.
>
> **§9 Concurrency:** two staff requests submitting the same code near-simultaneously — A locks, transitions, commits; B waits for the lock, re-checks, sees already SEATED/ACTIVE, does NOT perform a second transition. Only one confirmation succeeds; the second gets the appropriate conflict/already-confirmed response. No application-level mutexes — PostgreSQL row locking and the existing transaction model only.
>
> **§10 Locking:** inspect domain relationships and lock the minimal correct rows — at minimum the `SeatingAssignment` and `QueueEntry` state transitions must be protected; deterministic lock ordering if multiple rows are locked; do not lock tables unnecessarily (they're already reserved by the pending assignment — confirmation is a state transition, not a new allocation).
>
> **§11 Table occupancy:** confirmation must NOT change `Table` records — do NOT add `Table.status = occupied`. Occupancy remains derived from `SeatingAssignmentTable`; the `pending → active` transition is what changes the *derived* table state `held → occupied`. The table relationship itself is unchanged.
>
> **§12 Assignment-table rows:** confirmation must NOT create new `SeatingAssignmentTable` rows. Existing rows stay `released_at = NULL`; historical rows are never deleted; for a combined assignment, both table rows remain attached to the same assignment.
>
> **§13 Seating code:** confirmation must not generate a new code — it consumes the one already generated during allocation. Do NOT regenerate/replace/mutate/normalize into a different public format unless the API spec explicitly requires it.
>
> **§14 Idempotency/repeated confirmation:** must be safely repeatable without creating duplicate state — a second request with the same code, once already `SEATED`/`ACTIVE`, gets a conflict/already-confirmed response; must not create another assignment, change tables, create another assignment-table row, or generate another code. Follow the API's documented status/body for repeated confirmation.
>
> **§15 Staff authentication:** inspect the existing `StaffUser` model/spec. If authentication is already available, use it; if not, do NOT create a complete authentication system in this phase — implement the business operation behind the project's existing authentication boundary/placeholder as documented, and clearly report authentication status in the final report. Do not weaken the domain logic just because authentication is deferred.
>
> **§16 Service boundary:** a focused service if the architecture supports service objects (e.g. `Staff::ConfirmSeatingService`/`Seating::ConfirmService` — choose a name consistent with the repository), owning seating-code lookup, locking, state validation, and the atomic transition. Controller stays thin — no transaction/business logic directly in it.
>
> **§17 Model state transitions:** do not use unrestricted `update_column` or similar bypasses merely to force a transition — respect existing domain validation/state model; use explicit transition methods if they exist, or the smallest appropriate domain validation consistent with existing patterns if not. Do not redesign all state machines in this phase.
>
> **§18 API response:** follow `api-spec.md` exactly; communicate confirmed seating state without exposing internal lock/transaction/scoring/allocation internals. If the spec is missing a response shape, resolve from existing requirements or report the ambiguity rather than inventing one.
>
> **§19 Error cases (at minimum):** unknown code (documented not-found); code belongs to WAITING (cannot confirm); code belongs to already-SEATED (already confirmed/conflict); code belongs to LEFT (cannot confirm); code belongs to NO_SHOW (cannot confirm); assignment already ACTIVE (cannot confirm again); assignment RELEASED (cannot confirm). Use the existing API error conventions, don't invent a new taxonomy.
>
> **§20 Transaction rollback test:** a controlled failure after one state update but before the second — verify `QueueEntry` remains READY and `SeatingAssignment` remains PENDING, no partial transition (never READY+ACTIVE or SEATED+PENDING).
>
> **§21 Concurrency test:** real PostgreSQL, two real threads/connections, same `seating_code` — exactly one successful confirmation, exactly one conflict/already-confirmed result, final state SEATED/ACTIVE, no duplicate rows. Not mocked locks.
>
> **§22 Combined-table test:** a READY reservation backed by two tables, confirmed — one `QueueEntry`→SEATED, one `SeatingAssignment`→ACTIVE, two `SeatingAssignmentTable` rows remain with `released_at = NULL`, both still associated with the same assignment.
>
> **§23 Table state test:** before confirmation, `pending`/`released_at NULL`/derived `held`; after, `active`/`released_at NULL`/derived `occupied`. `Table` itself never modified.
>
> **§24 Guest status API integration:** after successful confirmation, `GET /guest/queue-entries/current` for that guest reflects `status = seated`, following the existing documented terminal-state shape; verify the read itself doesn't allocate another table, create another assignment, or modify unrelated entries.
>
> **§25 No allocation side effect:** staff confirmation must NOT call `Allocation::DecisionEngine`, `Allocation::Orchestrator`, or `Allocation::ReservationService` — confirmation does not allocate, it only confirms an already-allocated reservation. Release/allocation-after-release belongs to a later phase.
>
> **§26 Test suite (19 items, at minimum):** successful READY→SEATED; successful PENDING→ACTIVE; unknown code; WAITING/SEATED-again/LEFT/NO_SHOW/RELEASED-assignment/ACTIVE-assignment cannot be confirmed; repeated same-code request doesn't duplicate state; atomic transition; forced rollback; real concurrent race; combined 2-table confirmation; guest current-status shows SEATED after confirmation; no additional assignments/assignment-table rows/Table changes; existing 187+ suite stays green.
>
> **§27 API integration tests:** the actual HTTP endpoint against the real database — valid code, invalid code, invalid state, repeated confirmation, concurrent confirmation; verify HTTP status, response body, and database state. Not service-unit-tests-only.
>
> **§28 Manual verification (10 steps):** join a guest, let allocation produce READY, obtain the `seating_code` via guest status, call staff confirmation, verify `QueueEntry`=seated/`SeatingAssignment`=active/assignment-table rows intact/`released_at` NULL, call guest status again (=seated), repeat staff confirmation (no duplicate state, documented conflict), verify the 40-table seed baseline remains intact. Disposable data, cleaned up afterward.
>
> **§29 Documentation:** update `api-spec.md`, `01-requirements/traceability.md`, and (if needed) `functional-spec.md` only — document the endpoint, request/response, READY/PENDING preconditions, both transitions, concurrency behavior, repeated-confirmation behavior, authentication status. Do NOT document release as implemented; do NOT document staff authentication as implemented unless it actually is.
>
> **§30 AI working record:** update `agent-prompts.md`, `session-log.md`, `agent-decisions.md`; if a genuine AI mistake occurs, update `ai-corrections.md`. Do not fabricate corrections.
>
> **§31 Important correction rule — STOP and correct if Claude attempts to:** create a new `SeatingAssignment` during confirmation; create new `SeatingAssignmentTable` rows; allocate another table; change `Table.status`; generate a new `seating_code`; call `Allocation::Orchestrator`; add Sidekiq/Redis; silently build staff authentication.
>
> **§32 Git:** review `git status`/`git diff`/`git diff --stat` — verify changes limited to Phase 5B.6; run staff confirmation service tests, API integration tests, concurrency tests, guest status integration tests, full test suite; commit `feat: implement staff seating confirmation`; then `git status`/`git log --oneline --max-count=3`; working tree must be clean.
>
> **§33 Success criteria:** the 24-item checklist (service implemented; authoritative API contract followed; `seating_code` lookup; READY/PENDING validated; both transitions correct and atomic; PostgreSQL row locking used; concurrent race tested, exactly one succeeds; combined assignments confirmed correctly; existing assignment-table rows preserved, `released_at` stays `NULL`; `Table` records unmodified; no new assignment/seating_code/allocation; repeated confirmation handled correctly; guest current-status reflects SEATED; HTTP integration tests pass; full suite green; manual verification/documentation/AI-working-record/git checkpoint done).
>
> **§34 Strictly not implemented — confirm remain absent:** staff authentication system, staff registration, staff management, staff UI, release endpoint, guest leave endpoint, automatic allocation after release, Redis, Sidekiq, notifications, live updates, frontend, rate limiting, analytics, missed-opportunity tracking, fairness debt, predictive demand, runtime AI allocation.
>
> **§35 Final report format:** PASS/BLOCKED status; 1. Endpoint (method, route, request, success/error responses); 2. Service (class, public method, responsibilities); 3. State Transition; 4. Transaction (lookup/locks/validation/updates/commit-rollback); 5. Concurrency (real PostgreSQL results); 6. Tests (Total/Passed/Failed/Skipped + critical tests); 7. API Verification (real HTTP); 8. Guest Status Verification; 9. Documentation; 10. AI Working Record; 11. Git (commit/message/working tree); 12. Scope Verification (release, guest leave, staff authentication, notifications, Redis/Sidekiq, frontend, future functionality all confirmed deferred). End exactly with: "Phase 5B.6 is complete. Staff seating confirmation is implemented and verified. A READY reservation can be atomically confirmed by seating_code, transitioning QueueEntry from READY to SEATED and SeatingAssignment from PENDING to ACTIVE, with concurrency protection and no new allocation or table reservation. Release, guest leave, staff authentication, notifications, live updates, frontend, and other Phase 5B.7+ functionality remain deferred. No Phase 5B.7+ functionality was implemented in this phase." STOP.

---

## Prompt 21 — P0 Completion Mode: Guest Join Frontend Vertical Slice

**Source:** `Claude_Prompt_P0_Guest_Join_Vertical_Slice.md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message. Not numbered "Phase 5B.x" like every prior prompt — framed instead as "P0 COMPLETION MODE," explicitly a single, narrowly-scoped checkpoint task, not the start of a new numbered phase sequence.

**Session context:** the project's first frontend implementation since the Phase 5A bootstrap stub (a health-check-only screen). Target: `Browser → React frontend → POST /guest/queue-entries → Rails backend → PostgreSQL → existing allocation logic → real API response → React UI`, proving the existing backend/database/allocation/frontend work together as a real running MVP — using the backend exactly as it already exists, no backend changes.

**Full text (condensed; all 12 numbered steps' substantive content preserved):**

> **Step 1 — Inspect before coding:** read `CLAUDE.md`, `api-spec.md`, `functional-spec.md`, relevant requirements/traceability docs, current frontend structure, the existing guest join controller/service, current routes, current database/schema, existing frontend API/client setup; inspect current git status. Do not assume previous phase reports are correct without checking the actual repository. Before changing anything, briefly state: current frontend structure; existing guest join API; how the frontend should call it; files to be modified. Then implement.
>
> **Step 2 — Build only the Guest Join screen:** a simple functional screen (illustrative mockup: "Restaurant Waitlist / Group Size [2] / Phone Number [___] / [Join Queue]"). No visual polish required. Use the existing frontend technology/conventions; do not introduce unnecessary libraries; simple state management unless an established pattern already exists to reuse.
>
> **Step 3 — Connect to the existing API exactly:** `POST /guest/queue-entries`, never renamed/redesigned, using the existing contract from `api-spec.md`. Request must include `group_size`, `phone_number`, and a client-generated `idempotency_key`. Do not fabricate backend behavior.
>
> **Step 4 — Handle UI states, at least:** Initial (show the form); Loading (disable submit, show "Joining…"); Success–WAITING (display the actual backend response: "Status: WAITING / Position: \<actual position\>"); Success–READY (if allocation happens immediately: "Status: READY / Seating code: \<actual seating code\>"); Error (validation errors, API errors, network/backend unavailable, idempotency conflict where applicable). Keep the UI simple.
>
> **Step 5 — Do NOT change existing backend logic:** do not modify the allocation algorithm, `DecisionEngine`, `ReservationService`, `Orchestrator`, the domain model, migrations, database constraints, seating confirmation logic, staff functionality, authentication, Redis, Sidekiq, notifications, live updates, Guest Leave, Staff Release, Staff No-show. Reuse the existing backend as-is. If an actual integration defect is discovered that makes the frontend impossible to connect, STOP and report it before expanding scope — do not silently redesign backend behavior.
>
> **Step 6 — Run the application:** actually run it locally; verify PostgreSQL, Rails backend, and frontend are all running; use the real browser/UI. Do NOT consider the task complete based only on unit tests.
>
> **Step 7 — Real end-to-end verification:** perform the exact browser flow (open browser → enter group size → enter phone number → click Join Queue → React sends `POST /guest/queue-entries` → Rails processes → `QueueEntry` persisted → existing allocation runs if applicable → API returns actual state → React displays actual state) and verify the browser result.
>
> **Step 8 — Verify the API:** inspect the actual HTTP request/response; report the request, request body (redacting sensitive info if applicable), response status/shape; then separately verify `GET /guest/queue-entries/current` using the appropriate existing auth/token mechanism. The frontend result and the API result must agree.
>
> **Step 9 — Inspect the real database (mandatory):** after the browser join, inspect actual PostgreSQL data — verify `QueueEntry` has `id`/`group_size`/`phone_number`/`idempotency_key`/`active_visit_token`/`joined_at`/`status`; if allocation occurred, also verify `SeatingAssignment` (exists, correct `queue_entry_id`, `status = pending`), `QueueEntry.status = ready`, the seating code exists and is persisted, and `SeatingAssignmentTable` (correct table row(s), `released_at = NULL`). Do not rely only on Rails test fixtures — verify the real running database. Use disposable data, cleaned up afterward, without disturbing the 40-table seed baseline.
>
> **Step 10 — Run tests:** relevant frontend tests, backend tests, and/or the existing full suite as appropriate. Do NOT rewrite the existing 214 tests; the existing backend suite must remain green. If a test fails because of the frontend implementation, diagnose and fix it; if an unrelated pre-existing test fails, report it clearly rather than hiding it.
>
> **Step 11 — Documentation:** update ONLY the necessary existing documentation — at minimum, if applicable, `api-spec.md`, `01-requirements/traceability.md`, `agent-prompts.md`, `session-log.md`, `agent-decisions.md` — add only a concise implementation-status note. Do NOT perform another large specification audit; do NOT create another large architecture document. Keep documentation accurate, concise, current, consistent with actual implementation.
>
> **Step 12 — Git checkpoint:** before committing, show `git status`, `git diff --stat`, `git diff -- <relevant files>`; report files created/modified, tests, browser verification, API verification, database verification, documentation changes. Only after successful verification, commit `feat: add guest join frontend`, then push the commit to the configured GitHub remote, then verify `git status` and `git log --oneline --max-count=3`; the working tree should be clean.
>
> **Important scope rule:** STOP after this vertical slice is successfully implemented, locally verified, documented, committed, and pushed. Do NOT automatically continue with Guest Leave, Staff Queue, Staff Release, Staff No-show, staff frontend, staff authentication, Redis, Sidekiq, live updates, notifications, or P1 work — those are separate, future, focused tasks after human review of this checkpoint.
>
> **Final report format:** Status (PASS/BLOCKED); Frontend (files created/modified, screen implemented, API integration); API Verification (endpoint, request, response, HTTP status); Database Verification (`QueueEntry`/`SeatingAssignment`/`SeatingAssignmentTable` results); Tests (relevant tests, total passed/failed/skipped); Browser Verification (actual browser flow and result); Documentation (modified files); Git (commit hash, message, push result, working tree status); Scope (explicit confirmation no other P0/P1 functionality was implemented). End with "STOP HERE AND WAIT FOR THE NEXT TASK."

---

## Prompt 22 — P0 Task: Guest Leave

**Source:** `P0_Guest_Leave_Claude_Prompt.md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message. Continues the same "P0 completion mode" framing as Prompt 21, not a numbered "Phase 5B.x."

**Session context:** the fourth and final approved allocation trigger (Guest Leave — Guest Join, Release, No-show, and Guest Leave were the four named in Phase 5B.5.4; Release and Guest Leave were both deferred there because neither had an implemented code path yet). This prompt authorizes building the Guest Leave endpoint itself and wiring it to `Allocation::Orchestrator`, plus the corresponding frontend "Leave Queue" button.

**Full text (condensed; all 13 numbered steps' substantive content preserved):**

> **Objective:** implement Guest Leave as the next P0 feature. ONLY Guest Leave — do not implement staff functionality or any other remaining P0/P1 feature.
>
> **Step 1 — Inspect first:** read `CLAUDE.md`, `api-spec.md`, `functional-spec.md`, `functional-requirements.md`, `01-requirements/traceability.md`, the existing Guest Join implementation, the existing `QueueEntry` model/state transitions, existing allocation/orchestration services, the existing guest current-status endpoint, the current frontend Guest Join implementation, current routes, existing tests. Do not assume previous reports are correct without checking actual code. Before implementing, briefly report: required Guest Leave behavior from specifications; existing state-transition rules; whether a Guest Leave API already exists; what happens to an existing READY reservation; what happens to reserved tables; what allocation trigger should happen after leaving; exact files expected to be modified. Then implement.
>
> **Step 2 — Backend API:** use the route and request/response contract already defined by the authoritative API spec — do NOT invent a new route if one is already defined. Use the existing active-visit-token mechanism; the guest must only be able to leave their own active visit. Do NOT use phone number, database id, or idempotency key as identity/authentication — use `Authorization: Bearer <active_visit_token>`.
>
> **Step 3 — State rules:** respect the existing `QueueEntry` state machine; determine exact valid Guest Leave states from the authoritative spec. At minimum verify `WAITING → LEFT` and `READY → LEFT`; any associated pending reservation must be released correctly and atomically. Do NOT invent a new state, do NOT add `ready → waiting`, do NOT change the existing state machine.
>
> **Step 4 — Allocation after leave:** if Guest Leave releases a table reservation, trigger the existing allocation mechanism per the established architecture — reuse `Allocation::Orchestrator` and existing reservation/decision infrastructure, do NOT implement another allocation algorithm. Verify another eligible waiting guest can be considered after the table is released. Do not modify compatibility rules, fit score, scarcity, aging, starvation protection, combined-table rules, or transaction/concurrency guarantees.
>
> **Step 5 — Repeated leave:** follow the existing specification for repeated leave requests; test them. A guest must not create another `QueueEntry`, create another `SeatingAssignment`, release another guest's tables, or trigger unintended repeated state changes.
>
> **Step 6 — Security/isolation:** test that Guest A cannot leave Guest B's visit using Guest B's token; also test missing token, invalid token, expired/inactive token if applicable, terminal state, already-left guest. Use existing project error semantics — do not invent a new authentication system.
>
> **Step 7 — Transaction/atomicity:** for a READY leave, ensure `QueueEntry` + `SeatingAssignment` + `SeatingAssignmentTable` rows + the allocation trigger behave consistently per the existing transactional architecture. For a combined reservation, both tables must be released — never partially. Add a forced-failure test where appropriate to prove rollback. Do not weaken the existing DB-level exclusivity constraint.
>
> **Step 8 — Frontend:** update the existing Guest UI only enough to support Guest Leave — do NOT redesign the frontend. Add a simple "[ Leave Queue ]" action when the guest is in a state where leaving is allowed; the UI should call the real API, show loading/success/error states, update the current guest status, and never fabricate position/status. Use existing frontend conventions from Guest Join; do not add unnecessary dependencies.
>
> **Step 9 — Tests (15 items, at minimum):** WAITING→LEFT; READY→LEFT; invalid token; missing token; cross-guest token isolation; repeated leave; terminal-state leave; a READY reservation releases its table; a combined reservation releases both tables; release is atomic; allocation can use a table released by Guest Leave; no unrelated `QueueEntry` is modified; no unrelated table is released; real HTTP endpoint behavior; frontend behavior if a frontend test mechanism already exists (do NOT add a new frontend testing framework merely for this task). Keep the existing backend suite green.
>
> **Step 10 — Real application verification:** do NOT consider this complete based only on tests — run PostgreSQL, Rails backend, and frontend; use real disposable data. Perform Flow A (join → WAITING → leave → LEFT, verify the real DB), Flow B (join → READY → seating code shown → leave → LEFT; verify `QueueEntry=LEFT`, `SeatingAssignment=RELEASED`, `released_at` populated, the reserved table becomes available; for a combined assignment verify both tables), and Flow C (Guest A receives a table, Guest B is waiting; Guest A leaves → table released → allocation runs → Guest B considered; verify the real DB state).
>
> **Step 11 — Database verification:** inspect actual PostgreSQL, not just fixtures. Report `QueueEntry` status before/after, `SeatingAssignment` status before/after, `SeatingAssignmentTable` table ids and `released_at`; confirm other/unrelated waiting entries were not modified unexpectedly; confirm the 40-table/19-adjacency seed baseline remains intact after cleanup.
>
> **Step 12 — Documentation:** update only necessary existing documentation — likely `api-spec.md`, `01-requirements/traceability.md`, AI working records if required. Document the Guest Leave endpoint, state transitions, reservation-release behavior, allocation-trigger behavior, implementation status. Do NOT perform another large documentation consistency audit; do NOT rewrite unrelated specifications.
>
> **Step 13 — Git checkpoint:** before committing, show `git status`/`git diff --stat`/`git diff -- <relevant files>`; run relevant tests/verification first; then commit `feat: implement guest leave`. Do NOT push yet if no GitHub remote is configured — if a remote already exists and the environment is authenticated, report that fact; if no remote exists, simply report "GitHub push not performed because no remote is configured." Do not fabricate a push. The commit itself should still be created if all verification passes.
>
> **Scope guard — extremely important, do NOT implement:** Staff Login, Staff Queue, Staff Table API, Staff UI, Staff Release, Staff No-show, staff authentication, Redis, Sidekiq, WebSockets, notifications, live updates, rate limiting, analytics, P1 features, future AI functionality, changes to allocation scoring, changes to the domain model unless absolutely required by an already-approved P0 specification. If another feature appears necessary, STOP and report the dependency rather than implementing it automatically.
>
> **Final report format:** Status (PASS/BLOCKED); Backend (endpoint, service, state transition, allocation trigger); Frontend (UI changes, states handled); Tests (new tests, total/passed/failed/skipped); API Verification (real HTTP request/response, important status codes); Browser Verification (actual Guest Leave flow); Database Verification (important before/after state); Concurrency/Atomicity (relevant verification); Documentation (changed documents); Git (commit hash, message, remote/push status, working tree status); Scope (explicit confirmation no other P0/P1 functionality was implemented). End with "STOP HERE AND WAIT FOR THE NEXT TASK."

---

## Prompt 23 — P0 Task: Staff Login Stub

**Source:** `P0_Staff_Login_Exact_Claude_Prompt.md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message. Continues "P0 completion mode." Notes the GitHub repository is now public and current work has been pushed — verified independently (`git fetch origin` + `git log origin/main`) rather than trusted blindly, per this project's own standing rule and this prompt's own "do not rely blindly on previous AI reports" instruction.

**Session context:** the minimum authentication boundary needed by `POST /staff/seat` (Phase 5B.6, previously unauthenticated) and any future Staff P0 API. Explicitly a stub — REQ-STAFF-001 accepts stub-strength auth — not a production auth system.

**Full text (condensed; all numbered sections' substantive content preserved):**

> **§1 First: inspect, do not code.** Read `CLAUDE.md`, `functional-requirements.md`, `acceptance-criteria.md` if present, `01-requirements/traceability.md`, `api-spec.md`, `functional-spec.md`, the existing `StaffUser` model, existing staff routes/controllers/services, the existing `POST /staff/seat`, current authentication-related code, current frontend structure, existing tests. Specifications and repository are the source of truth — do not rely blindly on previous AI reports. Before coding, determine: what exactly P0 requires for Staff Login; whether a login endpoint is already specified; the exact request/response fields; whether this is explicitly a stub/demo mechanism; how the authenticated staff identity should be passed to future Staff APIs; whether P0 requires a Staff Login screen; which existing `StaffUser` fields to use; exact files to change. Then implement the smallest solution that satisfies the existing P0 specification.
>
> **§2 Do not invent a production auth system.** Do NOT add anything the specification doesn't require. Do NOT implement OAuth, Google login, SSO, MFA, registration, password reset, email verification, refresh-token infrastructure, a roles/permissions system, Redis, Sidekiq, WebSockets, notifications, live updates. Do NOT introduce JWT/session infrastructure unless the authoritative specification explicitly requires it. If the specification is ambiguous about an important authentication decision, STOP and report the ambiguity instead of inventing a product decision.
>
> **§3 Staff user/credentials.** Use the existing `StaffUser` model; do not redesign the domain model unless the approved P0 spec requires it. If passwords are required: use the existing bcrypt/`has_secure_password` mechanism already present, never store plaintext, never return password hashes, never log passwords, never hardcode a real credential. If the specification defines a stub credential or seeded staff user, follow it exactly; if it does not, do not silently invent one.
>
> **§4 Login API.** Implement the exact endpoint already defined in the authoritative `api-spec.md` — do NOT invent a different route. Follow the existing specification exactly for HTTP method, URL, request body, success status, success response, invalid-credential status, error response. The login response must contain only the authentication information explicitly required — never password/hash/unnecessary database internals. Keep Guest authentication separate from Staff authentication; a guest `active_visit_token` must never authenticate a staff user.
>
> **§5 Staff authentication boundary.** The purpose of this task is to establish the minimum authentication boundary needed by subsequent Staff P0 APIs. Inspect the existing `POST /staff/seat` — if the authoritative specification says the login mechanism must protect it now, apply the minimum required check; if the specification explicitly leaves it unauthenticated until a later Staff phase, do NOT change it. Do not implement any other Staff endpoint.
>
> **§6 Frontend.** Only build a Staff Login screen if the authoritative P0 requirements explicitly require it. If required, keep it minimal and consistent with the existing React app (illustrative mockup: "Staff Login / [ credential ] / [ Login ] / loading state / error state / success/authenticated state"). It must call the real backend — do not fake successful login. Do not add frontend authentication libraries; do not redesign the existing Guest UI; do not build a Staff Queue/Table/Release/No-show screen.
>
> **§7 Tests.** At minimum, test the applicable cases: valid login succeeds; invalid credentials fail; missing credentials fail; unknown staff user fails; password/hash is never returned; the authenticated staff identity is represented correctly; repeated valid login behaves correctly; a guest token cannot authenticate as staff; HTTP endpoint behavior; existing Staff-endpoint authentication behavior, only if the specification requires it. Do not introduce a new test framework. Run the full existing backend suite after implementation.
>
> **§8 Real API verification.** Do not consider this complete based only on unit tests — run the real Rails backend against the real PostgreSQL dev database. Verify a valid login (credentials → login endpoint → successful response), an invalid login (invalid credentials → authentication failure), and guest/staff isolation (a guest `active_visit_token` must NOT authenticate as staff). Do not report or paste actual passwords/tokens in the final report.
>
> **§9 Database verification.** Inspect the real database — `StaffUser` exists as expected, credential storage is safe, no plaintext password exists, no unrelated `QueueEntry` is changed, no `SeatingAssignment` is created, no table is reserved/released, the 40-table/19-adjacency baseline remains intact. Use disposable test data where needed and clean it afterward.
>
> **§10 Secret safety.** Because the GitHub repository is public, check before committing: `git status`; `git ls-files | grep -Ei '(^|/)\.env($|\.)|master\.key|\.pem$|\.key$'`; `git check-ignore -v backend/config/master.key`. Do not commit `backend/config/master.key`, `.env` files containing secrets, API tokens, passwords, or private keys. Do not modify `.gitignore` unnecessarily.
>
> **§11 Documentation.** Update only the necessary authoritative documentation — likely `api-spec.md`, `01-requirements/traceability.md`. Update AI working records only per the project's existing convention. Do NOT perform a broad documentation rewrite; do NOT rewrite historical documents.
>
> **§12 Git.** Before committing: `git status`, `git diff --stat`, `git diff -- <relevant files>`. Run the complete backend suite; if frontend code changed, run the existing frontend type/lint checks. Create ONE focused commit: `feat: implement staff login`. Do NOT push automatically. Report the commit hash and working-tree state.
>
> **Strict scope — do NOT implement:** Staff Queue, Staff Table View, Staff No-show, Staff Release, Staff management, staff registration, password reset, production-grade authentication, OAuth, SSO, MFA, Redis, Sidekiq, WebSockets, notifications, live updates, rate limiting, analytics, P1 functionality, AI/runtime allocation, allocation algorithm changes, domain model redesign. If another feature is discovered to be required as a dependency: STOP and report the dependency, do not implement it automatically.
>
> **Final report format:** Status (PASS/BLOCKED); What was implemented (short summary); API (exact endpoint, request shape, success response shape, authentication-failure behavior); Authentication (mechanism used, how `StaffUser` is used, how future Staff APIs can identify the authenticated staff user); Frontend (whether a Staff Login screen was required by P0 and whether it was implemented); Tests (new/total/passed/failed/skipped); Real Verification (real HTTP/database verification); Security (confirm no password/token/secret was committed); Documentation (modified documents); Git (commit hash, message, working tree status, push status); Scope (explicit confirmation Staff Queue, Staff Tables, Staff Release, Staff No-show, Redis, Sidekiq, live updates, notifications, and other P1 work were NOT implemented). End with "STOP AFTER THIS TASK."

---

## Prompt 24 — P0 Task: Staff Queue Vertical Slice

**Source:** `P0_Staff_Queue_Claude_Prompt(1).md` (candidate-authored, read from `~/Downloads/`), delivered complete in a single message. Continues "P0 completion mode," listing the current state as of the prior commit (`2432597 feat: implement staff login`) and requiring the plan-first, then-implement workflow already established for prior P0 tasks.

**Full text (condensed; all numbered sections' substantive content preserved):**

> **§1 Current state.** Already implemented and verified: domain model + migrations + constraints + 40-table seed, Guest Join API, Guest Current Status API, Guest Leave API, Allocation Decision Engine, transactional allocation, Allocation Orchestrator/triggers, Staff Login API + authentication, Staff Login frontend, Staff Seating Confirmation API, Guest Join/Leave frontend, real API/browser/PostgreSQL verification. Latest commit `2432597 feat: implement staff login`; working tree expected clean.
>
> **§2 Before coding — inspect the project.** Read `CLAUDE.md`, `functional-requirements.md`, `acceptance-criteria.md`, `traceability.md`, `api-spec.md`, `functional-spec.md`, `allocation-spec.md`, the existing `Staff::BaseController`, existing Staff Login implementation, `StaffUser`, `QueueEntry`, `SeatingAssignment`, `SeatingAssignmentTable`, current routes, existing frontend structure, existing tests. Determine the exact Staff Queue contract from the repository. Do not invent a new product requirement if the specification already defines it.
>
> **§3 First give a short plan.** Before editing files, state: the exact Staff Queue endpoint from the specification; the exact authentication requirement; the exact response shape; which queue states are visible to staff; required ordering/position semantics; whether READY entries expose seating code/table information; whether a Staff Queue frontend screen is required; files to be changed. Then proceed directly with implementation — do not ask product questions unless the authoritative specifications genuinely contain a blocking contradiction.
>
> **§4 Backend — Staff Queue API.** Implement the exact Staff Queue endpoint already specified in `api-spec.md`. Use the existing Staff authentication mechanism — do not create another authentication system. The endpoint must: require a valid Staff authentication token; reject missing/invalid Staff authentication with the specified 401 response; reject a Guest `active_visit_token`; read real PostgreSQL data; return exactly the fields specified by the API contract; follow the specified ordering; follow the specified queue-state visibility. Do not hardcode any queue data. Do not modify the domain model unless the specification explicitly requires a missing piece.
>
> **§5 Queue semantics.** Use the existing state machine (`waiting → ready → seated`, `waiting/ready → left/no_show`) — do not introduce new states. If Staff Queue requires WAITING position, use the already-established position semantics; do not create a stored position column; do not duplicate the allocation algorithm. **Queue position is not allocation priority** — the allocation engine remains the single authority for allocation decisions.
>
> **§6 READY entries.** If the specification requires READY entries in Staff Queue: use the existing `SeatingAssignment`/`SeatingAssignmentTable`, return the existing `seating_code`, return table IDs only if specified, never generate another seating code, never create another reservation, never allocate another table. A Staff Queue read must not perform new allocation. If the authoritative specification requires DEC-015 lazy expiration to be evaluated by this read, reuse the existing expiration mechanism — do not create a second expiration implementation.
>
> **§7 Read-only requirement.** The Staff Queue API is a read operation. It must not accidentally: create `QueueEntry`/`SeatingAssignment`/`SeatingAssignmentTable` rows, allocate tables, release tables, change `waiting` to `ready`, change `ready` to `seated`, alter unrelated entries. The only permitted state mutation is an already-specified DEC-015 lazy-expiration side effect, if the specification explicitly requires it.
>
> **§8 Tests.** Add focused backend tests covering: valid/missing/invalid Staff authentication, a Guest token used as a Staff token, empty queue, one WAITING entry, multiple WAITING entries, a READY entry, mixed WAITING/READY entries, ordering, position semantics if required, terminal-state filtering if required, correct response shape, no unintended allocation, no unintended reservation creation, DEC-015 lazy expiration if required. Use the existing test framework — do not add a new one. Run the complete backend test suite; all existing tests must remain green.
>
> **§9 Frontend — Staff Queue screen.** Only if the authoritative P0 requirements require it. Use the existing frontend architecture — do not redesign the application. The screen must call the real Staff Queue API using the authenticated Staff session. Implement only: loading, successful queue display, empty queue, API/authentication error. Display only information specified by the requirements. Do not hardcode queue entries, positions, seating codes, table IDs, or statuses. Do not create Staff Table, Release, or No-show UI.
>
> **§10 Real browser verification.** After implementation, run the real application. Verify: Staff Login still works; after login, `Staff Login → Staff Queue` displays real data from PostgreSQL; using disposable data, verify a WAITING guest appears correctly, a READY guest appears correctly, an empty queue behaves correctly, ordering is correct, and invalid Staff authentication is rejected. Do not use mocked API responses.
>
> **§11 Real API verification.** Verify the actual running backend with real HTTP requests: an authenticated Staff request succeeds; an unauthenticated request fails; a Guest token fails as Staff authentication; the response matches the specification; returned queue data matches PostgreSQL. Do not expose passwords or bearer tokens in the final report.
>
> **§12 Database verification.** Inspect the real PostgreSQL database. Confirm the Staff Queue response corresponds to real `QueueEntry`/`SeatingAssignment`/`SeatingAssignmentTable`/`Table` records where applicable; no unexpected allocation occurred; no unexpected reservation was created; 40 tables and 19 adjacency pairs remain intact; disposable test data is cleaned up. Do not delete pre-existing data not created by this task.
>
> **§13 Documentation.** Update only the documentation required by this implementation — likely `api-spec.md`, `traceability.md`. Follow the project's existing AI working-record convention. Do not rewrite unrelated specifications or historical records.
>
> **§14 Strict scope — do NOT implement:** Staff Table API, Staff Table UI, Staff Release, Staff No-show, Staff management, registration, roles/permissions, OAuth, SSO, MFA, password reset, Redis, Sidekiq, WebSockets, notifications, live updates, rate limiting, analytics, P1 fairness features, missed-opportunity tracking, fairness debt, predictive demand, AI runtime decisions, changes to the allocation algorithm, domain redesign, unrelated frontend work. If another feature appears necessary: report the dependency and stop, do not implement automatically.
>
> **§15 Git.** Before committing: `git status`, `git diff --stat`, `git diff -- <relevant files>`. Run the full backend test suite; frontend TypeScript check and lint if frontend changed. Create ONE focused commit: `feat: implement staff queue`. Do NOT push automatically. Leave the working tree clean.
>
> **§16 Final response:** Status (PASS/BLOCKED); Implemented (what was actually built); API (endpoint and behavior); Frontend (what was actually built); Tests (new tests and full-suite result); Real Verification (API + browser + PostgreSQL verification); Documentation (files changed); Git (commit hash and working-tree status); Scope (confirm Staff Table, Staff Release, Staff No-show, Redis, Sidekiq, notifications, live updates, and P1 work were NOT implemented). "STOP after this task. Do not start another phase."
