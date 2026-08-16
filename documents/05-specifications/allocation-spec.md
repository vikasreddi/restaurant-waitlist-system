# Allocation Specification

Status: specification only — pseudocode below describes required behavior for the implementation phase; it is not application code and must not be copy-pasted as-is into the codebase without being written idiomatically for Rails/ActiveRecord (DEC-012).

Implements `02-product-decisions/seating-allocation-policy.md` and `starvation-policy.md`.

## Not naive greedy table iteration

None of the functions below implement:

```
for each table:
    find first group that fits
    seat it
```

That pattern cannot correctly express smallest-fit preference or starvation protection, because it reasons about one table at a time instead of over all currently compatible configurations and all currently eligible waiting groups together. §2–§3 below are configuration-centric (`eligible_groups(configuration)`), not table-iteration-centric, by design.

## 0. Oversized-group rejection (join time, DEC-011)

```
function largest_seatable_capacity():
    return max(capacity of any single table, max over adjacent pairs of T1.capacity + T2.capacity)

function validate_join(group_size):
    if group_size > largest_seatable_capacity():
        return REJECT("group size exceeds all seatable configurations — please speak to staff")
    return ACCEPT
```

Run once, at join time, before a `QueueEntry` is ever created. This guarantees every entry considered by §1–§6 below is seatable by some currently-or-eventually-available configuration — the allocation and starvation logic never has to special-case an entry that can never be seated.

## 1. Compatibility function

```
# "free" is derived, not a stored field (finalized Phase 5B.1 model —
# 03-architecture/domain-model.md §2): a table is free iff no
# SeatingAssignmentTable row with released_at IS NULL references it.
function is_free(table):
    return not exists SeatingAssignmentTable row
                where table_id = table.id and released_at IS NULL

function compatible_configurations(group_size):
    configs = []
    for each single table T where is_free(T) and T.capacity >= group_size:
        configs.add(SingleTable(T))
    for each adjacent pair (T1, T2) where is_free(T1) and is_free(T2)
                                       and T1.capacity + T2.capacity >= group_size:
        configs.add(CombinedPair(T1, T2))
    return configs
```

Per DEC-002, only single tables and exactly-two-table adjacent pairs are considered — never triples.

## 2. Eligible groups for a configuration

```
function eligible_groups(configuration):
    return all waiting groups G such that configuration is in compatible_configurations(G.group_size)
```

## 3. Selection when a configuration becomes available (triggered on release, no-show, leave, or join)

```
function select_group_for(configuration):
    candidates = eligible_groups(configuration)
    if candidates is empty:
        return none   # configuration stays free

    protected = [g in candidates where g.is_starvation_protected
                                  and configuration fully satisfies g's requirement]
    if protected is not empty:
        return oldest_by_wait_time(protected)   # Stage 5

    smallest_fit_candidates = candidates filtered to configurations
                               that are the smallest available fit for each candidate
    return oldest_by_wait_time(smallest_fit_candidates)   # Stages 3-4
```

Note: `is_starvation_protected` is only ever evaluated against the **complete** configuration a group needs (INV-013) — a candidate needing a combined pair is never "protected" with respect to a single free table that is only half its requirement. This is enforced by `eligible_groups` already restricting candidates to those the configuration *fully* satisfies.

## 4. Starvation protection trigger

```
function update_starvation_protection():
    for each waiting group G:
        if G.starvation_protected_since is null
           and (now - G.joined_at) >= MAX_WAIT_THRESHOLD:
            G.starvation_protected_since = now
```

Run on a schedule or on every relevant read/write (implementation choice); `MAX_WAIT_THRESHOLD` is configurable (illustrated as 20 minutes, DEC-004). Crossing this threshold grants **priority once the group's complete configuration is available** — it does not itself guarantee an absolute maximum total wait (`starvation-policy.md`).

## 5. Atomic allocation — produces READY, not SEATED

**Corrected from an earlier draft of this document, which had this function set `group.status = seated` directly.** That was wrong against the finalized model: allocation reserves a configuration and shows the guest a code — it does not seat them. Seating only happens later, when staff confirm (§5a). See `domain-model-proposal.md` §0 for the full reasoning behind why `ready` exists as a separate step.

```
function allocate(group, configuration):
    begin transaction
        if configuration is SingleTable(T):
            lock T (SELECT ... FOR UPDATE)
            if not is_free(T): rollback; return FAILURE
            create SeatingAssignment(queue_entry_id: group.id, status: pending)
            create SeatingAssignmentTable(seating_assignment_id: assignment.id, table_id: T.id)
        else if configuration is CombinedPair(T1, T2):
            lock T1, T2 in a consistent order (e.g. by id, to avoid deadlocks)
            if not (is_free(T1) and is_free(T2)): rollback; return FAILURE   # both-or-neither, INV-005
            create SeatingAssignment(queue_entry_id: group.id, status: pending)
            create SeatingAssignmentTable(seating_assignment_id: assignment.id, table_id: T1.id)
            create SeatingAssignmentTable(seating_assignment_id: assignment.id, table_id: T2.id)
            # if either INSERT above violates the released_at-IS-NULL unique constraint
            # (table claimed by a concurrent transaction between the lock and the insert),
            # the transaction fails and rolls back — both claim rows or neither ever exist.
        group.status = ready
        group.ready_at = now
        group.seating_code = generate_code()   # format: OPEN-005, still undecided
    commit transaction
    return SUCCESS
```

