# Diagram — Combined-Table Atomic Allocation

Illustrates INV-005 (all-or-nothing) under a concurrent race for the same adjacent pair.

```mermaid
sequenceDiagram
    participant S1 as Staff action A (seat Group X on T1+T2)
    participant DB as Database (transactional)
    participant S2 as Staff/system action B (seat Group Y on T1+T2)

    S1->>DB: BEGIN TRANSACTION
    S1->>DB: Lock/check T1 (free), T2 (free)
    par concurrent attempt
        S2->>DB: BEGIN TRANSACTION
        S2->>DB: Lock/check T1, T2
    end
    DB-->>S1: T1 + T2 acquired
    S1->>DB: Mark T1, T2 = combined, form TableCombination, Group X -> seated
    S1->>DB: COMMIT
    DB-->>S2: T1 (or T2) no longer free — conflict detected
    S2->>DB: ROLLBACK (no partial allocation)
    DB-->>S2: Allocation failed cleanly, no state change
```

Notes:
- Whichever transaction commits first wins the full pair; the loser's transaction rolls back entirely — there is no state where one of T1/T2 ends up combined while the other doesn't (INV-005, INV-008).
- The losing action's group remains `waiting` and is re-evaluated on the next allocation pass (`04-seating-allocation.md`), not left in an inconsistent or partially-seated state.
- Exact locking mechanism (pessimistic row lock vs. optimistic version check + retry) is an implementation-phase decision; either satisfies this atomicity contract.
