# Agent Decisions

Record of judgment calls the agent made autonomously (within the "may identify contradictions/edge cases/alternatives" governance bound), and of items the agent explicitly declined to decide and surfaced for human review instead. See `ai-development-approach.md` for the governing rules.

## Decisions the agent made autonomously (organizational/editorial, not business rules)

| Item | What the agent chose | Why it's in-bounds |
|---|---|---|
| Project folder location | Asked the candidate directly rather than guessing (`~/Documents/restaurant-waitlist` chosen by the candidate) | Filesystem location is not a product/architecture decision; asking rather than assuming avoided silently placing the repo somewhere the candidate didn't intend |
| Splitting the 7 required diagrams into 7 separate files under `04-diagrams/` (`01-system-context.md` ... `07-architecture-data-flow.md`) rather than one combined file | Editorial/organizational choice | The Phase 3 prompt names 7 diagrams but does not mandate one-file-vs-many; separate files keep each diagram independently reviewable |
| Splitting the domain entity `TableCombination` out as its own row/table in `data-model.md` rather than a field on `Table` | Flagged explicitly as **not decided** — `data-model.md` states both are open until the implementation phase, and only proposes the split as the clearer default for spec-writing purposes | Marked explicitly as non-final in the document itself, not silently committed as a schema decision |
| Requirement/invariant/test ID scheme (`REQ-*`, `INV-*`, `NFR-*`, `TEST-*`, `DEC-*`, `OPEN-*`) | Carried forward and extended consistently from the Phase 1 analysis's own ID scheme | Purely a documentation-traceability convention, not a product decision |

## Session 2 — decisions made under explicit delegated criteria (not silent)

The Session 2 prompt explicitly asked the agent to evaluate two specific items against stated criteria and recommend a choice — this is different from Session 1's items above (organizational/editorial) and different from the still-open items below (genuinely undecided): here the human delegated the *evaluation*, and the agent's output is a recommendation subject to candidate approval, not a unilateral change to an approved decision.

| Item | Agent's recommendation | Criteria the human supplied |
|---|---|---|
| Oversized-group handling (DEC-011) | Option A — reject the join at submission with a validation error | "Prefer the option that gives the clearest correctness guarantee and simplest implementation" (Prompt 3 §7) |
| Technology stack (DEC-012) | Keep the candidate's proposed stack unchanged; no serious issue found | "Do NOT replace it simply because another stack is possible... if the stack is suitable, explicitly recommend keeping it" (Prompt 3 §8) |

Both are recorded in `02-product-decisions/decision-log.md` (DEC-011, DEC-012) with full evaluation and are explicitly labeled as pending the candidate's final sign-off, per the Session 2 prompt's closing line: "the next phase will begin only after the candidate reviews and approves this output."

## Items explicitly NOT decided by the agent — surfaced for human review

These are recorded as open in `02-product-decisions/decision-log.md` (§Open decisions) and must not be treated as resolved by anything else in `documents/`. Resolved this round: `OPEN-001` (DEC-012), `OPEN-003` (DEC-013), `OPEN-004` (partially — key format only), `OPEN-006` (DEC-011).

| ID | Item | Where it surfaces |
|---|---|---|
| OPEN-002 | Live-update mechanism (polling / SSE / WebSockets) | `03-architecture/architecture.md` §7, `04-diagrams/07-architecture-data-flow.md` |
| OPEN-005 | Seating-code format/strength | `05-specifications/api-spec.md` |
| OPEN-007 | Guest abandonment/expiration behavior (no explicit timeout requirement stated in the brief) | `02-product-decisions/decision-log.md`, `07-future-evolution/production-evolution.md` |

None of these three remaining items were addressed by the Session 2 prompt, so none were resolved — they carry forward unchanged.

## Contradictions checked for and not found

**Session 1:**
- Cross-checked the Phase 3 prompt's "Approved Product Decisions" (§3) and "Final Seating Allocation Algorithm" (§4) against the Phase 1-derived requirements (`01-requirements/`) for conflicts — none found; the approved decisions satisfy REQ-QUEUE-001/002/003 as analyzed in Phase 1.
- Checked the starvation policy's "critical rule" (protect the complete configuration, not a single table) against the brief's own worked example — consistent, not contradictory.
- Checked the P0/P1/Future scope split (§10 of Prompt 2) against the brief's "must-have" vs. "show us if you can" vs. "your call" sections — consistent; nothing in P0 as defined here exceeds what the brief calls must-have, and nothing the brief calls must-have was pushed into P1/Future.

