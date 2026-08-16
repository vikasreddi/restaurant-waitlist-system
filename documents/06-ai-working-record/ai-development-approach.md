# AI Development Approach

## Methodology

Kiro-style spec-driven agentic development, using Claude Code as the primary AI development environment, per the assignment's stated evaluation criteria (how requirements are interpreted, scope is chosen, decisions are made, AI agents are planned/directed, specifications are created, AI output is reviewed/corrected, hard paths are tested, and the AI working process is documented).

## Project-level workflow (from the Phase 3 governing prompt, §13)

```
Assignment
→ requirements analysis            (Phase 1 — Session 1)
→ human product decisions          (approved decisions fed into Phase 3, §3-9 of the Phase 3 prompt)
→ specification                    (Phase 3 — Session 1; documents/01-05)
→ human specification review       (Session 2 — corrections + architecture/stack decision)
→ AI-native configuration          (Phase 4 — Session 3; CLAUDE.md, .claude/agents, skills, commands, settings)
→ agent-assisted implementation    (not started — explicitly out of scope through Session 3)
→ tests
→ agent review
→ human verification
→ corrections
→ final verification
```

The goal is not to maximize AI-generated volume. The goal is to demonstrate that the candidate can plan, constrain, review, correct, and verify AI-assisted engineering work.

## Per-task workflow for implementation sessions (from the Phase 4 governing prompt, §3; enforced by `CLAUDE.md`)

```
Requirements → Product decisions → Specifications → Implementation plan
→ Small implementation task → Tests → AI review → Human review
→ Commit/checkpoint → Next task
```

This is the operative loop once implementation starts (Session A onward, `session-plan.md`) — the project-level workflow above describes how we got here; this describes how each future task should proceed within that. No implementation task should skip from "requirements" straight to "broad implementation."

## AI governance rules in force

Agents (including this session) **may**:
- identify contradictions;
- identify edge cases;
- propose alternatives;
- challenge assumptions;
- review specifications;
- identify implementation risks.

Agents (including this session) **must not**, silently:
- change business rules;
- change starvation policy;
- change table allocation policy;
- expand scope;
- add unnecessary infrastructure;
- implement future features;
- claim future features are implemented.

Where a contradiction, gap, or open question was found during this session, it is recorded in `agent-decisions.md` and surfaced in the phase completion report, not resolved unilaterally.

## What has and has not been handed to the agent so far

**Handed to the agent (Claude):**
- Session 1 / Phase 1: independent requirements analysis of the raw assignment brief (no code, no files).
- Session 1 / Phase 3: turning already-approved product decisions into a structured documentation/specification set (`documents/01-05`), plus this AI working record (`documents/06`) and future-evolution notes (`documents/07`).
- Session 2 / Phase 3 review: correcting overstated/incomplete Session 1 output per human review, evaluating (not choosing) the candidate's proposed technology stack, tightening the release and idempotency specifications, and expanding the test strategy.
- Session 3 / Phase 4: configuring the AI-native development environment itself — `CLAUDE.md`, four agents, three skills, three commands, and minimal settings — around the now-frozen specification, with several configuration-only judgment calls (MCP, hooks) explicitly delegated to the agent (`agent-decisions.md` "Session 3").

**Deliberately not handed to the agent:**
- The seating allocation algorithm, starvation policy, table seed data, maximum combination size, guest identity mechanism, and idempotency approach were **decided by the candidate** before this session and given to the agent as fixed inputs (see `documents/02-product-decisions/decision-log.md`) — the agent documented and specified these, it did not choose them.
- The technology stack (React + TypeScript, Rails, PostgreSQL, Redis, Sidekiq, Docker Compose) was **proposed by the candidate**, not the agent — the agent's Session 2 role was to evaluate it against the assignment's concurrency/atomicity/idempotency demands and either confirm or flag a serious issue (`02-product-decisions/decision-log.md` DEC-012), per the explicit instruction "do NOT replace it simply because another stack is possible."
- Remaining implementation-level mechanisms (live-update mechanism, seating-code format, guest-abandonment behavior — `OPEN-002`, `OPEN-005`, `OPEN-007`) are intentionally left undecided by the agent, to be resolved by the candidate in the next human-decision step, not defaulted to silently.
- No application code, database migrations, API implementations, or frontend components were written in any of the first three sessions (Phase 1, Phase 3, the Phase 3 review, and Phase 4 are all documentation/configuration-only by explicit instruction — Phase 4's own §16 restates this as a hard boundary even though it authorizes agent/skill/command creation).
- No agents, skills, hooks, or MCP configuration were created in Sessions 1 or 2 (explicitly excluded by those two governing prompts). Session 3 (Phase 4) is the first session where agents, skills, commands, and settings were explicitly authorized and created — see `.claude/` and `session-log.md` Session 3. No MCP servers and no hooks were added even in Session 3, per the judgment calls recorded in `agent-decisions.md`.

## Splitting work across sessions

Session 1 covered both Phase 1 (requirements analysis) and Phase 3 (documentation/specification foundation) sequentially, in one continuous conversation. Session 2 covered the Phase 3 review-correction-and-architecture-decision prompt. Session 3 covered the Phase 4 AI-native configuration prompt. Each ran in a separate conversation continuing from the same working directory. See `session-log.md` for the concrete session record. No parallel-agent split was used for any session.
