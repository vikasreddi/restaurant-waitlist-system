# Diagram — High-Level Architecture / Data Flow

```mermaid
flowchart LR
    subgraph Clients
        GuestSPA["Guest SPA (React + TS)"]
        StaffSPA["Staff SPA (React + TS)"]
    end

    subgraph Backend["Rails API"]
        JoinH["Join handler\n(validates size, idempotent)"]
        ReadH["Position/read handler\n(also: lazy DEC-015\nexpiration checkpoint)"]
        AllocH["Allocation service\n(system-triggered — join/release/\nno-show/leave — NEVER staff-triggered.\nwaiting -> ready, creates SeatingAssignment)"]
        ConfirmH["Confirm handler\n(staff seat-by-code —\nready -> seated ONLY;\nnever allocates)"]
        ReleaseH["Release handler\n(by queue_entry_id)"]
        NoShowH["No-show handler\n(staff-initiated OR\nDEC-015 lazy expiration)"]
    end

    DB[("PostgreSQL — source of truth\ntables, table_adjacency, queue_entries,\nseating_assignments,\nseating_assignment_tables")]
    Cache[("Redis — P1\nguest read path only,\nnever authoritative")]
    Worker["Sidekiq worker — P1"]

    GuestSPA -->|join| JoinH --> DB
    JoinH -.->|triggers, on the event\nthat frees a configuration| AllocH --> DB
    GuestSPA -->|view position| ReadH
    ReadH -.->|check, P1| Cache
    ReadH --> DB
    GuestSPA -->|leave| Backend

    StaffSPA -->|seat by code| ConfirmH --> DB
    StaffSPA -->|release seating assignment| ReleaseH --> DB
    ReleaseH -.->|triggers re-evaluation| AllocH
    StaffSPA -->|no-show| NoShowH --> DB
    NoShowH -.->|triggers re-evaluation, if a\nready reservation is released| AllocH

    ConfirmH -.->|invalidate on write, P1| Cache
    ReleaseH -.->|invalidate on write, P1| Cache
    JoinH -.->|invalidate on write, P1| Cache
    NoShowH -.->|invalidate on write, P1| Cache
    AllocH -.->|invalidate on write, P1| Cache

    ConfirmH -.->|enqueue "table ready", P1| Worker
```

Notes:
- **`AllocH` (allocation) and `ConfirmH` (staff confirmation) are deliberately separate boxes** — revised from an earlier version of this diagram, which had one "Seat handler" doing both. The allocation service decides *which* table(s) a group gets and reserves them (`waiting → ready`), triggered by system events, never directly by a staff request. `ConfirmH` only ever validates and activates an already-existing reservation (`ready → seated`) — it never runs the allocation algorithm. See `05-specifications/allocation-spec.md` §5 vs. §5a.
- Every write handler that changes queue/table state is a cache-invalidation trigger (P1) — this is the explicit list from `01-requirements/acceptance-criteria.md` REQ-SHOW-002.
- The notification worker (Sidekiq) is only ever triggered from `ConfirmH` (the actual seating moment), off the synchronous request path (REQ-SHOW-003), and re-reads PostgreSQL at execution time rather than acting on stale embedded state.
- `ReleaseH` takes `queue_entry_id` only — it resolves the entry's `SeatingAssignment` internally and releases it atomically (`released_at` set on the claim row(s), never deleted); there is no path that accepts a raw `table_id` (DEC-014).
- `ReadH` is also a DEC-015 lazy-expiration checkpoint: if it touches a `ready` entry whose reservation is overdue, it expires it (→ `no_show`, releases via the same path as `NoShowH`) before returning a response — there is no separate scheduler anywhere in this diagram.
- Redis (`Cache`) is read by `ReadH` only, and is never consulted by `JoinH`, `AllocH`, `ConfirmH`, `ReleaseH`, or `NoShowH` to decide table availability — those always go straight to PostgreSQL (DEC-013, INV-014).
- The DB box lists `seating_assignments`/`seating_assignment_tables` — replacing the earlier draft's `table_combinations`/`idempotency_records` (idempotency is a column on `queue_entries`, not a separate table; see `06-ai-working-record/ai-corrections.md` CORR-004 for the `seating_assignment_tables` correction specifically).
