# Diagram — Combined-Table Atomic Allocation

Illustrates INV-005 (all-or-nothing) under a concurrent race for the same adjacent pair. **Both participants here are the allocation service** (system-triggered, e.g. two release/no-show events each independently re-triggering allocation) — not staff. Staff never perform this step; see `03-staff-journey.md` for the separate confirmation flow.

```mermaid
sequenceDiagram
    participant A1 as Allocation attempt A (group X, T1+T2)
    participant DB as Database (transactional)
    participant A2 as Allocation attempt B (group Y, T1+T2)

    A1->>DB: BEGIN TRANSACTION
    A1->>DB: Lock T1, T2 (SELECT ... FOR UPDATE, consistent order)
    par concurrent attempt
        A2->>DB: BEGIN TRANSACTION
        A2->>DB: Lock T1, T2
    end
    DB-->>A1: T1 + T2 acquired (no non-released claim row exists for either)
    A1->>DB: INSERT SeatingAssignment(group X, status=pending)
    A1->>DB: INSERT SeatingAssignmentTable(T1), SeatingAssignmentTable(T2)
    A1->>DB: UPDATE QueueEntry(group X): status=ready, seating_code=...
    A1->>DB: COMMIT
    DB-->>A2: INSERT SeatingAssignmentTable(T1 or T2) violates<br/>UNIQUE(table_id) WHERE released_at IS NULL
    A2->>DB: ROLLBACK (no partial allocation)
    DB-->>A2: Allocation failed cleanly, no state change
```

Notes:
- Whichever transaction commits first wins the full pair; the loser's transaction rolls back entirely — there is no state where one of T1/T2 has a claim row while the other doesn't (INV-005, INV-008).
- The result of the winning transaction is `ready`, **not** `seated` — group X still needs staff to confirm via the seating code (`allocation-spec.md` §5a) before actually being seated. This diagram illustrates the allocation race only.
- The losing attempt's group remains `waiting` and is re-evaluated on the next allocation pass (`04-seating-allocation.md`), not left in an inconsistent or partially-reserved state.
- The database-level backstop here is the `UNIQUE(table_id) WHERE released_at IS NULL` constraint on `SeatingAssignmentTable` (finalized design — see `06-ai-working-record/ai-corrections.md` CORR-004 for why an earlier, denormalized-status version of this constraint would not actually have worked in PostgreSQL). Row locking is the primary mechanism; this constraint is what makes the guarantee hold even if locking discipline is ever imperfect.
