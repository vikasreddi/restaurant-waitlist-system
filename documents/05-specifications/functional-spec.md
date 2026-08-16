# Functional Specification

Status: specification only, not implementation. Consolidates `01-requirements/` and `02-product-decisions/` into implementation-ready behavior. Where a decision remains open, it is marked `OPEN` here too — this document does not resolve open decisions on its own authority.

## 1. Guest join

**Preconditions:** none (public endpoint).

**Inputs:** group size (positive integer), phone number, client-generated idempotency key.

**Behavior:**
1. Validate group size and phone number format. Invalid input → validation error, no entry created.
2. Check group size against the largest seatable configuration (a single largest table, or the best two-table adjacent combination under DEC-002). If no configuration — single or combined — can ever seat this group size, **reject the join with a clear validation error** directing the group to speak to staff directly; no entry is created (DEC-011, resolving the former OPEN-006). This keeps every `waiting` entry guaranteed-seatable by construction.
3. Check idempotency key against `idempotency_records` (unique constraint, `03-architecture/data-model.md`). The key is a client-generated UUID, reused verbatim on retry of the same attempt; a genuinely new join attempt uses a new key (`04-diagrams/06-guest-join-idempotency.md`).
   - Key not seen: create `QueueEntry` (status `waiting`), record the idempotency key, return position + active-visit token.
   - Key already seen: return the existing entry's current position + token, do not create a new entry (REQ-GUEST-007, INV-007).
4. Response includes: queue entry id (or opaque reference via token), computed position, active-visit token.

## 2. Guest view position / recover visit

**Preconditions:** caller presents an active-visit token.

**Behavior:**
- Token maps to a non-terminal entry → return current computed position and status.
- Token maps to a terminal entry (`seated`/`left`/`no_show`) → do not resume it as an active session (DEC-006); response reflects the terminal outcome, not a live position.
- Token unknown/invalid → guest is treated as not having an active visit (landing/join state), not an error that implies something is broken.

## 3. Guest leave

**Preconditions:** caller's token maps to a non-terminal entry.

**Behavior:** transition entry to `left`. Idempotent: leaving an already-`left` (or otherwise terminal) entry is a safe no-op, not an error that confuses the guest.

## 4. Staff login

**Preconditions:** none (public login endpoint).

**Behavior:** stub-strength credential check (REQ-STAFF-001) issues a staff session. Invalid credentials → generic authentication error (no user enumeration).

## 5. Staff view queue / tables

**Preconditions:** authenticated staff session.

**Behavior:** returns current queue entries (with computed position) and current table states. No caching requirement for the staff view in P0 (only the guest read path is a caching candidate, REQ-SHOW-002).

## 6. Staff seat by code

**Preconditions:** authenticated staff session; a seating code corresponding to a `waiting` entry.

**Behavior:**
1. Resolve code → entry. Unknown/already-used/non-waiting code → reject with a clear error, no state change.
2. Determine the entry's allocatable configuration per `allocation-spec.md`.
3. Attempt atomic allocation (`04-diagrams/05-combined-table-atomic-allocation.md`).
   - Success: entry → `seated`; table(s) → `occupied`/`combined`.
   - Failure (lost race, required table no longer available): reject cleanly, no partial state change, entry remains `waiting` and is re-evaluated on the next allocation pass.

## 7. Staff release

**Preconditions:** authenticated staff session; a seated entry identified by `queue_entry_id`.

**Behavior:** the API resolves the entry's complete seating assignment internally (single table or combined pair — never accepts a raw `table_id`/`combination_id` from the caller, DEC-014) and releases it atomically as one unit: table(s) → `free`; if combined, `TableCombination` dissolves and both member tables become independently free (INV-006, INV-015). Idempotent: releasing an already-released entry is a safe no-op, not an error.

## 8. Staff mark no-show

**Preconditions:** authenticated staff session; a `waiting` entry.

**Behavior:** entry → `no_show` (terminal). Idempotent against an already-terminal entry (safe no-op or clear rejection, not corruption — exact choice an implementation-phase detail, but must not silently re-fire side effects like notifications).

## 9. Position computation

Recomputed on read (or on the relevant write events if a cache is introduced, P1), from **current** state only — current waiting groups, current table availability/capacity/adjacency/compatibility, waiting time, and starvation-protection state (`02-product-decisions/seating-allocation-policy.md`). Never presented as a guaranteed exact count, and never a prediction of when a table will next become free (DEC-005).

## 10. Error handling shared across all write operations

- Validation errors are distinguishable from conflict errors (e.g., "invalid code" vs. "already seated"), so the frontend can show the correct empty/error state per REQ-FE-003/004/005.
- No operation ever leaves the database in a state that violates an invariant in `03-architecture/domain-model.md`, even under failure/retry.