Any failure path rolls back the entire transaction — no intermediate state (one table claimed, the other not; or an assignment row with no matching claim rows) is ever committed (INV-005, INV-008).

## 5a. Staff confirmation — READY → SEATED

Not part of allocation. This runs when staff submit a `seating_code` (`functional-spec.md` §6a) — a separate operation, on a separate trigger, from a separate actor.

```
function confirm_seating(seating_code):
    begin transaction
        group = load QueueEntry where seating_code = seating_code (SELECT ... FOR UPDATE)
        if group not found or group.status != ready:
            rollback; return NOT_FOUND_OR_INVALID
        if group.ready_at + MAX_READY_WAIT < now:   # DEC-015 — expire instead of confirming a stale hold
            expire_ready(group)   # see §6a below; converts to no_show, releases the assignment
            rollback; return EXPIRED
        assignment = group's pending SeatingAssignment
        assignment.status = active; assignment.activated_at = now
        group.status = seated; group.seated_at = now
    commit transaction
    return SUCCESS
```

Note what this function does **not** do: it never calls `compatible_configurations`, `eligible_groups`, or `select_group_for` — the allocation decision was already made and committed in §5. Staff confirmation only ever validates and activates an existing reservation.

## 6. Release

Takes the seated `queue_entry_id` only — never a raw `table_id` supplied by the caller (DEC-014, INV-015). This is already how the function is shaped below: it resolves internally which assignment the group holds and releases the whole thing atomically.

```
function release(queue_entry_id):
    begin transaction
        group = load QueueEntry(queue_entry_id)   # sole input; caller never names a table directly
        assignment = group's non-released SeatingAssignment
        assignment.status = released; assignment.released_at = now
        for claim_row in assignment's SeatingAssignmentTable rows:
            claim_row.released_at = now   # NOT deleted — history retained (finalized design, see
                                           # 06-ai-working-record/ai-corrections.md CORR-004)
    commit transaction
    trigger allocation re-evaluation for now-free configuration(s)   # see §3
```

## 6a. Lazy READY expiration (DEC-015)

Not a scheduled job. This function is called *inline*, as a check embedded in operations that already touch a `ready` entry or the tables it holds — never on its own timer.

```
function expire_ready(group):
    # Precondition: caller already holds a lock on `group` (e.g., via confirm_seating above,
    # or via whatever read/write path discovered the overdue entry) and has already verified
    # group.status == ready and group.ready_at + MAX_READY_WAIT < now.
    begin transaction
        group.status = no_show; group.no_show_at = now   # same terminal state as staff-initiated no-show
        assignment = group's pending SeatingAssignment
        assignment.status = released; assignment.released_at = now
        for claim_row in assignment's SeatingAssignmentTable rows:
            claim_row.released_at = now
    commit transaction
    trigger allocation re-evaluation for now-free configuration(s)   # see §3
```

`MAX_READY_WAIT` is configurable (illustrated as 5 minutes, DEC-015) — same treatment as `MAX_WAIT_THRESHOLD` (§4). Called from: `confirm_seating` (§5a, before confirming a possibly-stale hold), any position/queue read that touches this entry, any allocation pass that would otherwise consider this entry's held table(s) as unavailable indefinitely. Two concurrent callers discovering the same overdue entry are serialized by the same row lock `confirm_seating` uses — whichever acquires it first performs the expiration; the second sees `status == no_show` already and no-ops.

## 7. Worked example — why smallest-fit prevents unnecessary waiting

Group of 2 arrives when T1 (2-seat) is occupied but T2 (4-seat) is free. `compatible_configurations(2)` includes T2. `eligible_groups(T2)` includes this group (and possibly others needing ≤4). If no larger-need group is also eligible/older/protected for T2, this group becomes `ready` at T2 (code shown, staff confirmation pending) rather than waiting for T1 to free — directly implementing Stage 3 of `seating-allocation-policy.md`. It is *not yet* `seated` at this point — that's a separate step, §5a, triggered by staff.

## 8. Worked example — combined-pair race (ties to `04-diagrams/05-combined-table-atomic-allocation.md`)

Two concurrent allocation passes both attempt `allocate(group, CombinedPair(T1, T2))` — this is a race between two *allocation* attempts (system-triggered, e.g. two tables freeing in quick succession each triggering a re-evaluation), not two staff actions; staff never call `allocate` directly. The transactional lock/check in §5 ensures only one commits; the other observes T1 or T2 no longer free and returns `FAILURE` cleanly, with its group remaining `waiting` for re-evaluation.
