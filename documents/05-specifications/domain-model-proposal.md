# Domain Model Proposal (Phase 5B.1)

Status: **specification/analysis only — nothing in this document is implemented. FINALIZED as of Session 9**, ready for Phase 5B.2. No migrations, models, or seed code exist yet.

**Important governance note up front:** this proposal revises several assumptions from the Phase 3 drafts (`03-architecture/domain-model.md`, `data-model.md`). Those documents are "approved" in the sense that `CLAUDE.md` treats them as source of truth — this proposal does **not** silently overwrite them. Every place this document changes a prior assumption is called out explicitly (see §0 and inline "Revises Phase 3" notes). Recommendation: once this proposal is approved, `03-architecture/domain-model.md` and `data-model.md` should be updated to match — that update is not performed automatically here.

---

## 0. What changed from the Phase 3 draft, and why

Re-deriving the model from requirements (rather than accepting the earlier draft) surfaced a real gap: the Phase 3 `functional-spec.md` had staff "seat by code" trigger allocation *synchronously*, at the moment staff type a code. But the brief's actual guest experience — "when a group reaches the front, their phone shows a code" — describes the system deciding a group is next and showing them a code *before* staff act. Those are different designs: one needs a table reservation to exist before staff ever touch a code; the synchronous version doesn't. The reservation version is the one that actually matches the brief, and it needs a state the Phase 3 draft never had.

Concretely, this proposal:

1. **Adds a `ready` state to `QueueEntry`** (the earlier draft only had `waiting`/`seated`/`left`/`no_show`) — the allocation service assigns a specific table configuration to a specific group *before* staff act, showing that group's phone a code; staff's "seat by code" action confirms an already-reserved assignment, it doesn't perform allocation itself. This changes `INV-011`'s terminal-state list (adds `ready` as a non-terminal state) and changes the "seat by code" behavior described in `05-specifications/functional-spec.md` §6.
2. **Replaces `TableCombination` with `SeatingAssignment` + a small join table.** `SeatingAssignment` covers both single-table and combined seating uniformly (1 or 2 member tables), and represents the reservation *before* it's confirmed occupied, not just the confirmed state. This is a generalization, not a rename with the same meaning.
3. **Drops the separate `IdempotencyRecord` entity.** A unique column directly on `QueueEntry` fully satisfies the requirement with one fewer table and no join.
4. **Drops the separate `GuestIdentity`/`ActiveVisitToken` entity.** The brief's own description ("associated with the active queue entry") is inherently one-token-per-entry, not a guest-spanning identity — modeling it as its own entity would imply more persistence than "no account, nothing kept between visits" calls for.
5. **Drops `NotificationJob` from this phase entirely.** Notifications are explicitly deferred (Redis/Sidekiq, P1) — modeling their persistence now would violate "do not invent requirements that are not necessary."
6. **Corrected after human review (see `06-ai-working-record/ai-corrections.md` CORR-004): `SeatingAssignmentTable` no longer carries a denormalized `status` column.** The original proposal's partial unique index relied on that column being kept in sync with its parent `SeatingAssignment.status` purely by application convention — real, but not database-enforced, and PostgreSQL partial-index predicates can't reference another table's column to check that convention directly.
7. **Finalized design (supersedes the first-pass fix above, after a second round of review): `SeatingAssignmentTable` has a `released_at` timestamp — nullable, on the row itself, not copied from the parent.** `UNIQUE (table_id) WHERE released_at IS NULL` is a fully valid PostgreSQL partial index (the predicate references only a column of the table being indexed) and needs no application-level sync promise at all: it's self-contained. This also fixes a real gap in the interim CORR-004 fix (which deleted rows on release, losing history) — rows now persist forever with `released_at` populated on release/expiration, so historical assignments remain queryable. See §2, §4, §5, §6, §11 for the finalized design throughout.
8. **Added the READY-reservation expiration policy** (DEC-015): a `ready` reservation that isn't confirmed within 5 minutes auto-transitions to `no_show`, releasing its table(s). Evaluated lazily (no background job) — see §6/§16.

Net effect: **6 entities** (4 substantive + 2 join/associative), down from Phase 3's 7 — thinner and, per §0.1–0.2, more correct against the actual required guest experience. **This document is finalized** as of this revision (Session 9) — see §17.

---

## 1. Selected Domain Model — summary