**Session 2 (this review):**
- The three genuine defects found in Session 1's own output (starvation-guarantee overstatement, unjustified "Weighted" naming, ambiguous release identifier) are documented in full as CORR-001 through CORR-003 in `ai-corrections.md`, not summarized here.
- Checked the Session 2 prompt's stack-evaluation criteria (§8) against `01-requirements/non-functional-requirements.md` (NFR-CONC-001/002, NFR-IDEM-001/002) for coverage gaps — none found; every hard requirement maps to a concrete PostgreSQL/Rails mechanism (`decision-log.md` DEC-012).
- Checked whether resolving DEC-011 (reject oversized joins) conflicts with any P0 requirement — none found; REQ-GUEST-001 requires accepting *valid* joins, and does not require accepting groups the system has no configuration to seat.

No contradictions were found that required escalation beyond the open items listed above.

## Session 3 (Phase 4 — AI-native configuration) — decisions made under delegated judgment

The Phase 4 prompt explicitly delegated several configuration choices to the agent's judgment rather than specifying them exactly. These are recorded here, not treated as product/architecture decisions (they configure *how agents work*, not *what the product does*), but recorded for the same transparency reason.

| Item | What the agent chose | Reasoning |
|---|---|---|
| MCP servers | **None added.** | The prompt named three candidate categories (git/repo context, doc/spec retrieval, DB inspection) but required determining genuine usefulness first, not adding by default. Git context is already fully served by the `Bash` tool available to every agent (no MCP needed to run `git log`/`git diff`/`git blame`). Documentation/spec retrieval is already fully served by `Read`/`Grep`/`Glob` against a small, flat `documents/` tree — an MCP server would add indirection with no capability gain at this scale. Database inspection is premature: no database exists yet (no Rails app scaffolded), so there is nothing to inspect; this is worth revisiting once Session B (database/domain model) exists, not now. Documented per the prompt's required phrasing in `session-log.md`. |
| Hooks | **None added in `.claude/settings.json`.** | No Rails/npm project exists yet — a lint or test hook would fail immediately (nothing to run), which is worse than no hook. Deferred to the bootstrap session, once `bundle exec rspec`/`rubocop`/a frontend test command actually exist to hook into. |
| Permission-protection mechanism for approved decisions | Used a permission **`ask` rule** (`Edit`/`Write` on `documents/02-product-decisions/**`) instead of a `PreToolUse` hook. | Achieves the same practical goal (force confirmation before an implementation agent edits an approved decision) with a static, easily-verified JSON rule instead of a shell-scripted hook that would need to be constructed and pipe-tested against synthetic stdin per the config skill's own verification workflow — lower complexity and lower fragility risk for a two-day project, per the prompt's explicit "do not create slow/unnecessary hooks" guidance. |
| Agent tool-grants (`spec-reviewer`, `code-review-agent` = read-only; others = read+write+bash) | Restricted `spec-reviewer` to `Read, Grep, Glob` and `code-review-agent` to `Read, Grep, Glob, Bash` (no `Write`/`Edit`) | Enforces "must not implement application code" / "must not silently modify code during review" at the tool-permission level, not only via a prompt instruction an agent could drift from — a stronger guarantee than instruction text alone. |
| Requirement traceability format | A single flat Markdown table (`documents/01-requirements/traceability.md`) covering Requirement → Specification → Implementation → Test, no per-requirement files, no generated tooling | The prompt explicitly said "do not create a complicated tracking system... a simple Markdown mapping or checklist is sufficient" — this is the simplest structure that still lets `code-review-agent` and the `/requirements-check` command do their job. |
| Session-boundary guidance location | Wrote it as a new `documents/06-ai-working-record/session-plan.md` rather than inlining the full Session A–K breakdown into `CLAUDE.md` | Keeps `CLAUDE.md` itself short (it links to session-plan.md); the source prompt's own instruction was "do not duplicate large sections of these documents into configuration files." |

None of these are product/architecture decisions and none required a `BLOCKED — HUMAN DECISION REQUIRED` escalation — they were explicitly left to agent judgment by the governing prompt itself ("use your judgment," "if no MCP provides meaningful benefit... this is an acceptable outcome," "if hooks are not necessary, document why").

