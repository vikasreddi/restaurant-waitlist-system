# Session Log

Chronological record of Claude Code sessions on this assignment. Append new sessions here as they happen; do not rewrite history.

---

## Session 1 — 2026-08-15

**Environment:** Claude Code CLI, local macOS session, no MCP servers, no custom hooks/skills/agents configured for this work.

**Phase 1 — Requirements Analysis**

- Input: `restaurant_waitlist_claude_phase1_requirements.md` (candidate-authored, read from `~/Downloads/`).
- Output: a full requirements-analysis response covering explicit functional/non-functional requirements, implicit requirements, domain entities/invariants, concurrency risks, idempotency analysis, table allocation rules and ambiguities, queue/position analysis, the starvation problem (marked `DECISION REQUIRED`, no policy selected), anonymous guest identity analysis, live-update trade-offs (no selection), caching analysis (no technology chosen), background job analysis (no queue technology chosen), observability, security, hard-path test list, a `DECISIONS REQUIRED` checklist, P0/P1/P2/cut scope proposal, and top-10 lists for risks/tests/AI-agent failure modes.
- No files were created or modified in this phase, per its explicit instruction; the analysis was delivered directly in the conversation.
- Outcome: this analysis was the input to the candidate's own product/architecture decisions, which were then fed back into Prompt 2 (Phase 3) as "Approved Product Decisions."

**Phase 3 — Documentation & Specification Foundation**

- Input: `restaurant_waitlist_phase3_claude_prompt.md` (candidate-authored, read from `~/Downloads/`), which supplied already-approved decisions (table seed data, max combination size, the full seating allocation algorithm, starvation policy, position model, guest identity mechanism, idempotency requirement) and a required documentation structure.
- Agent asked the candidate one clarifying question: where to create the top-level `restaurant-waitlist/` project folder (offered `~/Downloads/`, `~/`, `~/Documents/` as options). Candidate chose `~/Documents/restaurant-waitlist`.
- Agent inspected the top-level directory structure only of a reference project present in the same Downloads folder (`mentoring-session-booking-main`), per Prompt 2 §14, to understand how a well-documented agentic assignment can organize prompts/diagrams/requirements/architecture/decisions/AI records — did not copy its implementation, architecture, or decisions.
- Created `~/Documents/restaurant-waitlist/documents/{01-requirements ... 07-future-evolution}/` and populated all files specified in Prompt 2 §11 (see `agent-decisions.md` for the file list and any organizational judgment calls), plus this AI working record.
- No application code, API implementation, database migrations, frontend components, agents, skills, hooks, or MCP configuration were created, per Prompt 2 §15's explicit boundary.
- Top-level `README.md` for the project was created alongside the `documents/` tree (see repo root).

**End-of-session report to candidate:** files created, major assumptions, unresolved questions (`OPEN-001` through `OPEN-007`), contradictions/risks found (none beyond the open items), and recommendations requiring human approval — delivered in the final chat response of this session, and mirrored in `agent-decisions.md`.

**Next session (not yet run):** human review of `documents/`, resolution of `OPEN-001`..`OPEN-007`, then architecture-decision step per the workflow in `ai-development-approach.md`, before any implementation work begins.

---

## Session 2 — 2026-08-15

**Environment:** Claude Code CLI, same local macOS environment and repository (`~/Documents/restaurant-waitlist/`), new conversation. No MCP servers, hooks, skills, or custom agents configured.

**Phase 3 Review Correction & Architecture Decision**

- Input: `restaurant_waitlist_phase3_review_architecture_prompt.md` (candidate-authored, read from `~/Downloads/`), containing specific human-review corrections to Session 1's output plus a technology-stack proposal to evaluate and an architecture-decision request.
- Verified three genuine defects in Session 1's actual output before recording them (per the "do not fabricate" rule): an overstated/self-contradictory starvation guarantee, an unjustified "Weighted" qualifier in the algorithm name, and an API contract that allowed an ambiguous raw-table-id release path. All three are documented in full in `ai-corrections.md` as CORR-001 through CORR-003, and corrected across every file that referenced them (`02-product-decisions/`, `03-architecture/`, `04-diagrams/`, `05-specifications/`).
- Applied the four other required corrections that were not "genuine mistakes" so much as clarifications/tightenings explicitly requested: position-computation wording (current-state-only, no prediction), an explicit "not naive greedy iteration" statement plus the required global-reasoning diagram shape for the allocation policy, a tightened idempotency-key description (client-generated UUID, reused on retry), and Stage 0 (oversized-group rejection) added to the allocation spec.
- Evaluated the oversized-group question (Option A: reject vs. Option B: mark permanently unseatable) against the human-supplied criteria and recommended Option A — recorded as `DEC-011`, resolving the former `OPEN-006`.
- Evaluated the candidate's proposed technology stack (React+TS, Rails API, PostgreSQL, Redis, Sidekiq+Redis, Docker Compose) against the assignment's concurrency/atomicity/idempotency/testing/deployability demands; found no serious issue and recommended keeping it unchanged — recorded as `DEC-012`, resolving the former `OPEN-001`. Noted the candidate's own reference project (`mentoring-session-booking-main`) uses the same core stack as supporting evidence of feasibility/familiarity.
- Added `DEC-013` (PostgreSQL is the sole source of truth; Redis is never authoritative for table availability) and `DEC-014` (release is identified by `queue_entry_id`, never a raw `table_id`, so a combined pair can never be half-released) as new standing architectural invariants (`domain-model.md` INV-014, INV-015).
- Updated `03-architecture/architecture.md` to reflect the approved stack concretely (component diagram, request flow, deployment); updated `04-diagrams/01-system-context.md` and `04-diagrams/07-architecture-data-flow.md` to name PostgreSQL/Redis/Sidekiq directly instead of generic placeholders.
- Rewrote `05-specifications/api-spec.md`'s release endpoint and `05-specifications/test-strategy.md` to add the 12 explicitly-required test cases from Prompt 3 §12 (new tests TEST-021 through TEST-026 for gaps not already covered, with an explicit coverage-mapping table).
- No application code, migrations, frontend components, agents, skills, or MCP configuration were created, per Prompt 3's explicit boundary (§1, §13, §15).
- Updated `README.md` to reflect the now-approved stack and the reduced open-decisions list.

**End-of-session report to candidate:** corrected files; final recommended technology stack (kept as proposed); final architecture (React SPA → Rails API → PostgreSQL, with Redis/Sidekiq as P1); final allocation-policy summary (renamed, corrected guarantee wording); unresolved decisions (`OPEN-002`, `OPEN-005`, `OPEN-007`); risks; what is now frozen for implementation vs. what remains intentionally deferred — delivered in the final chat response of this session.

**Next session (not yet run):** candidate review and approval of this session's output, specifically DEC-011 and DEC-012, before any implementation-agent configuration (agents/skills/MCP) or actual implementation work begins, per the workflow in `ai-development-approach.md`.

---

## Session 3 — 2026-08-15

**Environment:** Claude Code CLI, same local macOS environment and repository (`~/Documents/restaurant-waitlist/`), new conversation continuing from Session 2's approved output.

**Phase 4 — AI-Native Development Configuration**

- Input: `restaurant_waitlist_phase4_ai_configuration_prompt.md` (candidate-authored, read from `~/Downloads/`), authorizing configuration of the AI-native development environment — `CLAUDE.md`, agents, skills, commands, hooks, settings, MCP if useful — while explicitly still prohibiting any application code, Rails controllers/models, React components, migrations, Redis/Sidekiq implementation.
- Created root-level `CLAUDE.md`: source-of-truth pointer to `documents/`, the approved stack (DEC-012), the core development workflow, the product/engineering/AI rules from the prompt's §4, a requirement-traceability pointer, an agents/skills/commands index, the `BLOCKED — HUMAN DECISION REQUIRED` escalation format, the non-negotiable invariant list (referencing `domain-model.md` rather than duplicating it), and an explicit phase-boundary statement.
- Created `documents/01-requirements/traceability.md` — the lightweight Requirement → Specification → Implementation → Test mapping requested in §5, pre-populated with every P0/P1 requirement ID against its governing specification section and (where one already exists) its `TEST-*` ID; Implementation/Test columns are `—` throughout since no code exists yet.
- Created `documents/06-ai-working-record/session-plan.md` documenting the suggested (not mandatory) Session A–K bounded-objective breakdown from §13, and how it relates to the four new agents.
- Created four agents under `.claude/agents/`: `spec-reviewer` (read-only: `Read, Grep, Glob`), `backend-domain-agent` (`Read, Write, Edit, Bash, Grep, Glob`), `test-engineering-agent` (same), `code-review-agent` (read-only + `Bash` for running existing tests/linters, no `Write`/`Edit`). Each references the relevant `documents/` paths rather than duplicating their content, and each carries the specific "must not" rules from the prompt (never implement fairness debt/shared tables, never use Redis as source of truth, never silently modify code during review, etc.).
- Created three skills under `.claude/skills/`: `requirement-traceability`, `hard-path-testing` (the five hard-path categories — concurrency, idempotency, atomicity, starvation/fairness, state transitions — with explicit anti-patterns to reject in review), and `rails-domain-development` (project-specific service/transaction/locking guidance, explicitly not a generic Rails tutorial).
- Created three commands under `.claude/commands/`: `/spec-review`, `/test-hard-paths`, `/requirements-check`, each a thin wrapper pointing at the corresponding agent/skill and the authoritative documents rather than re-specifying behavior inline.
- Configured `.claude/settings.json` (via the `update-config` skill) with a minimal `permissions.deny` list for genuinely destructive operations (force-push, `git reset --hard`, `git clean -f`, `git branch -D`, `rm -rf`) and a `permissions.ask` rule forcing confirmation on any edit under `documents/02-product-decisions/**` regardless of active permission mode, protecting approved decisions from silent rewrites by an implementation agent. No hooks added — no Rails/npm project exists yet to lint or test, so a hook would fail immediately; deferred to the bootstrap session. No env vars, no model overrides.
- **MCP decision: none added.** Evaluated the three candidate categories the prompt named (git/repo context, documentation/spec retrieval, database inspection) and found none clear a genuine-value bar right now: git context and doc/spec retrieval are already fully served by existing `Bash`/`Read`/`Grep`/`Glob` tool access at this project's scale, and there is no database yet to inspect. Recorded per the prompt's required phrasing: *"No MCP was added because the available MCP capability did not provide sufficient value for this two-day project."* Revisit database-inspection MCP once Session B (database/domain model) exists.
- All Session 3 judgment calls (MCP, hooks, the permission-rule-vs-hook choice for protecting approved decisions, agent tool grants, traceability format, session-plan placement) recorded in `agent-decisions.md` under "Session 3 — decisions made under delegated judgment," each tied to the specific place the governing prompt explicitly left it to agent judgment.
- No application code, Rails controllers/models, React components, database migrations, Redis code, or Sidekiq jobs were created, per §16's explicit boundary.

