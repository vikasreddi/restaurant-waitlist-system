# Functional Specification

Status: specification only, not implementation. Consolidates `01-requirements/` and `02-product-decisions/` into implementation-ready behavior. Where a decision remains open, it is marked `OPEN` here too — this document does not resolve open decisions on its own authority.

## 1. Guest join

**Preconditions:** none (public endpoint).

**Inputs:** group size (positive integer), phone number, client-generated idempotency key.

**Behavior:**
1. Validate group size and phone number format. Invalid input → validation error, no entry created.
2. Check group size against the largest seatable configuration (a single largest table, or the best two-table adjacent combination under DEC-002). If no configuration — single or combined — can ever seat this group size, **reject the join with a clear validation error** directing the group to speak to staff directly; no entry is created (DEC-011, resolving the former OPEN-006). This keeps every `waiting` entry guaranteed-seatable by construction.
3. Check `idempotency_key` — a unique column directly on `QueueEntry` (not a separate table, `03-architecture/data-model.md`). The key is a client-generated UUID, reused verbatim on retry of the same attempt; a genuinely new join attempt uses a new key (`04-diagrams/06-guest-join-idempotency.md`).
   - Key not seen: create `QueueEntry` (status `waiting`), record the idempotency key, return position + active-visit token.
   - Key already seen: return the existing entry's current position + token, do not create a new entry (REQ-GUEST-007, INV-007).
4. Response includes: queue entry id (or opaque reference via token), computed position, active-visit token.

## 2. Guest view position / recover visit

**Preconditions:** caller presents an active-visit token.

**Behavior:**
- Token maps to a `waiting` entry → return current computed position and status.
- Token maps to a `ready` entry → return status `ready` and the `seating_code` (no numeric position — the group has already been allocated a configuration and is waiting on staff confirmation, not on other groups).
- Token maps to a terminal entry (`seated`/`left`/`no_show`) → do not resume it as an active session (DEC-006); response reflects the terminal outcome, not a live position. A `no_show` reached via DEC-015's lazy expiration reads identically to a staff-initiated one — the response does not distinguish the trigger.
- Token unknown/invalid → guest is treated as not having an active visit (landing/join state), not an error that implies something is broken.
- **This read is itself one of DEC-015's lazy-expiration checkpoints:** if the token resolves to a `ready` entry whose reservation is overdue, the expiration (→ `no_show`, release) is applied first, in the same transaction, before the response is built — the guest sees the up-to-date outcome, never a stale `ready` past its timeout.

## 3. Guest leave

**Preconditions:** caller's token maps to a non-terminal entry.

**Behavior:** transition entry to `left`. Idempotent: leaving an already-`left` (or otherwise terminal) entry is a safe no-op, not an error that confuses the guest.

## 4. Staff login

**Preconditions:** none (public login endpoint).

**Behavior:** stub-strength credential check (REQ-STAFF-001) issues a staff session. Invalid credentials → generic authentication error (no user enumeration).

## 5. Staff view queue / tables

**Preconditions:** authenticated staff session.