A guest joins and gets a `QueueEntry` (state `waiting`). The allocation service (built in a later phase, not this one) watches for tables becoming free and, per the approved policy (`02-product-decisions/seating-allocation-policy.md`), picks the best-eligible waiting entry for each newly-available configuration. When it picks one, it creates a `SeatingAssignment` (status `pending`) referencing 1 or 2 `Table`s via `SeatingAssignmentTable` rows, generates a `seating_code`, and moves the entry to `ready`. Staff enter that code to confirm: the assignment becomes `active`, the entry becomes `seated`. When the group leaves, staff release: the assignment becomes `released`, its table(s) become free again (derived, not stored). A table's occupancy is never stored directly on `Table` — it's always derived from whether a non-released `SeatingAssignmentTable` row references it, which is also the row that carries the database-level "one active assignment per table" guarantee.

---

## 2. Entity list

| Entity | Kind | Purpose |
|---|---|---|
| `StaffUser` | substantive | Authenticated staff actor (stub auth) |
| `Table` | substantive | A physical table: id, capacity; no stored occupancy |
| `TableAdjacency` | associative (seed data) | Which tables can combine with which |
| `QueueEntry` | substantive | One group's waitlist record and state machine |
| `SeatingAssignment` | substantive | A reservation/occupancy record for 1–2 tables, tied to one `QueueEntry` |
| `SeatingAssignmentTable` | associative | Which table(s) a `SeatingAssignment` covers; carries the DB-level exclusivity constraint |

### `StaffUser`
- **Fields:** `id`, `email` (unique), `password_hash`.
- **Constraints:** unique `email`.

### `Table`
- **Fields:** `id`, `capacity` (integer, `> 0`).
- **No status field** — see §14 "Combination representation" for why occupancy is derived, not stored.

### `TableAdjacency`
- **Fields:** `table_id`, `adjacent_table_id`.
- **Constraints:** unique `(table_id, adjacent_table_id)`; seed data, immutable at runtime (no product requirement changes adjacency after seeding).

### `QueueEntry`
- **Fields:** `id`, `group_size` (integer, `> 0`), `phone_number` (string; never used for auth or idempotency — see §10), `status` (`waiting` / `ready` / `seated` / `left` / `no_show`), `active_visit_token` (opaque string, unique, set at creation), `idempotency_key` (string, unique, set at creation), `seating_code` (nullable string, set only on entering `ready`), `joined_at`, `ready_at` (nullable), `seated_at` (nullable), `left_at` (nullable), `no_show_at` (nullable).
- **Constraints:** unique `active_visit_token`; unique `idempotency_key`; unique `seating_code` where not null (see §12 index); `group_size > 0`; `status` restricted to the five valid values.
- **Not stored:** any "position," "weight," or "priority" value — see §7/§8. Also not stored: a separate flag distinguishing staff-initiated no-show from expiration-initiated no-show — both set the same `status`/`no_show_at`; per DEC-015's documented trade-off, distinguishing the two is explicitly deferred to a future version.