**End-of-session report to candidate:** configuration created (CLAUDE.md, 4 agents, 3 skills, 3 commands, settings.json, no hooks, no MCP) with purpose/allowed/forbidden for each; deliberately-not-added items and why; the intended AI workflow for future sessions; remaining configuration/workflow risks; and an explicit confirmation that no application implementation was performed — delivered in the final chat response of this session.

**Next session (not yet run):** the first implementation session (Session A, project bootstrap, per `session-plan.md`) — explicitly authorized only after this configuration is reviewed and approved.

---

## Session 4 — 2026-08-16 — STOPPED (blocked on environment)

**Environment:** Claude Code CLI, same local macOS environment and repository (`~/Documents/restaurant-waitlist/`), new conversation. First implementation-authorizing session (Phase 5A / Session A bootstrap, per `session-plan.md`).

**Status: incomplete — stopped mid-task by explicit candidate instruction after a real environment blocker, not by reaching the checkpoint.**

**What happened, in order:**

1. Input: `restaurant_waitlist_phase5A_bootstrap_prompt.md` (Prompt 5) — authorized the smallest runnable bootstrap (Docker Compose running React+TS frontend, Rails API backend, PostgreSQL, a `/health` endpoint), explicitly no business functionality.
2. Ran environment inspection per Prompt 5 §2 before making any changes. Findings:
   - **Docker / Docker Compose: not installed.** No `docker` binary; daemon unreachable. No Colima, Podman, or OrbStack either.
   - **Ruby:** system Ruby 2.6.10 only (macOS default, arm64e) — too old for a modern Rails app (Rails 7+ needs Ruby ≥3.0+, typically newer). Bundler 1.17.2 (also the old macOS default).
   - **Rails:** not installed.
   - **Node.js / npm / Yarn:** none installed.
   - **Git:** installed, 2.42.0.
   - **Homebrew:** installed at `/usr/local` (Intel/Rosetta prefix on what is otherwise an arm64e machine — itself worth noting for a later session), reporting version ≥4.1.0 but with a shallow/no git repository warning.
3. Per Prompt 5's explicit "do not install or upgrade global software automatically" boundary, and this session's own standing guidance to check before taking system-impacting actions, the candidate was asked (not silently decided) how to obtain a working Docker for the required `docker compose up` verification. Options presented: Colima + Docker CLI (recommended, no GUI/password-dialog interaction needed), Docker Desktop (standard but requires a manual one-time GUI/password step), candidate installs manually, or skip Docker and proceed unverified. **Candidate chose Colima + Docker CLI.**
4. Created the project structure called for in Prompt 5 §4: empty `backend/` and `frontend/` directories at the repo root (no scaffolding generated inside either yet).
5. Ran `brew install colima docker docker-compose` in the background. **It failed** — not due to Colima/Docker themselves, but because this machine's existing Homebrew installation has broken permissions: `/usr/local/Cellar` and most of `/usr/local/**` are not writable by the current user (a pre-existing condition on this machine, unrelated to anything this session did). Homebrew's own error output additionally showed noise from a `docker`/`docker-desktop` cask-vs-formula naming collision, but that was secondary — the blocking error was the permissions failure, which occurs before any package is actually written.
6. Reported the failure and the exact fix (`sudo chown -R vikas <the affected /usr/local subpaths>`) to the candidate, since running `sudo` requires their password and is a broad, system-wide permission change outside this project's scope — not something to run unilaterally.
7. **Candidate issued an explicit stop instruction** (Prompt 6, recorded above) before running that fix themselves: stop at the current checkpoint, run no more installation commands, make no further project modifications, ensure everything important is saved, and report status. This session complied and stopped.

**What was completed:**
- Environment inspection (Prompt 5 §2) — done, findings above.
- Project structure — partially done: `backend/` and `frontend/` directories exist and empty (no content to lose; nothing was mid-write when the stop instruction arrived).
- Human decision captured: Colima + Docker CLI is the chosen path forward (not Docker Desktop, not a host-native Ruby/Node setup).

**What failed:**
- `brew install colima docker docker-compose` — failed with exit code 1 due to pre-existing `/usr/local` permission problems on this machine (Homebrew itself is not fully usable until fixed). Full output preserved at the background task's output path if needed for later debugging; the actionable fix is the `sudo chown` command above.

**What remains to be done (all of Prompt 5 is still open):**
- Fix the Homebrew `/usr/local` permissions (candidate to run the `sudo chown` command — outside agent scope).
- Re-run `brew install colima docker docker-compose`, then `colima start`.
- Verify `docker` and `docker compose` are functional.
- Generate the Rails API backend (containerized, per "prefer project-local/containerized dependencies" — e.g., via a Ruby container, not a host-installed Rails) with PostgreSQL adapter, Docker-Compose-suitable config, and a minimal `GET /health` endpoint.
- Generate the React + TypeScript frontend (containerized, e.g., via a Node container running `npm create vite@latest -- --template react-ts`) with a minimal page showing frontend-running status and backend health.
- Add PostgreSQL to `docker-compose.yml` with a persistent dev volume and connection config.
- Write `docker-compose.yml` wiring all three services together with sensible dev ports and documented dev-only credentials.
- Run and verify: `docker compose config`, container startup for all three services, `GET /health` → 200, frontend reachability, and (if practical) frontend-to-backend connectivity.
- Add a minimal health-endpoint test only (no business tests).
- Deliver Prompt 5's Final Report (§13) once the checkpoint is actually reached.

**Next command/action required, once the permission issue is resolved (exact sequence):**
```
brew install colima docker docker-compose
colima start
docker --version && docker compose version
```
Then resume Prompt 5 from §5 (Backend Bootstrap) onward.

**AI working record updated this session:** `agent-prompts.md` (Prompt 5 and Prompt 6, verbatim), `session-log.md` (this entry), `agent-decisions.md` (the Colima-vs-alternatives environment decision, recorded as a delegated/candidate-confirmed choice, not a silent agent decision). `ai-corrections.md` was not updated — no genuine agent mistake occurred this session; the blocker is pre-existing host machine state, not something the agent did wrong, so nothing was recorded there per the standing "do not fabricate" rule.

**Next session (not yet run):** resume Phase 5A bootstrap from the point above, once Homebrew permissions are fixed and Colima/Docker are installed.

---

## Session 5 — 2026-08-16 — Phase 5A bootstrap completed and verified

**Environment:** Claude Code CLI, same local macOS environment and repository (`~/Documents/restaurant-waitlist/`), new conversation, resuming after Session 4's stop.

**Phase 5A — Resume Bootstrap After macOS Permission Fix**

**Pre-work inspection (Prompt 7 §1), before any changes:** confirmed the project was exactly where Session 4 left it — empty `backend/`/`frontend/` directories, no git repository, `documents/` and `.claude/` untouched. Did not recreate, overwrite, or restart anything.

**Environment re-verification found two further blockers, both surfaced to the candidate rather than worked around:**

1. A smaller residual round of the same `/usr/local` permission problem from Session 4 — most paths were now writable, but `/usr/local/Homebrew` itself and several `share/`/`etc/`/`var/homebrew` paths were still owned by another user. Reported the exact remaining `sudo chown` command; candidate ran it themselves.
2. After that fix, `brew install colima docker docker-compose` succeeded for the formulae themselves, but `brew link` failed to symlink the `docker`/`colima`/`lima` binaries into `/usr/local/bin` because `/usr/local/share/fish/vendor_completions.d` (an unrelated shell-completions directory) wasn't writable. Rather than requesting a third round of `sudo chown` for a directory that doesn't affect functionality, the agent judged this a "smallest necessary correction" case (`CLAUDE.md`/Prompt 7 §10) and manually symlinked the three already-installed binaries (`docker`, `colima`, `limactl`) directly into `/usr/local/bin` — the same directory `brew link` would have written to, using files Homebrew had already placed in `/usr/local/Cellar`. No new software was installed; this only completed Homebrew's own linking step for the parts that had nothing to do with the broken directory. Recorded as a judgment call in `agent-decisions.md`.
3. `colima start` then failed with `limactl is running under rosetta, please reinstall lima with native arch` — a genuinely new, structural discovery: this Mac is Apple Silicon (arm64), but its only Homebrew installation lives at `/usr/local` (the Intel-prefix build, run under Rosetta translation), so every binary installed through it — including Colima/Lima — is an x86_64 build. Colima's VM management needs a native arm64 binary to use Apple's virtualization framework; no retry or flag on the existing installation fixes this. This was surfaced to the candidate as a real architectural/environment finding, not silently worked around (`CLAUDE.md` "when scope is exceeded" spirit, applied to environment setup rather than product decisions). **Candidate chose to install a second, native Homebrew at `/opt/homebrew`** (the standard fix, coexists with the existing Intel one) — that installer itself needed an interactive sudo password, so the candidate ran it themselves in their own terminal. The candidate then started Colima natively (`colima start --arch aarch64`) and confirmed it working before handing control back.

