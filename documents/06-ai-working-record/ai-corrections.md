# AI Corrections

**Important rule (per governing prompt): do not fabricate AI mistakes or claim an AI agent made a suggestion unless it actually happened in a recorded session.**

The three corrections below are genuine — each is a verifiable defect in the actual Session 1 output, caught during the Session 2 human review prompt (`restaurant_waitlist_phase3_review_architecture_prompt.md`) and corrected in that same session. A template for future examples follows.

---

### CORR-001 — Starvation guarantee overstated (and internally inconsistent)

**Session:** Session 1 (Phase 3 documentation), corrected in Session 2 (Phase 3 review). See `session-log.md`.

**Prompt/context:** Session 1's Prompt 2 asked the agent to document the approved starvation policy, including "what it costs."

**AI suggestion (what was actually written):** `02-product-decisions/starvation-policy.md` originally stated: *"It directly and provably satisfies 'no group waits forever': once past the threshold, the very next moment both required tables are simultaneously free, the protected group is seated ahead of newly-eligible competitors for that same configuration. The wait is therefore bounded by how long it takes for that configuration to next become available, not unbounded by competing traffic."*

**Why it was incorrect/incomplete:** This claimed an effective bound on total wait time. But the same document, two paragraphs later under "What it costs," already stated: *"No guaranteed maximum wait time in absolute terms... a protected group could still wait longer than the threshold in absolute terms."* These two statements directly contradict each other — the "why this policy" section oversold a guarantee that the document's own "what it costs" section correctly disclaimed. The agent was confidently wrong in the stronger claim and did not notice the self-contradiction with its own weaker, correct claim elsewhere in the same file.

**How the human identified the issue:** Explicit human review (Prompt 3, Correction 1) flagged the "provably satisfies" wording as too strong and supplied the corrected guarantee statement directly.

**Correction:** Rewrote the guarantee to: *"Maximum-wait protection guarantees priority when the group's complete compatible seating configuration becomes available. It does not guarantee an absolute maximum total waiting time."* Applied consistently across `starvation-policy.md`, `decision-log.md` (DEC-004), `seating-allocation-policy.md` (Stage 5), `domain-model.md` (INV-013), and `04-diagrams/04-seating-allocation.md`.

**Final decision:** The weaker, precise guarantee is now the only version of this claim anywhere in the documentation set — the overstated version was not left standing alongside it.

**Resulting specification change:** `02-product-decisions/starvation-policy.md`, `02-product-decisions/decision-log.md` (DEC-004), `02-product-decisions/seating-allocation-policy.md`, `03-architecture/domain-model.md` (INV-013), `04-diagrams/04-seating-allocation.md`.

---

### CORR-002 — Algorithm named "Weighted" with no weighting formula ever defined

**Session:** Session 1 (Phase 3 documentation), corrected in Session 2 (Phase 3 review).

**Prompt/context:** Session 1's Prompt 2 supplied the algorithm name "Compatibility-Aware Weighted Aging with Maximum-Wait Protection" verbatim; the agent adopted it as-is into `decision-log.md` and `seating-allocation-policy.md` without checking whether the name matched the actual specified behavior.

**AI suggestion (what was actually written):** The algorithm was documented under the name "...Weighted Aging..." across `decision-log.md` DEC-003, `seating-allocation-policy.md`'s title, `04-diagrams/04-seating-allocation.md`, and referenced elsewhere — but Stage 4's actual behavior, as specified, only ever used raw wait time as a tiebreaker/priority signal. No weighting function, coefficient, or formula combining wait time with anything else was ever defined anywhere in the specification.

**Why it was incorrect/incomplete:** The name implied a more sophisticated mechanism (some weighted combination of signals) than what was actually specified, which risks an implementer inventing an arbitrary weighting formula to "match the name" — exactly the kind of scope-creep the AI governance rules were meant to prevent (`ai-development-approach.md` §AI governance: "must not silently... expand scope").

**How the human identified the issue:** Explicit human review (Prompt 3, Correction 2) noted no weighting function had actually been defined and instructed a rename unless a concrete, necessary formula could be identified — none was.