### `SeatingAssignment`
- **Fields:** `id`, `queue_entry_id` (FK, one assignment per entry at a time), `status` (`pending` / `active` / `released`), `created_at`, `activated_at` (nullable), `released_at` (nullable).
- **Constraints:** at most one non-`released` `SeatingAssignment` per `queue_entry_id` (partial unique index — valid, `status` is this table's own column).

### `SeatingAssignmentTable`
- **Fields:** `id`, `seating_assignment_id` (FK), `table_id` (FK), `released_at` (nullable timestamp). **No `status` column — finalized design, see §0 item 7.**
- **Lifecycle:** a row is **created** (1 or 2 rows, in the same transaction as the parent `SeatingAssignment`) when the assignment is formed (`pending`) — `released_at` starts `NULL`. The row's existence with `released_at IS NULL` means "this table is currently claimed," whether the parent assignment is `pending` (held/ready) or `active` (occupied) — that distinction doesn't need to live on this row, since neither state makes the table available to anyone else; it's answerable by joining to the parent's `status` when needed (e.g., a richer staff table view). Activating an assignment (`pending → active`, staff seat the group) touches **only** the parent row — the claim row(s) are untouched. Releasing (group leaves, *or* the READY-expiration path, DEC-015) sets `released_at = now()` on the row(s) **in the same transaction** as the parent's `status → released` — the row is never deleted, so historical assignments remain queryable.
- **Constraints:** `UNIQUE (table_id) WHERE released_at IS NULL` — **this is the database-level enforcement of "one group per table" (INV-001/002/003)**, and the predicate references only this table's own column, so it needs no application-level promise to stay correct (unlike the original, incorrect design — see §0 item 6). Combined with inserting both rows of a 2-table assignment in one transaction, this gives atomic combined allocation almost entirely from the constraint system (see §11).
- **If a query needs to distinguish "held (pending)" from "occupied (active)" per table** (e.g., a richer staff table view), that's a `JOIN` to `seating_assignments.status` at read time — cheap, and doesn't reintroduce the write-path sync risk this correction removes, since nothing about it affects what makes a row exist or not.
- **Application-level (not DB-enforced) constraint:** at most 2 `SeatingAssignmentTable` rows per `seating_assignment_id` (DEC-002). A hard DB-level cap would need a trigger; the allocation service is the sole writer of these rows and enforces it directly — judged not worth the added migration complexity for a fixed, unchanging business rule. Noted as an accepted trade-off, not an oversight.

---

## 3. Relationships

```
StaffUser                                    (no FK relationships to the queue/table domain —
                                               stub auth only, scopes staff actions, not modeled further)

Table            1 ── * TableAdjacency ── * Table        (symmetric, seed data)
Table            1 ── 0..* SeatingAssignmentTable          (a table appears in many assignments over time,
                                                             all rows retained for history; at most one
                                                             with released_at IS NULL (currently claimed) —
                                                             enforced, not just implied)
SeatingAssignment 1 ── 1..2 SeatingAssignmentTable
QueueEntry        1 ── 0..1 SeatingAssignment (current)     (historically many over separate visits, but this
                                                             phase only ever creates one per entry — an entry
                                                             represents one visit, and a new visit is a new
                                                             QueueEntry, not a new assignment on the same one)
```

`QueueEntry` never references `Table` directly — the relationship is always through `SeatingAssignment` → `SeatingAssignmentTable` → `Table`, so "which table(s) does this group have" and "is this table free" both resolve through the same join, with no risk of two different code paths disagreeing (a real risk if `Table` also carried its own redundant occupancy field).

---

## 4. Constraints (database-level invariants)

| Constraint | Protects | Mechanism |
|---|---|---|
| `queue_entries.group_size > 0` | Sane input | CHECK |
| `tables.capacity > 0` | Sane seed data | CHECK |
| `queue_entries.idempotency_key` unique | INV-007 — retried join never duplicates | Unique index |
| `queue_entries.active_visit_token` unique | Guest can only ever resolve to exactly one entry | Unique index |
| `queue_entries.seating_code` unique where not null | Staff can't accidentally seat the wrong group via a colliding code | Partial unique index |
| `queue_entries.status` restricted to 5 values | Prevents an invalid/typo status from ever being persisted | CHECK (see §14 note on enums vs. CHECK) |
| `seating_assignments.queue_entry_id` unique where `status != released` | INV-009 — a group can't hold two simultaneous reservations/seatings | Partial unique index (valid — `status` is a column of the same table being indexed, no cross-table reference) |
| `seating_assignment_tables.table_id` unique `WHERE released_at IS NULL` | INV-001/002/003 — a table is never claimed by two groups at once, in either combined-pair slot | Partial unique index, **finalized design** (§0 items 6–7): the original version predicated on a `status IN (pending, active)` column denormalized from the parent `SeatingAssignment` — PostgreSQL partial-index predicates cannot reference another table's column, so that copy's correctness depended entirely on application discipline, not the database. `released_at` is this table's own column, so the predicate is valid and self-contained; a released/expired claim (`released_at` set) simply doesn't count toward the constraint, while the row itself is retained for history. |
| `seating_assignments.queue_entry_id` and `seating_assignment_tables.table_id`/`released_at` also support READY-expiration sweeps (DEC-015) | "Find `ready` entries whose reservation is overdue" (`queue_entries.status = 'ready' AND ready_at < now() - 5min`), evaluated lazily wherever the existing `(status, joined_at)` index is already scanned | No new index needed — the expiration check rides on `(status, joined_at)` already listed below, since `ready_at` and `joined_at` ordering coincide closely enough for this purpose, and the check only ever runs against entries already being read for another reason |

**Deliberately not added:** a CHECK capping `group_size` at some maximum (the real ceiling is "largest seatable configuration in the current seed data," which is data-dependent, not a fixed constant — enforced by the application per DEC-011, not the schema). A CHECK enforcing `table_one`/`table_two` adjacency (would need a trigger referencing `TableAdjacency`; the allocation service is the only writer and already must query adjacency to pick a valid configuration — adding a trigger duplicates that logic in SQL for no additional protection against a bug class that doesn't otherwise exist here). A denormalized `status` column on `seating_assignment_tables` — deliberately removed by the correction above, not merely never added. A separate background-job table/queue for expiration sweeps — explicitly rejected by DEC-015 in favor of lazy evaluation.

---

## 5. Indexes

| Index | Query it supports | Why it matters |
|---|---|---|
| Unique on `queue_entries.active_visit_token` | Guest polling: "find my active entry by token" | Also *is* the identity-scoping mechanism (§9) |
| Unique on `queue_entries.idempotency_key` | Join retry resolution | Also *is* the idempotency mechanism (§10) |
| Partial unique on `queue_entries.seating_code` (`WHERE seating_code IS NOT NULL`) | Staff "seat by code" lookup | Also *is* the no-collision guarantee between simultaneously-ready groups |
| `(status, joined_at)` on `queue_entries` | "Find active queue entries" (`status IN (waiting, ready)`), ordered oldest-first for wait-time aging | Both the staff queue view and the allocation service's eligibility query filter+sort on exactly this |
| Partial unique on `seating_assignment_tables.table_id` `WHERE released_at IS NULL` (finalized design, §0 items 6–7) | "Find available tables" (anti-join: tables with no non-released row here) | Constraint and index are the same object here by design (§2) |
| Partial unique on `seating_assignments.queue_entry_id` (`WHERE status != released`) | "Find guest's active seating assignment" | Also the one-assignment-per-group constraint |
| Unique on `(table_adjacency.table_id, adjacent_table_id)` | "Find adjacent tables of X" | Small table (~40 rows), performance is a non-issue; kept for correctness (no duplicate/contradictory seed rows), not speed |

**Deliberately not added:** an index on `tables.capacity` ("find tables by capacity"). At ~40 rows total, a full scan costs nothing measurable; adding an index here would be optimizing before there's any evidence it's needed, which §12 of the governing prompt explicitly warns against.

---

## 6. State machines

### `QueueEntry`

```
                 ┌─────────────────────────────────────────┐
                 │                                          │
   [join] ──▶ waiting ──▶ ready ──▶ seated  (terminal)      │
                 │           │  ▲                           │
                 │           │  └── (5-min timeout, no      │
                 │           │       staff confirmation —   │
                 │           │       DEC-015, lazy-evaluated)│
                 │           ▼                              │
                 │           └──▶ left     (terminal)       │
                 │           │                              │
                 │           └──▶ no_show  (terminal) ◀──────┘ (expiration also lands here)
                 │                                          │
                 └──▶ left     (terminal)                   │
                 │                                          │
                 └──▶ no_show  (terminal)                   │
```

**Valid transitions:**
- `waiting → ready` — system (allocation service selects this entry for a newly-available configuration; a `pending` `SeatingAssignment` is created, `seating_code` generated, `ready_at` set).
- `waiting → left` — guest leaves voluntarily before ever being called.
- `waiting → no_show` — staff mark no-show for a group that vanished before being called (rare but not impossible — e.g., staff clean up a stale entry).
- `ready → seated` — staff enter the correct `seating_code`; the entry's `SeatingAssignment` moves `pending → active` in the same transaction.
- `ready → left` — guest leaves after being called but before staff processed their code; the reserved `SeatingAssignment` is released (`pending → released`, `SeatingAssignmentTable.released_at` set) so its table(s) become free immediately.
- `ready → no_show`, **two triggers, same transition:** (a) staff mark no-show for a group that was called but never came up, or (b) **automatic, per DEC-015** — the entry has been `ready` for more than the configured timeout (5 minutes, illustrative/tunable) and nothing has confirmed it. Both release the reservation identically (`SeatingAssignment.status → released`, `SeatingAssignmentTable.released_at` set, same transaction). (b) is evaluated **lazily** — inline, as a side effect of any operation that already touches this entry or the tables it holds (guest position read, staff queue/table view, guest join, allocation/availability calculation, seating operations) — never by a background job or scheduler.

**Explicitly invalid (not modeled in this MVP):**
- `ready → waiting` ("un-ready" / demote back into the queue, including on expiration). Considered specifically for the expiration case and rejected for the MVP in favor of auto-`no_show` (DEC-015) — the documented cost is that a guest can lose their place even if the delay was staff's fault, not theirs; a future version could distinguish the two and re-queue with the original wait time preserved.
- Any transition out of `seated`, `left`, or `no_show` — all three are terminal (INV-011, extended here to explicitly exclude `ready` from the terminal set — **this changes INV-011's wording**, see §0).
- `waiting → seated` directly. Seating always requires having been `ready` first — a `waiting` entry has no reserved table(s) and no code yet, so there is nothing for staff to confirm.

### `Table` / `SeatingAssignment`

A table's occupancy is **derived**, not stored (see §2, §14). There are three derived states, not four — and, per the finalized design (§0 items 6–7), the middle two are distinguished by looking at the **parent** `SeatingAssignment.status` via a join, while "claimed at all" is answered entirely within the table's own claim row (`released_at IS NULL`):

```
Table's derived state = f(does a SeatingAssignmentTable row with released_at IS NULL reference this table?)
                       + (if yes) f(that row's parent SeatingAssignment.status)

  free  ──(row created, released_at=NULL,   ▶  held  ──(parent status: pending→active,
   ▲        parent status=pending)──┐        │          NO change to the row itself)──▶ occupied
   │                                 │        │                                             │
   │                                 │        │ (parent released while still pending —      │
   │                                 │        │  guest left, staff no-show, OR expiration    │
   │                                 │        │  per DEC-015 — released_at = now() is set    │
   │                                 │        │  on the row; the row itself is KEPT)         │
   │                                 └────────┘                                              │
   ▲                                                                                          │
   └────(parent released — group physically left: released_at = now() set, row KEPT)──────────┘
```

Note what does *not* happen at the `held → occupied` step: staff seating the group (`SeatingAssignment` `pending → active`) touches only the parent row — the `SeatingAssignmentTable` row(s) are untouched, because "claimed" is all they ever needed to express. `held` vs. `occupied` is a read-time distinction (join to the parent), not a write-time one. And note what does *not* happen at release/expiration either: the row is **never deleted** — only `released_at` is set — so a table's or an entry's full seating history remains queryable after the fact, unlike the interim CORR-004 fix.

"Combined" is **not** a fourth table state — it's a property of the `SeatingAssignment` (whether it has one or two `SeatingAssignmentTable` rows), not of any individual table. From a single table's point of view, being part of a combined assignment looks identical to being part of a single-table one: `free`/`held`/`occupied`, derived the same way. When a combined assignment is released (including via READY-expiration, DEC-015), **both** member rows get `released_at` set in the same transaction, so both tables return to `free` simultaneously — this is the mechanism behind "combined tables become independently available again after the group leaves" (INV-006), not a separate "split" operation.

---

## 7. Position — what's persisted vs. computed

**Nothing that resembles a position or rank is stored.** Per DEC-005, position is a dynamic function of current state, recomputed on read. What must be persisted so a later service *can* compute it:

- `queue_entries.group_size` — determines which configurations a group is compatible with (Stage 1, `seating-allocation-policy.md`).
- `queue_entries.status` — only `waiting`/`ready` entries count toward anyone's position.
- `queue_entries.joined_at` — the wait-time aging signal (Stage 4).
- Current table availability — derived from `seating_assignment_tables`, as above (Stage 2).
- `table_adjacency` — which configurations exist at all (Stage 1–2).
- Starvation-protection status — see §8 below for whether this needs its own stored field.

No "position" column exists to go stale, and no derived value needs to be kept in sync with writes elsewhere — it's computed fresh from these facts every time it's read.

---

## 8. Starvation / fairness — what's persisted vs. derived

The approved policy (DEC-004) needs, at minimum, each waiting/ready group's wait duration compared against a threshold. That's fully derivable from `joined_at` alone (`now() - joined_at >= MAX_WAIT_THRESHOLD`) — **no `starvation_protected_since` or "weight" column is proposed**, for the reason the governing prompt asks to prove: persisting it would only matter if the threshold constant itself could change *while a group is mid-wait* and we needed to freeze their protection status against that future change. No requirement asks for that, and adding it now would be exactly the kind of unproven precomputed field this phase's own instructions warn against. If threshold-change-safety becomes a real product requirement later, `ready_at`... no — a `starvation_protected_since` timestamp would be the one column worth adding at that point, not before.

This is a direct, deliberate simplification versus the Phase 3 draft, which left this ambiguous ("may be evaluated on a schedule or on every read/write") — this proposal resolves it: **derive on read, always, from `joined_at`.**

---

## 9. Guest identity

**Persisted:** `queue_entries.active_visit_token` — an opaque, unguessable random string generated at join time, unique per entry.

**Stored in the browser:** the token itself (e.g., `localStorage` — exact transport is an implementation-phase detail, not decided here, consistent with the existing open item in `02-product-decisions/decision-log.md`).

**Scoping:** the token identifies exactly one `QueueEntry` — nothing else. There is no broader "guest" record it belongs to; a browser holding a token can view/act on that one entry and nothing else (NFR-SEC-002).

**When it becomes invalid (in effect, not by deletion):** once the entry reaches a terminal state (`seated`/`left`/`no_show`), the token still technically resolves to that row, but the entry no longer behaves as an active session — the API returns the terminal outcome, not a live position (per DEC-006, unchanged by this proposal).

**A future visit:** scanning the QR code again always starts a fresh join, which always creates a brand-new `QueueEntry` with a brand-new `active_visit_token` and a brand-new `idempotency_key` — there is no code path that reuses an old token for a new visit, because there is no entity representing "the guest" independent of a specific entry (§0.4).

This directly matches the governing prompt's own preferred direction ("opaque random guest token... associated with the active queue entry") and corresponds to its own "Option C: queue-entry token" in §14's comparison, arrived at independently here before checking that list.

---

## 10. Idempotency

**Mechanism:** `queue_entries.idempotency_key`, a client-generated UUID, with a **database-level unique index** — the actual enforcement point, not an application-level check-then-insert (which would reopen the exact race the constraint exists to close).

**What makes it unique:** the *client* generates a fresh UUID for each distinct join *attempt* — not per guest, not per phone number, not per browser session. A retry of a failed/uncertain request reuses the same key; a genuinely new join (even from the same phone number, even in the same browser) generates a new one.

**Lifecycle:** written once, at row creation, alongside the row it protects — never updated, never reused across rows.

**If the same key is retried:** the second `INSERT` violates the unique constraint; the application catches that specific failure and returns the *existing* row's state instead of creating a new one or surfacing a generic error (already specified in `04-diagrams/06-guest-join-idempotency.md`, unchanged here).

**A new visit:** generates a new key, exactly as it generates a new `active_visit_token` — the two are conceptually independent (one is identity, one is retry-safety) but share the same lifecycle for the same reason (§0.4).

**Why not `IdempotencyRecord` as a separate table (Phase 3 draft):** the only thing that needs protecting is "does a row for this key already exist" — a column with a unique index on `queue_entries` itself answers that in one query, with one fewer join and one fewer table to keep in sync. A separate table would only be justified if idempotency keys needed to be tracked independently of whether they ever produced a successful row (e.g., logging rejected attempts) — not a stated requirement.

---

## 11. Concurrency plan

None of this is implemented in this phase — this is what the later allocation/seating service must do to uphold the invariants above.

| Scenario | What protects it |
|---|---|
| **Two guests join concurrently** | No shared row is touched — each `INSERT` is independent. No locking needed. |
| **Two seating operations concurrently** (e.g., a double-submitted "seat by code") | `SELECT ... FOR UPDATE` on the target `QueueEntry` row before checking `status == ready` and transitioning; the second transaction blocks, then sees the already-`seated` status and no-ops/rejects cleanly. |
| **Two adjacent tables targeted by different groups** (combined-allocation race) | Primary: lock both candidate `Table` rows, in a consistent order (e.g., by id) to avoid deadlocks, before creating the `SeatingAssignment`. Secondary/defense-in-depth: the partial unique index on `seating_assignment_tables.table_id WHERE released_at IS NULL` (finalized design, §0 items 6–7) — inserting both member rows in a single transaction means if either table was already claimed (a non-released row for it already exists), the whole `INSERT` (and thus the whole assignment) fails and rolls back together, which is what actually delivers "both tables or neither" (INV-005) even if the locking discipline above is ever imperfect. The predicate references only this table's own column, so this guarantee doesn't depend on any cross-table sync. |
| **A table is released while another seating operation starts** | Release (setting `released_at = now()` on the relevant `seating_assignment_tables` rows, in the same transaction as the parent's `status → released` — never deleting, §0 item 7) and a new allocation attempt (inserting new rows for the same table) both go through the same row-locking discipline on the `Table` row; PostgreSQL's MVCC + explicit locks serialize the two so there's no window where both sides believe the table is simultaneously free and taken. |
| **A retry of the same join arrives concurrently** (not sequentially) | The unique index on `idempotency_key` is itself the serialization point — two simultaneous `INSERT`s with the same key: one commits, one gets a unique-violation the application maps to "return the existing row." No explicit row lock is needed beyond what the unique index already provides. |
| **Two concurrent operations both notice the same overdue `ready` reservation** (lazy-expiration race, DEC-015) | `SELECT ... FOR UPDATE` on the target `QueueEntry` row before checking `ready_at` against the timeout and transitioning to `no_show` — same lock, same pattern as the "two seating operations" row above. Whichever transaction acquires the lock first performs the expiration (`status → no_show`, `SeatingAssignment.status → released`, `SeatingAssignmentTable.released_at` set); the second sees the entry already `no_show` and no-ops. No separate mechanism is needed beyond what §11's other rows already establish. |

**Isolation level:** PostgreSQL's default `READ COMMITTED` is sufficient throughout, provided the explicit `SELECT ... FOR UPDATE` locks above are actually taken at the right points — this doesn't require `SERIALIZABLE` or optimistic (version-column) concurrency control anywhere in this model.

---

## 12. Seed data plan

Seed structure only — **no seed code is written in this phase.**

40 tables, matching the approved DEC-001 distribution: 20 two-seat, 18 four-seat, 2 six-seat.

**Deterministic adjacency, deliberately chosen to align with the allocation algorithm's needs (not arbitrary):**

- **Two-seat tables (T1–T20):** paired sequentially — (T1,T2), (T3,T4), … (T19,T20) — 10 adjacent pairs, each combining to 4-seat capacity. (Redundant with a standalone 4-seat table for a party of 4, but still a valid, useful configuration for exercising "smallest suitable configuration" logic under load, and for testing that the allocator doesn't wastefully prefer a combo over a single table when a single table is available.)
- **Four-seat tables (T21–T38):** paired sequentially — (T21,T22), (T23,T24), … (T37,T38) — 9 adjacent pairs, each combining to 8-seat capacity. This is the seed data's primary support for groups of 5–8, and directly determines how often the starvation-protection scenario in `starvation-policy.md` can actually arise (a limited, deliberately scarce set of 8-capacity configurations).
- **Six-seat tables (T39, T40):** **not** adjacent to anything. They already cover parties up to 6 on their own; making them adjacent to each other (→ 12-seat combo) or to a 2/4-seat table would add configurations no stated requirement or realistic group size calls for — a deliberate scope decision, not an oversight.

Total: 19 adjacency pairs, fully deterministic and listable as a static seed table (no randomness, no generated layout) — satisfies "deterministic seed data" directly.

---

## 13. Model alternatives considered

### Seating representation
- **Option A — table directly references the queue group** (a `current_queue_entry_id` FK on `Table`). Rejected: cannot represent the `ready`/reserved-but-not-yet-occupied phase without overloading what the FK means, and cannot cleanly represent a 2-table combined assignment as one thing (would need two tables to agree on the same `queue_entry_id`, with no natural place to enforce atomicity between them).
- **Option B — separate seating assignment entity.** **Selected.** Cleanly represents `pending`/`active`/`released` independent of any one table's row, and generalizes 1-table and 2-table seating uniformly.
- **Option C — event-sourced seating log** (append-only events, current state derived from event history). Rejected as unnecessary complexity for a two-day scope — no requirement needs historical seating event replay; a mutable `status` field on a small number of tables is sufficient and far simpler to implement and test.

### Combination representation
- **Option A — table-pair relationship** (two nullable FK columns, `table_one_id`/`table_two_id`, directly on `SeatingAssignment`). Considered seriously — simpler to work with in Rails, one fewer table. **Rejected** specifically because a clean, single database constraint enforcing "this table is claimed by at most one active assignment, regardless of which slot it occupies" is not expressible as two independent partial-unique indexes on two different columns (a table could occupy `table_one_id` in one assignment and `table_two_id` in another simultaneously, and neither index alone would catch it).
- **Option B — seating unit / assignment representation** (a join table, `SeatingAssignmentTable`, one `table_id` column). **Selected**, specifically because it allows exactly one unique index on one column to correctly enforce table exclusivity regardless of which "slot" a table fills — chosen for **correctness**, not flexibility (per this phase's own stated preference: correctness over theoretical flexibility, in that order, when the two are in tension with simplicity). The *specific shape* of B went through two revisions after review, both recorded honestly rather than silently fixed: the first draft carried its own `status` column on the join row (a partial index predicated on it, which can't validly reference the parent's status — CORR-004); an interim fix removed the column entirely and deleted rows on release (simpler, but lost history); the **finalized** shape keeps a `released_at` timestamp on the row itself (never deleted) with `UNIQUE (table_id) WHERE released_at IS NULL` — valid, self-contained, and preserves historical assignments. The *decision between A/B/C* was right from the start; only B's internal shape needed the two rounds of correction.
- **Option C — array column on `Table`** (e.g., `combined_with: [table_ids]`, denormalized both directions). Rejected: requires keeping two rows' array columns manually in sync on every combine/release, exactly the dual-source-of-truth bug class this proposal otherwise avoids.

### Guest identity
- **Option A — phone number.** Rejected outright, per explicit instruction (DEC-007 and this phase's §2) — not unique per request, not authentication-grade, and reused across visits in a way that would violate "nothing kept between visits."
- **Option B — opaque guest token** (a persistent identity entity, `GuestIdentity`, that could span multiple future visits/entries). Considered — this is closer to what a real returning-customer system would eventually need. **Rejected for this MVP** — a `GuestIdentity` outliving a single visit implies persisting *something* across visits, in tension with "no account, nothing kept between visits."
- **Option C — queue-entry-scoped token.** **Selected** — a token whose entire lifecycle is exactly one `QueueEntry`'s lifecycle, as `queue_entries.active_visit_token`. Matches the governing prompt's own preferred description exactly (§9).

---

## 14. Deferred scope (not modeled in this phase)

| Deferred | Why |
|---|---|
| Redis cache | P1; adds an authority-boundary risk (DEC-013) not worth taking on before P0 correctness is proven with a plain PostgreSQL read path. |
| Sidekiq / background jobs | P1; the "table ready" notification is explicitly meant to be built once the synchronous flow (this model) is proven correct first. |
| Notification provider | No requirement asks for real delivery — only the async *pattern*, which needs no persisted domain model of its own beyond what P1 will add later. |
| Rate limiting | Explicitly optional hardening in the brief, not a correctness requirement this model needs to support. |
| Detailed staff authentication | Brief explicitly says "a stub is fine" — `StaffUser` here is intentionally minimal. |
| Table-management UI / persistence for editing layout | Brief explicitly states table layout is seed data with no management screen. |
| Arbitrary N-table combinations | DEC-002 caps at 2; no stated requirement or realistic group size in the brief needs more (see §12's six-seat-table reasoning). |
| Table-sharing preferences | Explicitly future scope (DEC-009); directly conflicts with the current one-group-per-table invariant this model enforces at the database level. |
| Advanced staff overrides (manual reorder, forced un-seat, "un-ready") | Brief flags real-world messiness as ours to choose; deferred per `02-product-decisions/scope-and-tradeoffs.md`, and per §6's explicit note that `ready → waiting` is not modeled. |
| Analytics / reporting | No requirement asks for it; the timestamp fields kept (`joined_at`, `ready_at`, `seated_at`, `left_at`, `no_show_at`) are ordinary audit fields needed for state-transition testing itself, not an analytics feature. |

---

## 15. Requirement traceability

| Requirement | Domain concept | DB field / constraint | Later service responsible |
|---|---|---|---|
| REQ-GUEST-007 / REQ-IMP-003 — idempotent join | `QueueEntry.idempotency_key` | Unique index (§10) | Guest join service |
| REQ-GUEST-004 / DEC-006 — anonymous guest recovery | `QueueEntry.active_visit_token` | Unique index (§9) | Guest position/recovery service |
| INV-001/002/003 — one group per table | `SeatingAssignmentTable.table_id` | Partial unique index (§4) | Allocation/seating service |
| REQ-TABLE-006 / INV-005 — atomic two-table seating | `SeatingAssignment` + `SeatingAssignmentTable` (2 rows, 1 transaction) | Partial unique index + transactional insert (§11) | Allocation/seating service |
| REQ-STAFF-005 / DEC-014 / INV-006 / INV-015 — table release | `SeatingAssignment.status → released`, cascaded to `SeatingAssignmentTable` rows | Application transaction (both rows together) | Release service (keyed by `queue_entry_id`, not raw `table_id`) |
| REQ-QUEUE-001/002 — non-FIFO position | `QueueEntry.group_size`, `status`, `joined_at`; `SeatingAssignmentTable` (availability); `TableAdjacency` | No stored position — computed (§7) | Position/allocation service |
| REQ-QUEUE-003 / DEC-004 — starvation protection | `QueueEntry.joined_at` | No stored protection flag — derived (§8) | Allocation service |
| REQ-STAFF-006 — no-show | `QueueEntry.status → no_show`, `no_show_at` | CHECK on `status` (§4) | Staff no-show action |
| REQ-GUEST-003 — guest leave | `QueueEntry.status → left`, `left_at` | CHECK on `status` (§4) | Guest leave action |
| DEC-015 — READY reservation expiration | `QueueEntry.ready_at`, `status → no_show`; `SeatingAssignmentTable.released_at` | `(status, joined_at)` index (reused, §5); `released_at` partial unique index (§4) | Lazy expiration check, embedded in position/allocation/staff-view reads (no scheduler) |

---

## 16. Open decisions (genuinely requiring human/product judgment)

1. **OPEN-005 (already tracked, still open) — exact `seating_code` format/strength.** This proposal only commits to "a unique string column, populated on entering `ready`." Length/character set/generation algorithm is unresolved.
2. ~~Does the `ready` state need its own abandonment timeout?~~ **Resolved — DEC-015** (5-minute lazy-evaluated timeout, auto-`no_show`). `OPEN-007` remains partially open for the `waiting`-state case only (see `decision-log.md`).
3. ~~Recommend formally updating `03-architecture/domain-model.md` and `data-model.md`~~ **Done this session** — both now reflect this proposal's finalized entities/invariants (see the updated versions of those two documents; this proposal was the source, they are now the authoritative copies going forward).

No further open decisions block Phase 5B.2 implementation, beyond `OPEN-002` (live-update mechanism), `OPEN-005` (seating-code format), and the `waiting`-state portion of `OPEN-007` — none of which block starting domain/persistence implementation itself.

---

## 17. Phase status

> Phase 5B.1 specification is finalized and ready for implementation.
> No application/domain code was implemented in this phase.
> Waiting for authorization to begin Phase 5B.2.
