# Diagram — Staff Journey

```mermaid
flowchart TD
    Login["Log in (email/password stub)"] --> Dashboard["View live queue + table states<br/>(waiting entries + ready entries,<br/>DEC-015 lazy-expiration checkpoint)"]

    Dashboard --> SeatChoice{"Group's code entered"}
    SeatChoice -->|valid, currently READY| Confirm["Confirm reservation (atomic)<br/>NOT an allocation decision —<br/>that already happened, system-side"]
    SeatChoice -->|invalid/used/unknown/not-ready code| RejectSeat["Reject — clear error, no state change"]

    Confirm -->|success| Seated["Group seated, table(s) occupied<br/>(assignment pending -> active)"]
    Confirm -->|reservation expired since code was shown, DEC-015| RejectSeat
    Confirm -->|reservation released concurrently| RejectSeat

    Seated --> WaitForGroupToLeave["Group dines"]
    WaitForGroupToLeave --> Release["Staff releases the group's<br/>seating assignment (by queue entry,<br/>not a raw table id — DEC-014)"]
    Release --> Dashboard

    Dashboard --> NoShowChoice{"Waiting or READY group<br/>never arrives / confirms"}
    NoShowChoice -->|staff marks no-show| NoShow["Entry -> no_show (terminal)<br/>if READY, its reservation is<br/>released in the same transaction"]
    NoShow --> Dashboard

    Dashboard -.->|"5-min timeout on a READY entry<br/>(lazy — checked here, not by a<br/>background job, DEC-015)"| NoShow
```

Notes:
- Staff never run the allocation algorithm. The system (allocation service, triggered by join/release/no-show/leave events) already chose a group's table configuration *before* that group ever shows a code — "Confirm" only validates and activates an existing `pending` `SeatingAssignment`. See `05-specifications/allocation-spec.md` §5 vs. §5a for the split.
- Release sets `released_at` on the assignment's `SeatingAssignmentTable` row(s) (never deletes them — history retained) — both together if combined, so both member tables become independently available at once (INV-006, CORR-004).
- The dashed edge into `NoShow` represents DEC-015: any dashboard view (or other operation touching a `ready` entry) that notices a reservation held past 5 minutes converts it to `no_show` and releases its table(s) inline, as a side effect of that read — not via a scheduler.
