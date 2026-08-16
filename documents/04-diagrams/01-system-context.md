# Diagram — System Context

```mermaid
flowchart TB
    Guest["Guest (phone browser)"]
    Staff["Staff (login required)"]
    QR["Shared QR code / link"]

    subgraph App["Restaurant Waitlist Application"]
        GuestSPA["Guest SPA (React + TypeScript)"]
        StaffSPA["Staff SPA (React + TypeScript)"]
        API["Rails API"]
        DB[("PostgreSQL — source of truth")]
        Cache[("Redis — cache, P1")]
        Queue["Sidekiq worker — P1"]
    end

    Guest -->|scans| QR --> GuestSPA
    Staff -->|logs in| StaffSPA

    GuestSPA -->|join / view position / leave| API
    StaffSPA -->|login / view queue+tables / seat / release / no-show| API

    API --> DB
    API -.->|read path only, P1, never authoritative| Cache
    API -.->|table-ready notification, P1| Queue
```

Notes:
- One shared QR code for all guests (no per-guest identity in the link itself) — REQ-GUEST-001.
- Staff SPA is behind stub auth; Guest SPA is public — NFR-SEC-001/002.
- Redis and Sidekiq are P1; the system is fully functional without them for P0. PostgreSQL is always the sole source of truth for table allocation (DEC-013).
