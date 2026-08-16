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

### CORR-004 — Table-exclusivity index couldn't actually do what it claimed

**Session:** Session 7 (Phase 5B.1 domain model proposal), corrected in Session 8 (human review of that proposal).

**Prompt/context:** Phase 5B.1 asked the agent to propose a database-level constraint enforcing "one active occupant per table," as part of designing `SeatingAssignmentTable` (the join entity between `SeatingAssignment` and `Table`).

**AI suggestion (what was actually written):** `05-specifications/domain-model-proposal.md` gave `SeatingAssignmentTable` its own `status` column ("denormalized copy of the parent assignment's status, written together in the same transaction") and proposed the exclusivity guarantee as a **partial unique index**: `UNIQUE (table_id) WHERE status IN ('pending','active')`. The document confidently described this as "the database-level enforcement of 'one group per table'... almost entirely from the constraint system."

**Why it was incorrect/incomplete:** PostgreSQL partial-index predicates can only reference columns of the table the index is built on — they cannot reach into another table (here, the parent `seating_assignments.status`) to decide inclusion. The proposal's own denormalized-column workaround was syntactically valid, but its correctness then depended entirely on an *application-level promise* ("always written together in the same transaction") that nothing in the schema actually enforced — a bug, a partial update, or a future engineer forgetting the pairing would silently break the exclusivity guarantee the document claimed was database-level. This is the same overclaiming pattern as CORR-001 (a guarantee stated more confidently than the underlying mechanism actually delivers), recurring at the schema-design level this time instead of the policy-wording level.

**How the human identified the issue:** Direct review of the proposed constraint against actual PostgreSQL partial-index semantics — the human caught that the predicate as designed could not reference the parent's status at all, and separately noticed the readiness-hold-forever gap (see the open-decision item this closes, `documents/05-specifications/domain-model-proposal.md` §16 item 2).

**Correction:** Removed the `status` column from `SeatingAssignmentTable` entirely. The corrected design uses row *existence* instead of a status flag: a claim row is created when a `SeatingAssignment` is formed and **deleted** (not status-flagged) when it's released. Table exclusivity is then a single **plain** unique index on `table_id` — no predicate, no cross-table reference, no denormalization to keep in sync. `held` vs. `occupied` (pending vs. active assignment) becomes a read-time join to the parent's status, not a write-time concern for the claim row.

**Final decision:** The corrected design is adopted throughout `domain-model-proposal.md` (§0, §2, §4, §5, §6, §13) — not just noted as a caveat. The underlying entity choice (a join table over two nullable FK columns) was correct and unchanged; only its specific shape needed the fix.

**Resulting specification change:** `05-specifications/domain-model-proposal.md` §0 (new revision items 6–7), §2 (`SeatingAssignmentTable` entity), §3 (relationship diagram wording), §4 (constraints table), §5 (indexes table), §6 (Table/SeatingAssignment state diagram), §11 (concurrency plan), §13 (Combination representation alternatives).

---

### CORR-005 — Redundant Rails-level uniqueness validation raced the database constraint it was supposed to defer to

**Session:** Session 12 (Phase 5B.3, guest join API + idempotency implementation).

**Prompt/context:** Phase 5B.3 required `Guest::JoinService` to guarantee that two requests carrying the same client-generated `idempotency_key` never produce two `QueueEntry` rows, including under real concurrency — the idempotency invariant from `CLAUDE.md` and INV-016's self-contained-constraint principle. The service was written to rescue `ActiveRecord::RecordNotUnique` from the database's own unique index on `idempotency_key` as the authoritative concurrency guarantee, per the same design philosophy as CORR-004.