**Once the environment was confirmed working (`docker info` reachable, server `linux/aarch64`), implementation proceeded:**

- Generated a minimal Rails 7.1.6 API app (Ruby 3.3.12) in `backend/` using a throwaway `ruby:3.3-slim` container bind-mounted to `backend/` — nothing installed on the host. Flags used: `--api --database=postgresql --skip-git --skip-ci --skip-kamal --skip-docker --skip-bootsnap` (`--skip-git` because the overall project has no git repository yet and generating a nested repo inside `backend/` would have been worse than none; `--skip-kamal`/`--skip-docker` to avoid Rails 8-style deploy scaffolding this bootstrap doesn't need — Rails 7.1 doesn't include those by default, kept the flags for robustness/clarity anyway).
- Generated a minimal React+TypeScript app (Vite) in `frontend/` using a throwaway `node:20-slim` container (`npx --yes create-vite@latest . --template react-ts`) — nothing installed on the host.
- Added `HealthController#show` (`GET /health` → `{"status":"ok"}`) alongside Rails' own built-in `/up` health check (left untouched).
- Configured `config/database.yml` to read host/username/password from `DATABASE_HOST`/`DATABASE_USERNAME`/`DATABASE_PASSWORD` env vars (Docker Compose sets these; falls back to `localhost`/`postgres`/`postgres` for non-Docker use).
- Enabled `rack-cors` (was commented out by default) and configured it to allow the frontend's origin (`FRONTEND_URL` env var, defaults to `http://localhost:5173`) — required for the frontend's browser-side `fetch("/health")` to work cross-origin; verified with an actual `Origin`-header curl request, not assumed.
- Wrote `backend/Dockerfile` (dev-focused: bundle install at build time, bind-mount source at runtime) and `backend/bin/docker-entrypoint` (clears a stale `tmp/pids/server.pid`, runs `rails db:prepare` before boot so the dev/test databases and schema exist — no business migrations exist yet, so this is a no-op beyond creating the tracking tables).
- Replaced the default Vite template `App.tsx` with the required minimal status page ("Frontend: running" / "Backend: connected|unreachable|checking…"), reading the backend URL from `VITE_BACKEND_URL` and calling `GET /health` on mount. Set `server.host: true` / `server.port: 5173` / `strictPort: true` in `vite.config.ts` so the Vite dev server is reachable from outside its container.
- Wrote `frontend/Dockerfile` (dev-focused: npm install at build time, bind-mount source at runtime, named volume for `node_modules` to avoid the bind mount shadowing it).
- Wrote the top-level `docker-compose.yml`: `postgres` (16-alpine, named volume, health-checked via `pg_isready`), `backend` (depends on postgres being healthy), `frontend` (depends on backend). Dev-only credentials (`postgres`/`postgres`) documented inline in the compose file's header comment, matching Prompt 5/7's "dev-only credentials acceptable if clearly documented."
- Added `.dockerignore` for both services.
- Added a minimal health-endpoint test (`backend/test/controllers/health_controller_test.rb`) — one assertion-bearing test, no business tests.