**Correction:** Renamed to "Compatibility-Aware Aging with Maximum-Wait Protection" everywhere except the verbatim historical quote of Session 1's Prompt 2 in `agent-prompts.md` (preserved unchanged as an accurate record of what was actually said then). The six stages themselves were not altered — this was a naming correction, not a policy change.

**Final decision:** Name corrected; explicit statement added in `seating-allocation-policy.md` and `decision-log.md` DEC-003 that no arbitrary group-size or other weighting is to be introduced.

**Resulting specification change:** `02-product-decisions/decision-log.md` (DEC-003), `02-product-decisions/seating-allocation-policy.md` (title + Stage 4 framing), `04-diagrams/04-seating-allocation.md`, `05-specifications/allocation-spec.md` (status line).

---

### CORR-003 — Release endpoint allowed an ambiguous raw table identifier

**Session:** Session 1 (Phase 3 documentation), corrected in Session 2 (Phase 3 review).

**Prompt/context:** Session 1 specified the staff release endpoint while designing `05-specifications/api-spec.md` without an explicit instruction on exactly what identifier release should take.

**AI suggestion (what was actually written):** `05-specifications/api-spec.md`'s release endpoint originally accepted `{ table_id }` *or* `{ combination_id }` ("exact identifier shape TBD by data model"). The underlying `allocation-spec.md` §6 pseudocode was already written correctly (it operated on `group`/the queue entry and resolved single-vs-combined internally) — but the *API contract* as specified would have let a caller pass a single `table_id` directly, including, in principle, a `table_id` for a table that was part of an active combination, without the API surface itself preventing that half-release path.

**Why it was incorrect/incomplete:** This is inconsistent with the atomicity discipline the rest of the specification insists on for allocation (INV-005) — release should be symmetric ("both-or-neither" applies in both directions), but the documented API shape left a door open to specifying just one member of a combined pair, which the spec text didn't explicitly rule out at the contract level.

**How the human identified the issue:** Explicit human review (Prompt 3, Correction 6) required that release be designed around the seating assignment or queue entry, not an arbitrary individual table.

**Correction:** Changed the release endpoint to accept `{ entry_id }` only; removed `table_id`/`combination_id` as caller-supplied release parameters. The API resolves internally which table(s) the entry holds and releases them atomically. Added `INV-015` to the domain model and `DEC-014` to the decision log to make this an explicit, named invariant rather than an implicit assumption.

**Final decision:** Release is identified by queue entry everywhere in the documentation set — API spec, architecture, diagrams, and test strategy were all updated to match.

**Resulting specification change:** `05-specifications/api-spec.md`, `03-architecture/api-overview.md`, `03-architecture/data-model.md`, `03-architecture/domain-model.md` (INV-015), `02-product-decisions/decision-log.md` (DEC-014), `04-diagrams/03-staff-journey.md`, `04-diagrams/07-architecture-data-flow.md`, `05-specifications/test-strategy.md` (TEST-008, TEST-026).

---

## Template for future real examples

```
### Correction N — <short title>

Session: <session identifier / date, see session-log.md>

Prompt: <what was actually asked of the agent>

AI suggestion: <what the agent actually proposed or produced>

Why it was incorrect/incomplete: <the specific defect — e.g., violated an invariant,
  missed a concurrency case, silently changed scope, treated a stub as production-ready>

How the human identified the issue: <what caught it — code review, a failing test,
  re-reading a spec, manual testing, etc.>

Correction: <what was actually done to fix it>

Final decision: <what the candidate decided going forward>

Resulting specification/code change: <link/reference to the actual diff or doc update>
```

## Where to look, once implementation starts

The Phase 1 analysis (`01-requirements/requirements-analysis.md`) already flagged 10 high-risk areas for an AI agent to be confidently wrong on this project (FIFO defaulting, frontend-only idempotency, non-atomic combined allocation, app-level-only concurrency checks, phone-number-as-auth, missed cache invalidation on no-show/release, vague starvation heuristics, over-reserving a lone table, overengineering, and happy-path-only tests). CORR-001 through CORR-003 above are a first, concrete instance of the same failure class (confident overstatement / incomplete specification) occurring one level up, in the specification itself rather than in code — worth watching for again once implementation starts, since a confidently-wrong spec can propagate into confidently-wrong code that matches it.