**Behavior:** returns current queue entries (`waiting` entries with computed position; `ready` entries flagged distinctly, since they have no numeric position — they're waiting on staff confirmation, not on other groups) and current table states (derived — `free`/`held`/`occupied` per `03-architecture/domain-model.md` §2, not a stored field). This read is also a DEC-015 lazy-expiration checkpoint, same as §2. No caching requirement for the staff view in P0 (only the guest read path is a caching candidate, REQ-SHOW-002).

## 6. Allocation (system, not staff — precedes §6a)

**Trigger:** any event that changes table availability or the waiting set — join, release, no-show (staff or DEC-015 expiration), leave. Not invoked by staff directly.

**Behavior:** per `allocation-spec.md` / `seating-allocation-policy.md` / `allocation-algorithm.md` (Phase 5B.5.1 — the locked, formula-precise version of this selection step), the allocation service selects the best-eligible `waiting` entry for each newly-available configuration and, atomically:
1. Creates a `pending` `SeatingAssignment` and its 1–2 `SeatingAssignmentTable` claim rows.
2. Generates a `seating_code`.
3. Transitions the entry `waiting → ready`, sets `ready_at`.

This is the step that used to be described (incorrectly, in the Phase 3 draft) as happening synchronously when staff enter a code — it does not. By the time a code exists for staff to enter, the table decision has already been made and reserved.

## 6a. Staff seat by code (confirmation, not allocation)

**Preconditions:** authenticated staff session; a seating code corresponding to a `ready` entry.

**Behavior:**
1. Resolve code → entry. Unknown code, or a code belonging to an entry that isn't currently `ready` (already seated, already used, released/expired, or never existed) → reject with a clear error, no state change.
2. Confirm the entry's `SeatingAssignment` is still `pending` and has not been released/expired out from under it (DEC-015's lazy check applies here too — if this specific entry's own reservation is found to be overdue at the moment staff submit, the same expiration path fires instead of confirming a stale hold).
3. If still valid: atomically transition the `SeatingAssignment` `pending → active` and the entry `ready → seated`, in one transaction.
   - Success: entry → `seated`; the assignment's table(s) are now `occupied` (a read-time join, not a new write to the claim rows — see `03-architecture/domain-model.md` §2).
   - Failure (the entry was concurrently expired/released by another process in the narrow window between staff reading the code and submitting it): reject cleanly with a "reservation no longer valid" error, no partial state change. The entry does not silently re-enter `waiting` — per DEC-015, an expired `ready` entry is `no_show` (terminal).

Staff never perform the allocation decision itself — only confirm one already made (`04-diagrams/05-combined-table-atomic-allocation.md`, `04-diagrams/04-seating-allocation.md`).

## 7. Staff release

**Preconditions:** authenticated staff session; a seated entry identified by `queue_entry_id`.

**Behavior:** the API resolves the entry's `SeatingAssignment` internally (never accepts a raw `table_id` from the caller, DEC-014) and releases it atomically as one unit: the assignment's `status → released`, and its `SeatingAssignmentTable` row(s) get `released_at` set (never deleted — history is retained) — if combined, both rows together, so both member tables become independently free at once (INV-006, INV-015). Idempotent: releasing an already-released entry is a safe no-op, not an error.

## 8. Staff mark no-show

**Preconditions:** authenticated staff session; a `waiting` **or `ready`** entry.

**Behavior:** entry → `no_show` (terminal). If the entry was `ready`, its `SeatingAssignment` is released in the same transaction, exactly as in §7 — a staff-initiated no-show on a `ready` entry and DEC-015's automatic expiration converge on the same outcome (§11). Idempotent against an already-terminal entry (safe no-op or clear rejection, not corruption — exact choice an implementation-phase detail, but must not silently re-fire side effects like notifications).

## 8a. Automatic no-show — READY expiration (DEC-015)

**Trigger:** not a staff action. A `ready` entry whose `ready_at` is more than the configured timeout (5 minutes, tunable) in the past, discovered **lazily** — as a side effect of any operation that already reads or writes that entry or the tables it holds: guest position read (§2), staff queue/table view (§5), a new guest join (§1, if the entry's held table(s) are relevant to that join's allocation), the allocation pass (§6), or another seating operation (§6a, §7, §8) touching the same entry/tables. **No scheduler, cron, or background job performs this check** — it never runs except embedded in an operation that was going to touch the database anyway.

**Behavior:** identical to §8's staff-initiated no-show on a `ready` entry — `status → no_show`, `no_show_at` set, `SeatingAssignment` released. The response/record does not distinguish "staff marked it" from "expiration caught it" (`03-architecture/data-model.md`).

**Concurrency:** guarded the same way as any other transition off `ready` (`SELECT ... FOR UPDATE` on the entry) — see `domain-model-proposal.md` §11 for the full concurrency plan, including the case where two operations discover the same overdue entry at once.

## 9. Position computation

Applies to `waiting` entries only — a `ready` entry has no numeric position (§2); it's no longer competing against other waiting groups, it's holding a reservation pending staff confirmation. Recomputed on read (or on the relevant write events if a cache is introduced, P1), from **current** state only — current waiting groups, current table availability/capacity/adjacency/compatibility, waiting time, and starvation-protection state (`02-product-decisions/seating-allocation-policy.md`). Never presented as a guaranteed exact count, and never a prediction of when a table will next become free (DEC-005).

## 10. Error handling shared across all write operations

- Validation errors are distinguishable from conflict errors (e.g., "invalid code" vs. "already seated"), so the frontend can show the correct empty/error state per REQ-FE-003/004/005.
- No operation ever leaves the database in a state that violates an invariant in `03-architecture/domain-model.md`, even under failure/retry.