**AI suggestion (what was actually written):** `QueueEntry` (added in the prior session, Phase 5B.2) still carried `validates :idempotency_key, presence: true, uniqueness: true` — a normal Rails uniqueness validation left over from before the dedicated join service existed. `Guest::JoinService#create_new_entry` was written to rescue two different exceptions for what should be the same case: `ActiveRecord::RecordInvalid` (treated as a generic bad-input validation error, HTTP 422) and `ActiveRecord::RecordNotUnique` (treated as the idempotency race, resolved as a replay or conflict). The service's dedicated concurrency test (`test/services/guest/join_service_concurrency_test.rb`, using real threads and `use_transactional_tests = false`) failed: `Expected: [:created, :idempotent_replay], Actual: [:created, :validation_error]`.

**Why it was incorrect/incomplete:** Rails' `uniqueness: true` validation runs a `SELECT` immediately before the `INSERT`, inside the same request/thread, before the database's unique index is ever touched. Under genuine concurrency, that `SELECT` can itself observe the other thread's just-committed row and raise `ActiveRecord::RecordInvalid` — a completely different exception from `ActiveRecord::RecordNotUnique`, for the exact same underlying event (a duplicate `idempotency_key`), non-deterministically depending on thread timing. The service's `RecordInvalid` rescue branch had no way to distinguish "genuinely invalid input" from "this is actually a duplicate-key race that lost to a same-millisecond SELECT," so it silently misclassified a valid idempotent retry as a 422 validation error — a functional violation of the idempotency invariant, only reachable under real concurrency (which is exactly why the ordinary sequential unit tests, and even sequential manual retries, never caught it: `JoinService#call`'s own `find_by` check absorbs sequential duplicates before `create_new_entry` is ever reached).

**How the human identified the issue:** Not human-caught — self-caught by the project's own hard-path concurrency test during Phase 5B.3 implementation, per this project's own hard-path-testing skill and the governing prompt's explicit self-correction protocol (stop, diagnose, explain, correct, add/confirm a regression test, record it here). Diagnosis was confirmed with a disposable `bin/rails runner` reproduction (sequential duplicate `QueueEntry.create!` raised `ActiveRecord::RecordInvalid` with message "Idempotency key has already been taken," not `RecordNotUnique`) before any fix was applied.

**Correction:** Removed `uniqueness: true` from `QueueEntry`'s `idempotency_key` validation, keeping only `presence: true`. The database's unique index on `idempotency_key` (added in Phase 5B.2's migration) is now the single, self-contained source of truth for this invariant — consistent with INV-016 and the CORR-004 precedent of never letting a correctness guarantee depend on two mechanisms that can diverge under timing. `Guest::JoinService#create_new_entry`'s `rescue ActiveRecord::RecordNotUnique` branch is now the only path that can ever observe a duplicate key; its `rescue ActiveRecord::RecordInvalid` branch is now reachable only for genuine bad input (e.g. `group_size <= 0`, blank `phone_number`). The concurrency test and the full suite were both re-run and confirmed passing (including 5 repeated standalone runs of the concurrency test, to check for flakiness) before proceeding. A previously-passing model test (`queue_entry_test.rb`, "a retried join with the same idempotency_key cannot create a second QueueEntry") had asserted the old, incorrect behavior (`duplicate.valid?` false, `save!` raising `RecordInvalid`) and was updated to assert the corrected behavior (`duplicate.valid?` true at the Rails level; `save!` raises `RecordNotUnique` from the database).

**Final decision:** The corrected design — presence-only Rails validation, database unique index as sole uniqueness authority — is adopted in `app/models/queue_entry.rb`, with an explanatory comment referencing this entry so a future session isn't tempted to "restore" the seemingly-more-complete `uniqueness: true` validation.

**Resulting specification change:** No specification text change (this was a code-level defect in something already correctly specified — `api-spec.md`'s idempotency behavior was accurate throughout). Code changes only: `backend/app/models/queue_entry.rb`, `backend/app/services/guest/join_service.rb` (clarifying comment), `backend/test/models/queue_entry_test.rb` (corrected assertion).

---

### CORR-006 — `allocation-spec.md` still specified a stored, schedule-updated starvation flag, contradicting the already-finalized "derive, don't store" model

**Session:** Session 14 (Phase 5B.5.1, allocation algorithm reconciliation — analysis/specification only, no application code).

**Prompt/context:** This phase's governing prompt explicitly required comparing every proposed algorithm detail against all existing authoritative documents (`seating-allocation-policy.md`, `starvation-policy.md`, `functional-spec.md`, `api-spec.md`, `domain-model.md`, `data-model.md`) and flagging any contradictory rule found in prior AI-generated documentation, rather than silently reconciling or ignoring it.

**AI suggestion (what was already written, from an earlier phase):** `05-specifications/allocation-spec.md` §4, `update_starvation_protection()`, contained:
```
function update_starvation_protection():
    for each waiting group G:
        if G.starvation_protected_since is null
           and (now - G.joined_at) >= MAX_WAIT_THRESHOLD:
            G.starvation_protected_since = now
```
— a stored, per-row `starvation_protected_since` field, written by a function described as running "on a schedule or on every relevant read/write."

**Why it was incorrect/incomplete:** This directly contradicts two later, more authoritative, already-finalized documents: `domain-model-proposal.md` §7–8 (Phase 5B.1, finalized Session 9) explicitly reasons through and **rejects** adding a `starvation_protected_since` (or any "weight") column, concluding it's fully derivable from `joined_at` alone and that persisting it would be exactly the kind of unproven precomputed field the project's own instructions warn against; `data-model.md`'s `queue_entries` section explicitly lists "not stored: any position, rank, weight, or starvation-protection flag — all computed at read time" as a finalized constraint. `allocation-spec.md` §4 was written before (or independently of) that reconciliation and was never updated to match — including during the Phase 5B.1.5 specification-consistency pass (Session 10), whose own named audit scope (READY lifecycle, staff seat-by-code, table representation, idempotency, guest identity, table exclusivity, READY expiration) did not include this specific starvation-protection pseudocode, so the contradiction survived undetected until this phase's explicit cross-document comparison requirement surfaced it. A naive implementation of §4 as originally written would have added a schema column and (per its own "on a schedule" phrasing) risked reintroducing exactly the background-scheduler pattern DEC-015 already rejected for the structurally identical READY-expiration case.

**How the human identified the issue:** Not human-caught — self-caught via the deliberate cross-document grep/comparison this phase's own governing prompt required (§23), specifically searching for `starvation_protected_since` across `documents/` and finding it asserted as *rejected* in one finalized document and still *proposed as stored* in another, unrevised one.

**Correction:** `allocation-spec.md` §4 rewritten to `is_starvation_protected(G, now)` — a pure function, no stored field, no schedule, called inline exactly like the DEC-015 lazy READY-expiration check. `allocation-spec.md` §3's reference to `g.is_starvation_protected` (an attribute-access phrasing that read as if it might be a stored/memoized property) was also updated to the explicit function-call form `is_starvation_protected(g, now)` for consistency. The new `allocation-algorithm.md` (this session's primary deliverable) formalizes the same derive-at-read-time behavior as its own §9, and both documents now agree with `domain-model-proposal.md`/`data-model.md`.

**Final decision:** No stored starvation-protection field will exist in the schema; the check is derived from `joined_at` at evaluation time only, in both `allocation-spec.md` and `allocation-algorithm.md`. This is a genuine, real, documentation-only correction — no application code existed for this function, so nothing beyond the specification text needed to change.

**Resulting specification change:** `05-specifications/allocation-spec.md` §4 (rewritten), §3 (one function-call reference updated for consistency), plus a new top-of-document status note pointing to `allocation-algorithm.md` as the locked, formula-precise version of §2–§4. `05-specifications/allocation-algorithm.md` §9 and §23 (new document, this session) states and explains the correction. `domain-model-proposal.md` and `data-model.md` — the two documents that were already correct — were **not** modified (per this phase's own instruction: "current specification → correct it; historical record → preserve it").

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
