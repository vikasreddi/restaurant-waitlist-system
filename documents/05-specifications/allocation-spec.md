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
function compatible_configurations(group_size):
    configs = []
    for each free single table T where T.capacity >= group_size:
        configs.add(SingleTable(T))
    for each free adjacent pair (T1, T2) where T1.capacity + T2.capacity >= group_size
                                          and T1.status == free and T2.status == free:
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

## 5. Atomic allocation

```
function allocate(group, configuration):
    begin transaction
        if configuration is SingleTable(T):
            lock/check T is still free
            if not free: rollback; return FAILURE
            T.status = occupied; T.current_queue_entry_id = group.id
        else if configuration is CombinedPair(T1, T2):
            lock/check T1 is still free AND T2 is still free
            if either not free: rollback; return FAILURE   # both-or-neither, INV-005
            create TableCombination(T1, T2, group.id)
            T1.status = combined; T2.status = combined
        group.status = seated
        group.seated_at = now
    commit transaction
    return SUCCESS
```

Any failure path rolls back the entire transaction — no intermediate state (one table touched, the other not) is ever committed (INV-005, INV-008).

## 6. Release

Takes the seated `queue_entry_id` only — never a raw `table_id`/`combination_id` supplied by the caller (DEC-014, INV-015). This is already how the function is shaped below: it resolves internally which assignment the group holds and releases the whole thing atomically.

```
function release(queue_entry_id):
    begin transaction
        group = load QueueEntry(queue_entry_id)   # sole input; caller never names a table directly
        if group.assigned_table_id is set:
            table.status = free; table.current_queue_entry_id = null
        else if group.assigned_combination_id is set:
            combination.dissolved_at = now
            for table in combination.tables:
                table.status = free; table.current_queue_entry_id = null; table.combination_id = null
    commit transaction
    trigger allocation re-evaluation for now-free configuration(s)   # see §3
```

## 7. Worked example — why smallest-fit prevents unnecessary waiting

Group of 2 arrives when T1 (2-seat) is occupied but T2 (4-seat) is free. `compatible_configurations(2)` includes T2. `eligible_groups(T2)` includes this group (and possibly others needing ≤4). If no larger-need group is also eligible/older/protected for T2, this group is seated at T2 rather than waiting for T1 to free — directly implementing Stage 3 of `seating-allocation-policy.md`.

## 8. Worked example — combined-pair race (ties to `04-diagrams/05-combined-table-atomic-allocation.md`)

Two staff actions both attempt `allocate(group, CombinedPair(T1, T2))` concurrently. The transactional lock/check in §5 ensures only one commits; the other observes T1 or T2 no longer free and returns `FAILURE` cleanly, with its group remaining `waiting` for re-evaluation.