## Contradictions checked for — Session 3

- Checked the four agents' assigned tool grants against `CLAUDE.md`'s AI rules ("must not... claim completion without verification") — `backend-domain-agent` and `test-engineering-agent` both have `Bash` (needed to actually run tests), so "claim completion without verification" is a prompt-level rule for those two, not a tool-level one; no contradiction, just a different enforcement layer than the read-only agents.
- Checked that no agent, skill, or command in `.claude/` implements, references, or scaffolds a `documents/07-future-evolution/` item — none do.
- Checked that the technology stack referenced throughout `.claude/` matches the approved DEC-012 stack exactly (no drift, e.g., no accidental mention of a different queue/cache technology) — confirmed consistent.

No contradictions found requiring escalation.

## Session 4 (Phase 5A — bootstrap) — environment decision surfaced to the candidate, not decided silently

| Item | What happened | Why it was surfaced rather than decided unilaterally |
|---|---|---|
| Container runtime choice (no Docker/Colima/Podman found on the machine) | Agent presented four concrete options (Colima+CLI, Docker Desktop, candidate installs manually, skip Docker/proceed unverified) via a direct question rather than picking one. **Candidate chose Colima + Docker CLI.** | Installing a container runtime is a meaningfully impactful, not-trivially-reversible system change (background VM, networking changes, potential GUI/privileged-helper setup) — Prompt 5 §2 itself explicitly forbids installing global software automatically, and this falls squarely in that category even though Docker is required infrastructure for the approved stack (DEC-012). |
| Response to the Homebrew `/usr/local` permission failure | Agent did not attempt `sudo chown` itself, and did not attempt any workaround (e.g., reinstalling Homebrew to a user-writable prefix, using `--build-from-source`, or a manual tarball install of Colima/Docker binaries bypassing Homebrew). Reported the exact fix and asked the candidate to run it. | The fix requires `sudo` (the candidate's password, which the agent cannot supply) and touches ~25 system-wide directories under `/usr/local` that affect every Homebrew-managed tool on the machine, not just this project — well outside "project-local" scope, and irreversible-by-the-agent if done wrong. Matches the standing guidance to check before hard-to-reverse, broad-blast-radius actions. |

This is recorded as a **process/environment decision**, not a product or architecture decision — it does not touch anything in `documents/02-product-decisions/` and required no `BLOCKED — HUMAN DECISION REQUIRED` escalation (that format is reserved for architectural contradictions, missing product decisions, or correctness-affecting ambiguity, none of which occurred here — this was a pure tooling/permissions blocker).

## Session 5 (Phase 5A resume — bootstrap completed) — decisions made autonomously and ones surfaced

| Item | What happened | In-bounds reasoning |
|---|---|---|
| Manually symlinking `docker`, `colima`, `limactl` into `/usr/local/bin` after `brew link` failed only on an unrelated fish-completions directory | Agent did this itself, without asking, rather than requesting a third `sudo chown` round | Judged as the "smallest necessary correction" under the troubleshooting rule (Prompt 7 §10): the formulae were already installed by Homebrew into `/usr/local/Cellar` (the part that succeeded); the only failure was linking convenience files for a shell (fish) nobody here uses. Creating symlinks in an already-writable directory (`/usr/local/bin`, confirmed group-writable) to already-installed, Homebrew-placed binaries is non-destructive, fully reversible (`brew unlink`/`brew link` still work normally), and installs nothing new — a meaningfully different, much lower-stakes action than the sudo-requiring chown calls that were escalated. |
| Surfacing the Rosetta/Homebrew-architecture discovery to the candidate rather than silently installing a native Homebrew | Agent stopped and asked, with concrete options, rather than picking one | This was a genuinely new architectural fact about the machine (not something either prior session had reason to know), and the fix (a second Homebrew installation, a meaningful and slightly unusual system change) itself needed an interactive sudo password the agent cannot supply — squarely the same "stop and ask for a human administrator action" case as Session 4's permission issues, per Prompt 7 §2 and §10. |
| Rails version: pinned `~> 7.1.6` (not Rails 8) | Agent's implementation-phase choice, not escalated | `documents/03-architecture/architecture.md` OPEN items never specified an exact Rails minor/major version — only "Ruby on Rails API" was approved (DEC-012). Rails 7.1 was chosen specifically to avoid Rails 8's newer default scaffolding (Kamal deploy config, Solid Queue/Cache/Cable) that would otherwise need explicit `--skip-*` flags to stay consistent with "do not introduce unnecessary infrastructure" — a judgment call within the approved stack, not a deviation from it. |
| Ruby 3.3.12, Node 20, minitest pinned to `~> 5.20` | Agent's implementation-phase choices | Ordinary dependency/runtime version selection within an already-approved stack; the minitest pin specifically fixes a real compatibility bug (see `session-log.md` Session 5 "Problem encountered"), not a design choice. |
| `--skip-git` on `rails new` | Agent's choice, not asked | The overall project has no git repository (true since Session 1, never established). Letting `rails new`'s default `git init` create a nested repository inside `backend/` only would have been a worse, harder-to-notice state than no repository at all. Not initializing the top-level repository either was already the standing position from Session 4 — carried forward, not re-decided. |

None of these required `BLOCKED — HUMAN DECISION REQUIRED` — the symlink and version-pin items are ordinary implementation judgment calls within already-approved scope (per `CLAUDE.md` "AI rules: agents may... implement within assigned scope"), and the two environment items that genuinely warranted a stop (residual permissions, Rosetta architecture) were in fact stopped and surfaced, not decided silently.

## Contradictions checked for — Session 5

- Checked that nothing generated by `rails new` or `create-vite` (default templates, boilerplate files, generated READMEs) implements or references any P0 business behavior — confirmed clean; only the explicitly-added `HealthController` and status-page `App.tsx` touch application logic, both within Prompt 5/7's explicit bootstrap scope.
- Checked the `rack-cors` configuration against `documents/02-product-decisions/decision-log.md` DEC-013 (Redis/cache boundary) — not applicable/no conflict; CORS is a browser-security concern unrelated to the cache-authority invariant.
- Checked that `backend/bin/docker-entrypoint`'s `rails db:prepare` call does not implicitly create any business schema — confirmed; zero migrations exist, so it only creates Rails' own internal tracking tables (`schema_migrations`, `ar_internal_metadata`), consistent with Prompt 5/7 §7 ("no business schema yet, only whatever minimal Rails database setup proves the app can connect").

No contradictions found requiring escalation.

## Session 6 (Phase 5A.1 — cleanup + git checkpoint) — judgment calls

| Item | What happened | Reasoning |
|---|---|---|
| Default git branch named `main` (not git's own default `master`) | Agent set this via `git symbolic-ref HEAD refs/heads/main` before the first commit, without asking | Ordinary, low-stakes tooling convention (now the standard default on GitHub/GitLab and most modern tooling); not a product/architecture decision, fully within "agents may... implement within assigned scope" for a task explicitly about setting up git. |
| `.gitignore` includes `backend/config/master.key` even though the governing prompt's example list didn't name it | Agent added it | The prompt's §7 explicitly says "do not commit secrets, passwords, private credentials" — Rails' `config/master.key` is exactly that category (it's the decryption key for `credentials.yml.enc`); omitting it would have been a real gap in "inspect before commit," not a faithful reading of the instruction's intent. |
| Generating `frontend/package-lock.json` (missing from the host) before committing | Agent did this as part of §7's "review the files that will be committed," not asked for explicitly | Discovered during the required pre-commit review, not invented busywork; committing a Node project without its lockfile would undermine "the commit should represent the Phase 5A runnable baseline" (§7/§8) — a reproducibility gap directly relevant to what this checkpoint is for. Did not touch anything else in `frontend/` or `backend/` beyond this. |
| Author identity on the first commit (`vikas@Rajas-Air.lan`, auto-derived) | Agent did not configure `git config user.name`/`user.email` globally or locally, and did not guess the candidate's real name/email | Guessing or fabricating a person's name/email for commit authorship isn't the agent's call to make; flagged to the candidate in the session report instead, so they can set it (and optionally amend the commit) themselves if it matters for how the assignment reads. |

None of these required `BLOCKED — HUMAN DECISION REQUIRED` — all four are ordinary tooling/process judgment calls within the explicit scope of "git setup" and "inspect before commit," not product, architecture, or business-behavior decisions.
