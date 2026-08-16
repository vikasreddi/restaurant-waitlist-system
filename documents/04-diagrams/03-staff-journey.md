# Diagram — Staff Journey

```mermaid
flowchart TD
    Login["Log in (email/password stub)"] --> Dashboard["View live queue + table states"]

    Dashboard --> SeatChoice{"Group's code entered"}
    SeatChoice -->|valid, currently waiting| Allocate["Run allocation (atomic)"]
    SeatChoice -->|invalid/used/unknown code| RejectSeat["Reject — clear error, no state change"]

    Allocate -->|success| Seated["Group seated, table(s) occupied"]
    Allocate -->|required table(s) unavailable at commit| RejectSeat

    Seated --> WaitForGroupToLeave["Group dines"]
    WaitForGroupToLeave --> Release["Staff releases the group's\nseating assignment (by queue entry,\nnot a raw table id — DEC-014)"]
    Release --> Dashboard

    Dashboard --> NoShowChoice{"Waiting group never arrives"}
    NoShowChoice -->|staff marks no-show| NoShow["Entry → no_show (terminal)"]
    NoShow --> Dashboard
```

Notes:
- "Allocate" is the atomic step implementing REQ-TABLE-006/INV-005 — both required tables or neither.
- Release dissolves any active `TableCombination` back into two independent tables (INV-006).
