# Diagram — High-Level Architecture / Data Flow

```mermaid
flowchart LR
    subgraph Clients
        GuestSPA["Guest SPA (React + TS)"]
        StaffSPA["Staff SPA (React + TS)"]
    end

    subgraph Backend["Rails API"]
        JoinH["Join handler\n(validates size, idempotent)"]
        ReadH["Position/read handler"]
        SeatH["Seat handler\n(atomic allocation)"]
        ReleaseH["Release handler\n(by queue_entry_id)"]
        NoShowH["No-show handler"]
    end

    DB[("PostgreSQL — source of truth\ntables, queue_entries,\ntable_combinations,\nidempotency_records")]
    Cache[("Redis — P1\nguest read path only,\nnever authoritative")]
    Worker["Sidekiq worker — P1"]

    GuestSPA -->|join| JoinH --> DB
    GuestSPA -->|view position| ReadH
    ReadH -.->|check, P1| Cache
    ReadH --> DB
    GuestSPA -->|leave| Backend

    StaffSPA -->|seat by code| SeatH --> DB
    StaffSPA -->|release seating assignment| ReleaseH --> DB
    StaffSPA -->|no-show| NoShowH --> DB

    SeatH -.->|invalidate on write, P1| Cache
    ReleaseH -.->|invalidate on write, P1| Cache
    JoinH -.->|invalidate on write, P1| Cache
    NoShowH -.->|invalidate on write, P1| Cache

    SeatH -.->|enqueue "table ready", P1| Worker
```

Notes:
- Every write handler that changes queue/table state is a cache-invalidation trigger (P1) — this is the explicit list from `01-requirements/acceptance-criteria.md` REQ-SHOW-002.
- The notification worker (Sidekiq) is only ever triggered from the seat handler, off the synchronous request path (REQ-SHOW-003), and re-reads PostgreSQL at execution time rather than acting on stale embedded state.
- `ReleaseH` takes `queue_entry_id` only — it resolves the entry's complete seating assignment (single table or combined pair) internally and releases it atomically; there is no path that accepts a raw `table_id` (DEC-014).
- Redis (`Cache`) is read by `ReadH` only, and is never consulted by `JoinH`, `SeatH`, `ReleaseH`, or `NoShowH` to decide table availability — those always go straight to PostgreSQL (DEC-013, INV-014).