**Problem encountered and resolved (real, not fabricated — see reasoning below on why this isn't in `ai-corrections.md`):** the first test run failed with `wrong number of arguments (given 3, expected 1..2)` inside `railties`' `line_filtering.rb`. Root cause: `bundle install` (unpinned) resolved minitest 6.0.6, whose `Minitest.run` signature changed incompatibly with Rails 7.1.6's test-runner internals (built against minitest 5.x). Per the troubleshooting rule (Prompt 7 §10): inspected the actual error, identified the root cause, made the smallest necessary correction (pinned `gem "minitest", "~> 5.20"` in the Gemfile, documented why in a comment), re-ran `bundle install` inside the running container, re-ran the test — passed. **Not recorded in `ai-corrections.md`:** that file's pattern is "the agent confidently asserted something and a human had to catch it was wrong." Here the agent's own test run caught the failure directly, diagnosed the root cause, and fixed it within the same troubleshooting pass — an ordinary dependency-resolution bug encountered and resolved during implementation, not a case of confident wrongness a human corrected. `ai-corrections.md` already has its 2–3 genuine examples from Session 2 (CORR-001–003); nothing was force-fitted here to pad that count.

**Verification actually performed (not claimed without running it, per Prompt 7 §9):**
- `docker compose config` — succeeded (`--quiet`, exit 0).
- `docker compose ps` — all three containers `Up`, postgres reporting `(healthy)`.
- `curl http://localhost:3000/health` — `200`, body `{"status":"ok"}`.
- `curl http://localhost:5173/` — `200`, served the Vite/React app shell.
- `docker compose exec backend bin/rails runner '...ActiveRecord::Base.connection.active?...'` — `DB_CONNECTED`.
- `curl -H "Origin: http://localhost:5173" http://localhost:3000/health` — confirmed `access-control-allow-origin: http://localhost:5173` present, proving the frontend's actual in-browser fetch will succeed, not just that the two servers independently respond.
- Confirmed the served frontend JS bundle actually contains `VITE_BACKEND_URL: "http://localhost:3000"` — the env wiring reaches the browser, not just the build config.
- `bin/rails test test/controllers/health_controller_test.rb` — 1 run, 2 assertions, 0 failures.

**Git checkpoint (Prompt 7 §12):** `git status` — still `fatal: not a git repository`. No repository has ever been initialized for this project (true since Session 1). Per Prompt 7 §12 ("do not create a commit unless the project workflow already expects Claude to commit"), and since there is no existing git workflow to speak of, the agent did not initialize a repository or commit — flagged clearly in the final report as an open item for the candidate to decide on, not acted on unilaterally.

**AI working record updated this session:** `agent-prompts.md` (Prompt 7, verbatim, plus a note on the mid-session environment exchange), `session-log.md` (this entry), `agent-decisions.md` (the manual-symlink judgment call, the Rails/Ruby/minitest version-pin choices, and the native-Homebrew-vs-alternatives environment decision). `ai-corrections.md` intentionally not updated this session — reasoning above.

**End-of-session report to candidate:** environment versions, files created/modified, full verification results, the problem encountered and how it was resolved, AI working-record files updated, and the explicit phase-status confirmation — delivered in the final chat response of this session.

**Next session (not yet run):** Phase 5B — Domain Model + Migrations + Seed Data. Not started in this session, per the explicit phase boundary.

---

## Session 6 — 2026-08-16 — Phase 5A.1 cleanup + first git checkpoint

**Environment:** Claude Code CLI, same local macOS environment and repository (`~/Documents/restaurant-waitlist/`), new conversation, immediately following Session 5.

**Phase 5A.1: corrected stale project-status documentation and established the first version-control checkpoint before domain implementation.**

- Inspected current state first (`git status`/`git log` — confirmed no repository existed anywhere in the project; `CLAUDE.md`, `README.md`, `docker-compose.yml`, `backend/`, `frontend/` — all as Session 5 left them). Did not recreate, redo, or start Phase 5B.
- Updated `CLAUDE.md`'s "Current status" and "Phase boundary" sections only — now states Phase 5A (Sessions 4–5) is complete and verified, and explicitly lists what's still not implemented (domain models, allocation, guest/staff APIs, auth, Redis/Sidekiq). Product/engineering/AI rules and all `DEC-*`/`INV-*` references left untouched.
- Updated `README.md`: replaced the "no application code has been written yet" status line and added the "Current implementation status" section (implemented vs. not-yet-implemented lists) plus working `docker compose up` run instructions, matching what was actually verified in Session 5.
- Verified the existing AI working record already contains the environment issue, the Intel-vs-ARM64 Homebrew discovery, the Colima architecture resolution, final Docker verification, and the bootstrap result in full (Session 5's entry) — did not duplicate any of it; this entry is the "concise checkpoint entry" the governing prompt allowed for.
- Added a one-line status note to `documents/01-requirements/traceability.md` ("Phase 5A = infrastructure/bootstrap only... no business requirement... has been implemented yet") — did not add any business requirement mapping, per the explicit instruction that Phase 5B establishes the first one.
- **Git setup:** no repository existed at the project root (true since Session 1). Ran `git init`, set the default branch to `main` (a minor, unescalated judgment call — see `agent-decisions.md`), and wrote a root-level `.gitignore` (`.env`/`.env.*`, `.DS_Store`, `node_modules/`, `vendor/bundle/`, `coverage/`, `log/`, `tmp/`, `frontend/dist/`, and `backend/config/master.key` specifically as a secret-adjacent file the governing prompt's §7 concern covers even though it wasn't in the example list). Confirmed via `git check-ignore -v` that `.DS_Store`, `backend/log/*`, `backend/tmp/*`, and `backend/config/master.key` are excluded, and that `documents/`, `CLAUDE.md`, `.claude/`, `README.md`, `docker-compose.yml` are not.
- **Reviewed staged files before committing** (§7) and caught a real gap: `frontend/package-lock.json` had never been persisted to the host — `npm install` only ran inside the Docker build layer, and the runtime bind mount (`./frontend:/app`) shadowed it with the host's (nonexistent) copy. Generated it properly via `docker compose exec frontend npm install` so it landed in the bind-mounted directory, then confirmed it appeared in what would be staged. This is a small, directly-related fix to what this exact checkpoint is supposed to capture (a reproducible baseline), not an unrelated fix.
- Created the first commit: **`2b653ff` — "chore: bootstrap runnable application"** (123 files). Contains the runnable application (backend/, frontend/, docker-compose.yml), the full AI working record, `CLAUDE.md`, and `.claude/agents|skills|commands|settings.json` — matching the governing prompt's required checkpoint contents exactly.
- **Noted, not fixed:** the commit's author identity (`vikas <vikas@Rajas-Air.lan>`) was auto-derived from the OS account/hostname since no global git identity is configured on this machine. Flagged to the candidate in the final report rather than guessed at or silently left uncommented — this may matter for how the assignment's authorship reads during review.
- **Post-checkpoint verification** (§11): `docker compose config` succeeded; `docker compose ps` showed all three containers still `Up`/`(healthy)` (never stopped since Session 5, so this also incidentally demonstrates the stack surviving a `git init` + commit alongside it); re-curled `/health` (200), frontend (200), and re-ran the `ActiveRecord::Base.connection.active?` check (`DB_CONNECTED`) — no regressions introduced by the cleanup.

**No AI correction recorded.** No genuine agent mistake occurred this session that fits `ai-corrections.md`'s pattern (an agent claim a human had to catch as wrong) — the package-lock.json gap was self-caught during the routine pre-commit review this task itself asked for (§7), not a confident wrong assertion.

**AI working record updated this session:** `agent-prompts.md` (Prompt 8, verbatim), `session-log.md` (this entry), `agent-decisions.md` (the `main`-branch-name and `.gitignore`-scope judgment calls).

**End-of-session report to candidate:** documentation files updated and exact stale statements corrected; git status (no prior repository → initialized → commit hash/message); verification results; AI working-record files updated; explicit scope confirmation — delivered in the final chat response of this session.

**Next session (not yet run):** Phase 5B — Domain Model + Migrations + Seed Data. Not started in this session, per the explicit phase boundary.

---

## Session 7 — 2026-08-16 — Phase 5B.1 domain model proposal (specification only, no code)

**Environment:** Claude Code CLI, same local macOS environment and repository (`~/Documents/restaurant-waitlist/`), new conversation, immediately following Session 6.

**Phase 5B.1 — Domain Model Proposal and Review**

- The candidate's first paste of the governing prompt was truncated (cut off mid-§3, no closing sections). The agent checked `~/Downloads/` for a matching file, found none, and asked the candidate to re-send rather than guessing at or inventing the rest of a governing specification document — the candidate re-sent the complete text in the next turn.
- Re-derived the domain model from requirements rather than accepting the Phase 3 draft (`03-architecture/domain-model.md`, `data-model.md`) as-is, per the governing prompt's explicit instruction not to automatically accept the example state machine or ERD. This surfaced a real, previously-unnoticed gap: Phase 3's `functional-spec.md` had staff "seat by code" perform allocation *synchronously* at the moment of code entry, but the brief's actual guest experience ("when a group reaches the front, their phone shows a code") requires the system to decide and reserve a configuration for a specific group *before* staff ever act. Modeling this correctly required adding a `ready` state to `QueueEntry` that the Phase 3 draft never had — recorded as a formal "changed a previous assumption" note (governing prompt §20) rather than silently introduced.
- Produced `documents/05-specifications/domain-model-proposal.md` — the full analysis: 6 entities (`StaffUser`, `Table`, `TableAdjacency`, `QueueEntry`, `SeatingAssignment`, `SeatingAssignmentTable`), down from Phase 3's 7 (dropped `IdempotencyRecord` as a separate table — folded into a unique column on `QueueEntry`; dropped `GuestIdentity`/`ActiveVisitToken` as a separate entity — folded into a unique column on `QueueEntry`, matching the governing prompt's own "queue-entry token" option; dropped `NotificationJob` entirely — out of scope per §19). Replaced `TableCombination` with `SeatingAssignment` + a `SeatingAssignmentTable` join table, chosen specifically because a single partial-unique index on the join table's `table_id` column (not two independent indexes on two FK columns) is the only design that correctly enforces "a table is claimed by at most one active assignment regardless of which slot it fills" — full alternatives comparison (§14 of the deliverable) documents why the simpler two-column design was considered and rejected on correctness grounds, not merely a preference.
- Deliberately did **not** propose any stored "position" or "starvation weight" column — both are derived at read time from `joined_at`/`group_size`/current table state, per the governing prompt's explicit instruction to prove necessity before persisting a precomputed value; documented why (§7–8 of the deliverable).
- Verified the exact current invariant IDs (`INV-001`–`INV-015`) and decision IDs (`DEC-001`–`DEC-014`) against the live documents before citing them in the proposal, rather than relying on memory.
- Worked through the full concurrency plan (§11 of the deliverable) mapping each of the governing prompt's five named race scenarios to a specific mechanism (row locking, the join-table partial-unique index, or the idempotency-key unique index) — no implementation was written, only which mechanism protects which case.
- Proposed a concrete, deterministic 40-table seed/adjacency plan explicitly tied to the allocation algorithm's needs (enough 4+4 adjacent pairs to support groups of 5–8; the two 6-seat tables deliberately left non-adjacent to anything, since no requirement needs a >8-person automatic configuration) — no seed code written.
- **Governance note recorded in the deliverable itself (§0, §16):** this proposal revises Phase 3's "approved" `domain-model.md`/`data-model.md` in several places. Per `CLAUDE.md`'s "if you find a contradiction... STOP and report it, do not silently resolve it," the agent did not overwrite those documents — the proposal recommends they be formally updated once approved, and flags this as an explicit open item rather than assuming approval.
- Two new open decisions surfaced (not previously tracked): whether the `ready` state needs its own abandonment timeout distinct from `OPEN-007`'s existing `waiting`-state scope, and the standing `OPEN-005` (seating-code format) remains unresolved by this proposal — it only commits to "a unique string column."

**No AI correction recorded.** No case this session fits `ai-corrections.md`'s pattern (an agent claim a human had to catch as wrong) — the truncated-prompt handling was a stop-and-ask, not a wrong claim, and the Phase 3 assumption revisions are disclosed, reasoned refinements produced *during* the analysis this phase asked for, not a mistake caught after the fact.

**AI working record updated this session:** `agent-prompts.md` (Prompt 9, condensed but complete), `session-log.md` (this entry), `agent-decisions.md` (the domain-model revision judgment calls), plus the new specification artifact `documents/05-specifications/domain-model-proposal.md`.

**Strict no-code rule honored:** no migrations, models, controllers, services, seed code, frontend changes, Docker changes, APIs, or tests were created this session.

**End-of-session report to candidate:** delivered per the governing prompt's §22 Final Output structure in the final chat response of this session, referencing `domain-model-proposal.md` for full depth.

**Next session (not yet run):** Phase 5B.2 — implementation, only after human review/approval of this proposal (and, per the proposal's own recommendation, a decision on whether to formally update `03-architecture/domain-model.md`/`data-model.md` to match it).

---

## Session 8 — 2026-08-16 — human review of the Phase 5B.1 proposal: one real correction, one open item resolved

**Environment:** Claude Code CLI, same repository, continuing directly from Session 7 in the same conversation (candidate reviewed the proposal and responded with findings, not a new governing prompt file).

**Human review findings on `documents/05-specifications/domain-model-proposal.md`:**

1. **A real, confirmed defect:** the proposed `seating_assignment_tables` exclusivity constraint (a partial unique index predicated on a `status` column meant to mirror the parent `SeatingAssignment.status`) can't actually work as described — PostgreSQL partial-index predicates cannot reference another table's column, so the "database-level enforcement" the proposal claimed was really only as strong as an unenforced application promise to keep the denormalized column in sync. Recorded in full as **CORR-004** in `ai-corrections.md` — the fourth genuine, human-caught correction on this project, and structurally the same overclaiming pattern as CORR-001 (a guarantee stated more confidently than the mechanism actually delivers), this time at the schema level. Corrected throughout `domain-model-proposal.md` by removing the denormalized `status` column and switching to row-existence semantics (create on claim, delete on release) with a single plain unique index — simpler than the original design, not just fixed.
2. **A real, previously-open question, now given a product answer:** the candidate confirmed that a `ready` reservation must not be allowed to hold tables indefinitely, closing (in principle) the open item the proposal itself had flagged (`domain-model-proposal.md` §16 item 2, tied to `OPEN-007`'s scope). The candidate stated an expiration policy is being introduced but did not yet specify its exact shape (duration, and what happens to the entry/table on expiry) — the agent asked clarifying questions rather than inventing the specifics, consistent with "the candidate is driving product decisions" (`CLAUDE.md`).

**AI working record updated this session:** `ai-corrections.md` (CORR-004), `session-log.md` (this entry), `agent-decisions.md` (recording that the expiration-policy specifics were asked for, not assumed). `domain-model-proposal.md` corrected in place (still specification only — no code).

**Next session (not yet run):** once the expiration policy's specifics are confirmed, fold them into `domain-model-proposal.md` (§6/§16) and `02-product-decisions/decision-log.md` (a new `DEC-*` entry), then proceed toward Phase 5B.2 implementation per the candidate's approval.

---

## Session 9 — 2026-08-16 — Phase 5B.1 finalized: expiration policy locked, constraint design corrected a second time, architecture docs updated

**Environment:** Claude Code CLI, same repository, continuing directly from Session 8 in the same conversation.

**Two-part human message:** the candidate's first attempt to answer Session 8's clarifying questions (Prompt 11) was truncated mid-paste. The agent checked `~/Downloads/` for a matching file (none found) and asked for the remainder rather than guessing — the same protocol used for a similarly truncated paste in Session 7. The candidate then sent the complete, locked decision set.

**What was locked in (verbatim trade-off preserved, recorded in `decision-log.md` as **DEC-015**):**
- READY expiration outcome: auto-`no_show` (not `ready → waiting`) after a 5-minute timeout.
- Evaluation: lazy, embedded in existing read/write operations (guest position read, staff queue/table view, guest join, allocation/availability calculation, seating operations) — explicitly no Sidekiq, scheduler, or background sweep.
- Duration: 5 minutes, tunable configuration, not hardcoded into business logic.

**Constraint design corrected a second time** (the Session 8 fix — CORR-004, delete-on-release — was itself superseded here, not silently replaced): the candidate proposed `seating_assignment_tables(..., released_at)` with `UNIQUE(table_id) WHERE released_at IS NULL` and asked the agent to validate it against pending assignments, active assignments, release, expiration, historical assignments, and atomic two-table seating. The agent validated the design against all six cases explicitly (see `domain-model-proposal.md` §2/§4) and adopted it — it's strictly better than the agent's own Session 8 fix, since it additionally preserves historical seating-assignment data that the delete-based version would have discarded. `domain-model-proposal.md` was updated throughout (§0, §2, §3, §4, §5, §6, §11, §13, §15, §16, §17) to reflect the finalized design consistently, not just patched in one place.

**Architecture documents updated directly** (previously only recommended, per Session 7's stance — this session's governing message explicitly authorized it): `03-architecture/domain-model.md` and `data-model.md` were rewritten to match the finalized proposal — new entities (`SeatingAssignment`/`SeatingAssignmentTable` replacing `TableCombination`, dropping `IdempotencyRecord`/`GuestVisit`/`NotificationJob`), the `ready` state and its expiration path, and two new invariants: `INV-016` (a DB exclusivity constraint must never depend on another table's column staying in sync — the concrete lesson of CORR-004) and `INV-017` (READY-reservation lazy expiration, DEC-015). `CLAUDE.md`'s product rules, invariant-range reference, and non-negotiable-invariants summary were updated to match, since it's the file loaded into every future session.

**Known gap, flagged rather than silently left inconsistent:** `05-specifications/functional-spec.md`, `allocation-spec.md`, `api-spec.md`, `test-strategy.md`, and four diagrams (`03-staff-journey.md`, `05-combined-table-atomic-allocation.md`, `06-guest-join-idempotency.md`, `07-architecture-data-flow.md`) still describe the pre-`ready` synchronous-seating model from Phase 3 and have not been updated this session. The governing prompt's instruction was scoped to "architecture/data-model documentation," which was fully addressed; these specification/diagram files are a different category and a larger additional scope the agent did not expand into unilaterally. **This needs a follow-up pass before Phase 5B.2 implementation begins**, since an implementer reading only those files would get outdated guidance that contradicts the now-authoritative `domain-model.md`/`data-model.md`/`domain-model-proposal.md`.

**No fabricated corrections.** CORR-004 (already recorded in Session 8) is the only correction this session builds on; the constraint refinement here is a continuation/supersession of that same correction, not a new independent mistake, and is described that way in `domain-model-proposal.md` rather than logged as a separate CORR entry.

**AI working record updated this session:** `agent-prompts.md` (Prompts 10 and 11, verbatim/condensed), `session-log.md` (this entry), `agent-decisions.md` (the released_at-vs-delete design validation, and the decision to scope the architecture-doc update to exactly what was authorized).

**Strict no-code rule honored:** no Rails models, migrations, controllers, services, APIs, seed code, frontend code, domain tests, Redis, or Sidekiq were created or modified.

**Next session (not yet run):** either a documentation-consistency pass over the flagged specification/diagram files, or Phase 5B.2 implementation directly if the candidate judges the flagged gap low-risk enough to address alongside implementation — candidate's call, not decided here.

---

## Session 10 — 2026-08-16 — Phase 5B.1.5 specification consistency pass

**Environment:** Claude Code CLI, same repository, continuing directly from Session 9 in the same conversation.

**Phase 5B.1.5 — Specification Consistency Pass.** This is exactly the follow-up Session 9's report flagged as needed — the candidate authorized it explicitly rather than it being silently deferred indefinitely.

**Audit performed first, before any edits** (per the governing prompt's explicit ordering): read every document under `01-requirements/` through `06-ai-working-record/` that could plausibly still describe the pre-`ready` model, and produced a contradiction table (Document | Old assumption | Finalized assumption | Action) covering 21 distinct items across 4 specification files, 6 diagrams, 2 requirements documents, and 2 decision documents. That table was presented in full before any document was touched.

**Documents updated:**
- `05-specifications/functional-spec.md` — idempotency reference fixed; §2 (position/recover) split into `waiting` vs. `ready` response behavior, both now DEC-015 lazy-expiration checkpoints; §5 (staff view) updated for derived table status and `ready` entries; the old §6 "Staff seat by code" split into a new §6 "Allocation (system, not staff)" and §6a "Staff seat by code (confirmation, not allocation)" — the core fix, since the old single section conflated the two; §7 (release) and §8 (no-show) updated for `SeatingAssignment`/`released_at`; new §8a documents DEC-015's automatic no-show path; §9 (position) clarified as `waiting`-only.
- `05-specifications/allocation-spec.md` — `compatible_configurations` rewritten around derived table freedom (`is_free`, no `Table.status`); §5 "Atomic allocation" corrected to produce `ready` (not `seated`) and create `SeatingAssignment`/`SeatingAssignmentTable` rows instead of a `TableCombination`; new §5a "Staff confirmation" (the actual `ready → seated` step, explicitly noted as never re-running the allocation algorithm); §6 "Release" rewritten around `SeatingAssignment`/`released_at`; new §6a "Lazy READY expiration" implementing DEC-015 as an inline function, not a job; both worked examples (§7, §8) corrected to stop at `ready` and to describe an allocation-vs-allocation race, not a staff-vs-staff one.
- `05-specifications/api-spec.md` — guest current-position response split into `waiting`/`ready` shapes; `GET /staff/tables` and `GET /staff/queue` updated for derived status and `ready` entries; `POST /staff/seat` rewritten with an explicit "confirmation, not allocation" note and a new `conflict` case distinguishing expiration from a generic race.
- `05-specifications/test-strategy.md` — TEST-004/005/006 reframed as allocation-vs-allocation races, not staff-vs-staff; TEST-022 terminology fixed; TEST-015 reworded; six new tests added (TEST-027 through TEST-033) covering the `ready` transition, staff confirmation not re-allocating, DEC-015 expiration, a confirmation-after-expiration race, lazy expiration not permanently blocking a table, concurrent expiration discovery, and the exclusivity constraint itself at the database level; the "highest-value tests" summary line updated to include three of the new ones.
- `04-diagrams/02-guest-journey.md`, `03-staff-journey.md`, `04-seating-allocation.md`, `05-combined-table-atomic-allocation.md`, `06-guest-join-idempotency.md`, `07-architecture-data-flow.md` — all six updated; `07-architecture-data-flow.md` required the most substantive change, splitting one "Seat handler" into a separate allocation service and confirmation handler, and correcting the DB box's table names.
- `01-requirements/functional-requirements.md` and `acceptance-criteria.md` — REQ-STAFF-004 and REQ-GUEST-005 wording tightened to say `ready`, not `waiting`; a new acceptance criterion added for the expired-code case.
- `02-product-decisions/seating-allocation-policy.md` and `starvation-policy.md` — one clarifying sentence each, making explicit that these policies produce `ready`, not `seated`.
- `CLAUDE.md`, `.claude/agents/backend-domain-agent.md`, `.claude/agents/test-engineering-agent.md`, `.claude/skills/hard-path-testing/SKILL.md` — stale `INV-001–INV-015` ranges found and corrected to `INV-001–INV-017` (a residual gap from Session 9's own invariant additions, caught during this session's broader audit); `hard-path-testing/SKILL.md`'s state-transition guidance updated to name the current states.

**Documents intentionally unchanged:** `01-system-context.md` (never named specific entities, nothing to contradict); `documents/07-future-evolution/*` (describe deferred future work, not the current model); all prior `06-ai-working-record/` session entries (historical record of what was true *at the time* — correctly preserved, not rewritten, per the governing prompt's explicit "do not blindly replace historical AI-working-record references"); `05-specifications/domain-model-proposal.md` and `03-architecture/domain-model.md`/`data-model.md` (already finalized in Session 9; this session's audit confirmed no further changes were needed there).

**No requirement conflicts found** requiring a STOP — every named requirement (REQ-GUEST-001 through 005, REQ-STAFF-004/005/006, REQ-TABLE-002/005, REQ-QUEUE-001/002/003, REQ-INFRA-001/002) still maps cleanly to the finalized model; only wording needed tightening, not requirement content.

**Final verification grep pass** confirmed every remaining occurrence of `TableCombination`/`IdempotencyRecord`/`GuestIdentity`/`idempotency_records` in the documentation tree is either (a) inside the AI working record, correctly describing history, or (b) an explicit "revised from Phase 3 draft" note inside an authoritative document, clearly marked as historical context rather than live guidance. No unflagged contradictions remain.

**No AI correction recorded.** This session built directly on CORR-004 (already recorded) and did not surface any new instance of the agent confidently asserting something wrong — it was a systematic propagation of an already-corrected design, not a new mistake.

**AI working record updated this session:** `agent-prompts.md` (Prompt 12, condensed), `session-log.md` (this entry), `agent-decisions.md` (the audit-first ordering decision and the historical-vs-contradiction classification approach).

**Strict no-code rule honored:** no migrations, models, controllers, services, APIs, seeds, frontend code, Redis, or Sidekiq were created or modified — this session touched only `documents/`, `CLAUDE.md`, and `.claude/`.

**Next session (not yet run):** Phase 5B.2 — implementation. The specification set is now internally consistent and, per the candidate's judgment, ready for that to begin.

---

## Session 11 — 2026-08-16 — Phase 5B.2: first application code in the project

**Environment:** Claude Code CLI, same repository, continuing directly from Session 10 in the same conversation. Backend/frontend/postgres containers still running from earlier bootstrap sessions.

**Phase 5B.2 — Domain Persistence Implementation.** The candidate's first paste of the governing prompt was truncated mid-§19; the agent flagged it rather than acting on it, and the candidate supplied the complete file (`Phase_5B_2_Prompt.md`) instead.

**Implementation (all inside the running `backend` container — nothing installed on the host):**
- Enabled `bcrypt` in the Gemfile (was commented out) for `StaffUser#has_secure_password`.
- Six migrations, generated via `rails generate migration` then hand-written: `staff_users`, `tables`, `table_adjacencies`, `queue_entries`, `seating_assignments`, `seating_assignment_tables`. All ran clean on the first attempt against both the already-running dev DB and a full `db:drop db:create db:migrate` clean-slate run (§33).
- Six models (`StaffUser`, `Table`, `TableAdjacency`, `QueueEntry`, `SeatingAssignment`, `SeatingAssignmentTable`) with the associations, validations, and DB-constraint backing specified in the prompt.
- `db/seeds.rb`: deterministic 40-table seed (20×2/18×4/2×6, `T01`-`T40`) and 19 deterministic adjacency pairs, idempotent via `find_or_create_by!`.
- 60 tests across 7 files (`table_test.rb`, `table_adjacency_test.rb`, `queue_entry_test.rb`, `seating_assignment_test.rb`, `seating_assignment_table_test.rb`, `staff_user_test.rb`, `seed_data_test.rb`), 93 assertions, covering every case the prompt's §31/§32 named plus several the agent added (e.g., proving each Rails-level validation is backstopped by the actual DB constraint, not just application code — a direct application of the project's own `hard-path-testing` skill).

**Three implementation-level decisions made under the prompt's own §0 delegation ("choose the simplest correct implementation and document it"), all recorded in `agent-decisions.md`:**
1. Added a stored `expires_at` on `seating_assignments` (set at creation from a new `SeatingAssignment::READY_TIMEOUT` constant, tunable via `READY_TIMEOUT_SECONDS` env var) — a small, acknowledged deviation from `domain-model-proposal.md` §8's "derive, don't store" stance, made because §11 of this prompt explicitly listed `expires_at` as a field and storing it is harmless (a frozen deadline, not a business-rule change).
2. `TableAdjacency` uses **canonical-pair storage**: a `table_id < adjacent_table_id` database check constraint is what actually prevents a pair from being representable as two independent rows (the prompt's own stated concern in §6) — not application-level deduplication. A `TableAdjacency.pair!(a, b)` class method and a `Table#adjacent_tables` reader hide the canonical-ordering detail behind a symmetric interface. This same check constraint incidentally also rejects self-adjacency (`table_id == adjacent_table_id` can never satisfy `<`), so no separate DB mechanism was needed for that case — a Rails-level validation was still added for a friendlier error message.
3. `seating_code` stays on `queue_entries` (matching the already-finalized `data-model.md`) rather than being duplicated onto `seating_assignments`, resolving a wording ambiguity in this prompt's §11 (which listed it among "SeatingAssignment's approved conceptual fields") in favor of the more specific, explicitly-named-as-authoritative source (`data-model.md`, listed in this prompt's own §1 as a primary source to read first).

**Verification actually performed, not claimed without running it:**
- Migrations ran clean twice: once against the existing dev DB, once from a full `db:drop db:create db:migrate` (§33).
- `db:seed` produced exactly 40 tables (20/18/2 by capacity) and 19 adjacency pairs — verified via `rails runner`, not assumed from reading the seed script.
- Actual generated PostgreSQL schema inspected directly via `psql \d` (§34) for all four non-trivial tables — confirmed: no occupancy column on `tables`; the canonical-order check constraint on `table_adjacencies`; all check constraints, unique indexes, and partial unique indexes present with the exact predicates specified (`WHERE released_at IS NULL`, `WHERE status <> 'released'`, `WHERE seating_code IS NOT NULL`); no `TableCombination`/`IdempotencyRecord`/`GuestIdentity` tables exist.
- All four Rails-console verification examples from §35 run against disposable data inside a transaction that was explicitly rolled back (`ActiveRecord::Rollback`) — confirmed zero residue in the seed database afterward via a direct count query, not just by inspecting the script.
- Full test suite: **60 runs, 93 assertions, 0 failures, 0 errors, 0 skips** (run twice — once before, once after a self-caught test bug, see below — and a final confirmation run after the clean-DB cycle).
- Pre-existing `test/controllers/health_controller_test.rb` re-run and still passing — confirmed this phase didn't regress Phase 5A's bootstrap.

**A minor, self-caught, self-corrected test-writing bug — not logged as an AI correction, and here's why:** the first `table_test.rb` write had a structural bug (a `Table#update_column` call sitting outside its intended `assert_raises` block), causing that one test to ERROR rather than pass — the underlying database CHECK constraint was correct and working throughout; only the test's own structure was momentarily wrong. Caught immediately by running the suite, fixed in the same turn, re-verified. This doesn't fit `ai-corrections.md`'s pattern (a design/reasoning error a human — or human review — had to catch); it's an ordinary test-writing slip caught by the test suite doing exactly what it's for, in the same session it was written, with no design implication. Consistent with this project's standing rule not to pad that file's signal (see Sessions 6/7/9/10 for the same reasoning applied to other non-qualifying cases).

**Also self-caught during the Rails-console verification (§35), not a code bug:** the first attempt at the verification script wrapped a deliberately-failing raw SQL statement (Example 3) directly inside the outer disposable transaction without a savepoint — PostgreSQL correctly aborted the entire enclosing transaction in response (`PG::InFailedSqlTransaction`), which is expected Postgres behavior, not a schema or application defect. Fixed by wrapping that one check in `ActiveRecord::Base.transaction(requires_new: true)` (a savepoint) so its expected failure doesn't poison the rest of the verification. Re-ran cleanly; confirmed no residue was left by the failed first attempt either (`QueueEntry` count for the disposable phone-number pattern was `0` before any fix was applied, since the entire outer transaction had correctly never committed).

**Documentation updated:** `data-model.md` got a short "Implemented as of Phase 5B.2" addendum recording the three decisions above — `domain-model-proposal.md` and `domain-model.md` were deliberately **not** touched, since the entity/invariant model itself didn't change, only implementation-detail specifics already fully captured in the `data-model.md` addendum (matching this prompt's own §37 instruction not to rewrite product decisions unnecessarily).

**Security/secrets check (§40):** reviewed the full diff — no passwords, API keys, tokens, `.env` files, or machine-specific secrets found. No demo `StaffUser` was seeded (the prompt's §4 only required one "if the existing specification expects one" — it doesn't), so there were no demo credentials to document either.

**AI working record updated this session:** `agent-prompts.md` (Prompt 13, condensed but complete), `session-log.md` (this entry), `agent-decisions.md` (the three implementation decisions above, plus the ambiguity-resolution reasoning for `seating_code`'s location).

**Scope boundary honored:** no guest/staff APIs, no allocation algorithm (compatibility scoring, aging, starvation policy, table matching), no Redis/Sidekiq/background workers/notifications/live updates/rate limiting, no frontend business flows. Only `backend/{Gemfile, Gemfile.lock, db/migrate/, db/schema.rb, db/seeds.rb, app/models/*, test/models/*}` and the three documentation files above were touched.

**Git checkpoint:** reviewed via `git status`/`git diff --stat` before committing — see the session's final report for the exact commit hash and message.

**Next session (not yet run):** Phase 5B.3 or equivalent — the allocation service, staff confirmation, and/or the guest/staff APIs, per whatever the candidate authorizes next.

---

## Session 12 — 2026-08-16 — Phase 5B.3: first business API (guest join + idempotency)

**Environment:** Claude Code CLI, same repository, continuing directly from Session 11 in the same conversation. Backend/frontend/postgres containers still running from earlier sessions.

**Phase 5B.3 — Guest Join API + Idempotency.** The candidate's governing prompt (`Phase_5B_3_Guest_Join_API_Prompt(1).md`) was delivered complete in one piece — no truncation this time.

**Implementation (all inside the running `backend` container):**
- Route: `POST /guest/queue-entries` under `namespace :guest`, matching the route already defined in `api-spec.md` rather than the prompt's own illustrative `POST /guest/join` (§4 explicitly instructs following the existing spec's route over inventing a new one).
- `Guest::JoinService` (`app/services/guest/join_service.rb`): owns the idempotency decision and the create-vs-replay-vs-conflict logic. A first, non-authoritative `find_by(idempotency_key:)` check short-circuits the ordinary sequential-retry path; the actual concurrency guarantee is the database's own unique index on `idempotency_key`, surfaced via a `rescue ActiveRecord::RecordNotUnique` that resolves exactly like a normal retry would (create / idempotent_replay / conflict, per whether the retried input matches the original).
- `Guest::QueueEntriesController` (`app/controllers/guest/queue_entries_controller.rb`): thin — translates the service's `Result` into `201` (created), `200` (idempotent replay), `409` (conflict), or `422` (validation_error), with a consistent `{ error: { type, message, details } }` shape for failures.
- 22 new tests across 3 files: `test/services/guest/join_service_test.rb` (14 unit tests — happy path, validation, retry/replay, conflict, same-phone-different-keys, multiple visits, token properties, no-allocation), `test/services/guest/join_service_concurrency_test.rb` (1 real-thread concurrency test, `use_transactional_tests = false`, `Queue`-based start barrier, per this project's own `hard-path-testing` skill), `test/controllers/guest/queue_entries_controller_test.rb` (8 integration tests over actual HTTP requests/responses).

**A genuine, self-caught concurrency bug — recorded as CORR-005 (`ai-corrections.md`):** the dedicated concurrency test failed on first run (`Expected: [:created, :idempotent_replay], Actual: [:created, :validation_error]`). Diagnosed via a disposable `bin/rails runner` reproduction: `QueueEntry`'s pre-existing `validates :idempotency_key, uniqueness: true` (added in Phase 5B.2, before this service existed) ran its own `SELECT` immediately before the `INSERT`, and under real thread concurrency could itself observe the other thread's just-committed duplicate and raise `ActiveRecord::RecordInvalid` — a different exception from the `ActiveRecord::RecordNotUnique` the service's rescue logic assumed for the race case, non-deterministically depending on timing. Fixed at the root, consistent with CORR-004/INV-016's established philosophy: removed `uniqueness: true` from the model (kept `presence: true`), making the database's unique index the single, self-contained source of truth for this invariant. A stale model test that had asserted the old (buggy) behavior was corrected to assert the new one. Full suite and 5 repeated standalone runs of the concurrency test confirmed the fix, with no regressions (84 runs, 146 assertions, 0 failures throughout).

**Two ambiguity resolutions in favor of the already-approved `api-spec.md` over the prompt's own illustrative wording (recorded in `agent-decisions.md`):** the route (`/guest/queue-entries`, not `/guest/join`) and the request field name (`phone_number`, not `phone`) — both cases where the prompt's §4/§5 explicitly said to prefer the existing spec if one already defines the shape.

**Position deliberately omitted from the response (§18's explicit prohibition on implementing queue position in this phase):** documented as a divergence from `api-spec.md`'s original response shape, not a silent omission — see the "Implementation status (Phase 5B.3)" note added to `api-spec.md`'s join section.

**Verification actually performed, not claimed without running it:**
- Full suite: 84 runs, 146 assertions, 0 failures, 0 errors, 0 skips — run after the CORR-005 fix, and again after a full clean-database rebuild (`db:drop db:create db:migrate db:seed`, §26).
- Manual curl verification (§25) against the running backend, using disposable data cleaned up immediately afterward (confirmed `QueueEntry.count == 0` post-cleanup, with the 40 seeded tables and 19 adjacency pairs undisturbed): first join → `201` with `{ entry_id, active_visit_token, status: "waiting" }`; exact retry (same key/data) → `200` with the identical `entry_id`/token; conflicting retry (same key, different `group_size`/`phone_number`) → `409` with the original entry's data unchanged; invalid `group_size` → `422` with a `validation_error` body.
- One environmental hiccup during manual verification, not a code defect: the long-running dev server (up ~3 hours) hadn't picked up the new `app/services/guest/` directory tree and briefly raised `NameError: uninitialized constant Guest::QueueEntriesController::JoinService` on the first curl call. Confirmed via `bin/rails runner` that `Guest::JoinService` resolved correctly in a fresh process; fixed by restarting the `backend` container, then re-ran all curl scenarios cleanly. Not logged as an AI correction — it's a dev-server-reload artifact of a long implementation session, not a design or code defect.

**Documentation updated:** `api-spec.md` (join endpoint — added the `conflict` error case and an explicit "Implementation status (Phase 5B.3)" note distinguishing what's implemented now from what's deferred: `position` and the DEC-011 oversized-group rejection, both blocked on the not-yet-built allocation service), `01-requirements/traceability.md` (REQ-GUEST-001, REQ-GUEST-007, DEC-011 rows filled in with implementation/test references and explicit "deferred" notes where applicable).

**Security/secrets check (§31):** reviewed the diff — no passwords, API keys, tokens, `.env` files, or machine-specific secrets. No demo credentials introduced (guest join requires no authentication).

**AI working record updated this session:** `agent-prompts.md` (Prompt 14), `session-log.md` (this entry), `agent-decisions.md` (route/field-name resolutions, the position-omission decision, CORR-005 cross-reference).

**Scope boundary honored:** no guest position/leave, no allocation (compatibility scoring, table/adjacency selection, weighted aging, starvation), no staff APIs, no Redis/Sidekiq/notifications/live updates/rate limiting, no frontend business flows. Only `backend/config/routes.rb`, `backend/app/services/guest/`, `backend/app/controllers/guest/`, `backend/app/models/queue_entry.rb` (the CORR-005 fix), `backend/test/{services,controllers}/guest/`, `backend/test/models/queue_entry_test.rb` (the CORR-005 regression-consistent assertion), and the three documentation files above were touched.

**Git checkpoint:** reviewed via `git status`/`git diff --stat` before committing — see the session's final report for the exact commit hash and message.

**Next session (not yet run):** Phase 5B.4 or equivalent — likely the allocation service and/or staff confirmation flow, per whatever the candidate authorizes next.

---

## Session 13 — 2026-08-16 — Phase 5B.4: guest current-visit status + informational position

**Environment:** Claude Code CLI, same repository, continuing directly from Session 12 in the same conversation. Backend/frontend/postgres containers still running.

**Phase 5B.4 — Guest Current Queue Status + Position.** The candidate's governing prompt (`Phase_5B_4_Guest_Current_Queue_Status_Position_Prompt(1).md`) was delivered complete in one piece.

**First task, done before any code (per the prompt's own §3): reconciled position semantics.** `functional-spec.md` §9 and DEC-005 define the *eventual* guest position as reflecting current table availability, compatibility, wait-time aging, and starvation-protection state — the full output of `seating-allocation-policy.md`. This phase's own §4/§10 explicitly forbid implementing any of that (compatibility scoring, weighted aging, starvation scoring, table matching) until Phase 5B.5. This is a real, narrow tension between an approved decision and this phase's own boundary — resolved the same way as Phase 5B.3's `position`-omission decision: the prompt itself directly and explicitly authorizes a documented, phase-scoped simplification rather than leaving the tension for the agent to invent an answer to. Chosen representation: **a chronological rank among currently-`waiting` entries only** (how many other `waiting` groups joined earlier, plus one) — the only input left available once compatibility/aging/starvation are all off-limits. Documented, not silently substituted, in both `api-spec.md`'s new "Position semantics" note and here.

**Implementation (all inside the running `backend` container):**
- Route: `GET /guest/queue-entries/current` — a `collection` route on the existing `guest/queue_entries` resource (matches the route already defined in `api-spec.md`).
- `Guest::CurrentQueueStatusService` (`app/services/guest/current_queue_status_service.rb`): resolves `active_visit_token` → `QueueEntry` via the existing unique index (`QueueEntry.lock.find_by(active_visit_token:)`, inside a transaction — the same `SELECT ... FOR UPDATE` pattern `domain-model-proposal.md` §11 already specified for this exact case), applies the DEC-015 lazy-expiration check inline if the entry is `ready` and overdue (releases the `SeatingAssignment` and its `SeatingAssignmentTable` row(s), transitions the entry to `no_show`), then computes the chronological position only for entries still `waiting`.
- `Guest::QueueEntriesController#current` (extended, not a new controller — thin, translates the service's `Result` into `200`/`404`).
- **Token transport fixed as an implementation decision** (api-spec.md had explicitly left this "not yet fixed"): `Authorization: Bearer <active_visit_token>` — chosen over a query string or path segment specifically so the token never lands in server/proxy access logs or browser history.
- 22 new tests: 15 in `test/services/guest/current_queue_status_service_test.rb` (token resolution, waiting/position, ready-not-expired, DEC-015 expiration including persistence and the not-yet-overdue no-op case, all four terminal-state shapes, no-allocation-side-effects), 7 in `test/controllers/guest/current_queue_status_controller_test.rb` (real HTTP requests: waiting+position, missing header, unknown token, cross-guest isolation, ready+seating_code, seated-only-status, no side effects across repeated GETs).

**No genuine AI mistake occurred this session** — every test passed on first run (105 total after this phase's additions, 0 failures), so no `ai-corrections.md` entry was added. Recorded here explicitly per the prompt's own §25/§26 instruction not to manufacture a correction that didn't happen.

**Verification actually performed, not claimed without running it:**
- Full suite: 105 runs, 200 assertions, 0 failures, 0 errors, 0 skips.
- Manual curl verification (§22), using disposable join data cleaned up immediately after (`QueueEntry.count == 0` post-cleanup; 40 tables / 19 adjacency pairs undisturbed): three waiting guests created via the real join endpoint, first guest's read → `position: 1`, third guest's read → `position: 3`; an unknown token and a request with no `Authorization` header both → `404` with the same `not_found` body; `SeatingAssignment`/`SeatingAssignmentTable` counts confirmed `0` throughout (no side effects from any GET).
- One environmental note, not a defect: the backend container was proactively restarted before manual verification (a known artifact from Phase 5B.3's session — a long-running dev server doesn't pick up brand-new `app/` subdirectories until restarted); this avoided a repeat of that non-issue rather than re-discovering it.
- `ready`/expired-`ready`/`seated`/`left`/`no_show` response shapes were verified via the real HTTP integration test suite (`current_queue_status_controller_test.rb`), not via raw curl — these states can't currently be reached through any implemented API (no allocation service exists yet to create a `ready` entry), so the controller test constructs them directly against the real database and asserts on the real HTTP response, which is the same verification strength curl would add for the states curl actually can reach.

**Documentation updated:** `api-spec.md` (fixed the previously-open "transport... not yet fixed" line to `Authorization: Bearer <token>`; added the "Position semantics" note explaining the chronological-rank simplification and its relationship to the deferred DEC-005 computation; added an "Implementation status (Phase 5B.4)" note), `01-requirements/traceability.md` (REQ-GUEST-002, REQ-GUEST-004 rows filled in, explicitly distinguishing "informational position implemented now" from "full DEC-005 computation deferred to Phase 5B.5").

**Security/secrets check:** reviewed the diff — no passwords, API keys, tokens, `.env` files, or machine-specific secrets. The chosen `Authorization: Bearer` transport was itself picked partly for security reasons (documented above), and the endpoint never echoes another guest's token or full token values in error messages.

**AI working record updated this session:** `agent-prompts.md` (Prompt 15), `session-log.md` (this entry), `agent-decisions.md` (the position-semantics reconciliation, the token-transport decision, the invalid-token-status-code decision).

**Scope boundary honored:** no compatibility scoring, weighted aging, starvation scoring, table matching, or allocation simulation; no `SeatingAssignment`/`SeatingAssignmentTable` creation; no guest leave; no staff APIs; no Redis/Sidekiq/notifications/live updates/rate limiting; no frontend business flows. Only `backend/config/routes.rb`, `backend/app/services/guest/current_queue_status_service.rb`, `backend/app/controllers/guest/queue_entries_controller.rb`, `backend/test/{services,controllers}/guest/current_queue_status_*_test.rb`, and the two documentation files above were touched.

**Git checkpoint:** reviewed via `git status`/`git diff --stat` before committing — see the session's final report for the exact commit hash and message.

**Next session (not yet run):** Phase 5B.5 or equivalent — the allocation service (compatibility-aware aging + starvation protection) and/or staff confirmation flow, per whatever the candidate authorizes next.

---

## Session 14 — 2026-08-16 — Phase 5B.5.1: allocation algorithm reconciliation + specification lock (analysis only, no code)

**Environment:** Claude Code CLI, same repository, continuing directly from Session 13 in the same conversation.

**Phase 5B.5.1 — Allocation Algorithm Reconciliation + Specification Lock.** The candidate's governing prompt (`Phase_5B_5_1_Allocation_Algorithm_Reconciliation_Prompt(1).md`) was delivered complete in one piece. Explicitly analysis/specification only — no allocation service, no `SeatingAssignment` creation, no table selection, no weighted-aging/starvation code, and this session touched zero files under `backend/` (confirmed via `git status` before committing).

**Work performed:**
- Read every named source document (`seating-allocation-policy.md`, `starvation-policy.md`, `allocation-spec.md`, `functional-spec.md`, `api-spec.md`, `domain-model.md`, `data-model.md`, `domain-model-proposal.md`, `07-future-evolution/missed-opportunities.md`, `decision-log.md` DEC-002/003/004/008/011) before writing anything.
- Created `documents/05-specifications/allocation-algorithm.md` — the required dedicated specification, all 24 named subsections present: explicit formulas for `fit_score` (utilization ratio, `group_size / capacity`), `scarcity_score` (`1 / count of currently-compatible available configurations`, computed fresh from the current landscape, never a static seed-time assumption), `aging_score` (linear, hard-capped at `1.0` once `waiting_seconds >= MAX_AGING_WINDOW_SECONDS`, defaulted equal to the starvation threshold), a derived (never stored) `is_starvation_protected` check acting as a categorical override rather than an additive score, a composite `total_score = 0.4·fit + 0.3·scarcity + 0.3·aging` (weights explicitly labeled tunable MVP parameters, justified against `seating-allocation-policy.md`'s own Stage 3/4 split, not blindly assigned), a global batch-matching algorithm (`run_allocation_pass`: build the full waiting-groups × available-configurations grid, exclude non-protected candidates whenever any protected candidate exists, pick the deterministic highest-ranked candidate, allocate, repeat until exhausted — not first-match, not per-table-in-isolation), a derived 4-level tie-break hierarchy (`total_score` → fewer tables consumed → earlier `joined_at` → lower `id`, deliberately NOT the prompt's own suggested 6-level ordering verbatim, since two of its levels were redundant with what `total_score` already expresses — reasoning recorded in both the document and `agent-decisions.md`), 12 worked examples, full pseudocode, concurrency/transaction requirements (unchanged from `allocation-spec.md` §5/§17/`domain-model-proposal.md` §11 — same `SELECT ... FOR UPDATE`, deterministic table-id lock ordering, `READ COMMITTED`), and a known-limitations/future-evolution section.

**A genuine, self-caught specification contradiction — recorded as CORR-006 (`ai-corrections.md`):** while performing this phase's own required cross-document comparison (§23), found that `allocation-spec.md` §4 still specified starvation protection as a **stored**, per-row `starvation_protected_since` field "updated on a schedule" — directly contradicting `domain-model-proposal.md` §7–8 and `data-model.md`'s explicit, already-finalized (Phase 5B.1) "not stored: any position, rank, weight, or starvation-protection flag." This predates the Phase 5B.1.5 consistency pass and fell outside that pass's named audit scope, so it survived undetected until this phase's explicit comparison requirement surfaced it. Corrected `allocation-spec.md` §3–§4 to a pure, derived `is_starvation_protected(G, now)` function — no stored field, no schedule — matching the new `allocation-algorithm.md` §9 exactly. Per the governing prompt's own §23 instruction, the current specification (`allocation-spec.md`) was corrected; the historical/already-correct documents (`domain-model-proposal.md`, `data-model.md`) were left untouched, not rewritten to "match."

**Documents updated (all specification/documentation only):** `documents/05-specifications/allocation-algorithm.md` (new — the primary deliverable), `documents/05-specifications/allocation-spec.md` (§4 corrected per CORR-006, §3 one reference updated for consistency, a top-of-document pointer to `allocation-algorithm.md` added), `documents/05-specifications/functional-spec.md` (§6, one-line pointer to `allocation-algorithm.md` as the now-locked, formula-precise version of the selection step), `documents/05-specifications/api-spec.md` (the Phase 5B.4 "Position semantics" note extended to point at `allocation-algorithm.md`'s formulas as the deferred full computation), `documents/01-requirements/traceability.md` (REQ-TABLE-004/006, REQ-QUEUE-001–004 rows updated to reference `allocation-algorithm.md`, explicitly distinguishing "algorithm locked, Phase 5B.5.1" from "implementation deferred to Phase 5B.5.2"). `seating-allocation-policy.md` and `starvation-policy.md` (DEC-003/DEC-004, human-approved product decisions) were deliberately **not** modified — this phase's formulas implement and make precise what those documents already approved; they don't change the approved policy itself.

**Verification performed (§30's 12-item checklist):** re-read the finalized document; ran `grep -rn "FIFO"` and `grep -rn "starvation_protected_since"` across `documents/` — confirmed no stale "FIFO" rule remains in any authoritative document (only "not FIFO"/"non-FIFO" mentions and one historical `decision-log.md` entry recording that strict FIFO was *rejected*), and confirmed every remaining `starvation_protected_since` mention is now explanatory/corrective, not live pseudocode proposing a stored field; confirmed `position` (`api-spec.md`) remains explicitly distinguished from final allocation priority; confirmed the 1–2 table maximum, 6-seat-standalone, and 2+2/4+4 adjacency semantics are all preserved verbatim from the seed data and DEC-002; confirmed the starvation threshold remains configuration (`STARVATION_THRESHOLD_SECONDS`), not hardcoded; confirmed READY (not SEATED) remains the allocation outcome and allocation is explicitly stated as never performing staff confirmation; confirmed future fairness (§16 of the new document) and AI's runtime-exclusion (§17) are both explicit, separate sections.

**Documentation updated:** see "Documents updated" above.

**AI working record updated this session:** `agent-prompts.md` (Prompt 16), `session-log.md` (this entry), `agent-decisions.md` (Session 14 — the fit/scarcity/aging formula choices, the weight defaults, the tie-break-hierarchy derivation, the starvation-protected-candidates-ordering gap-filling decision). One genuine correction: **CORR-006** in `ai-corrections.md`.

**Scope boundary honored:** no allocation service, no `SeatingAssignment`/`SeatingAssignmentTable` creation, no table selection in application code, no weighted-aging/starvation code, no Redis/Sidekiq/background jobs/notifications/staff APIs/frontend changes. `git status` confirmed zero files under `backend/` were touched this session — documentation-only, as required.

**Git checkpoint:** reviewed via `git status`/`git diff --stat` before committing — see the session's final report for the exact commit hash and message.

**Next session (not yet run):** Phase 5B.5.2 — implementing the allocation service against this now-locked algorithm specification, per whatever the candidate authorizes next.
