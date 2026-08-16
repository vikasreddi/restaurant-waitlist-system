# Diagram — Seating Allocation Policy

Compatibility-Aware Aging with Maximum-Wait Protection (`02-product-decisions/seating-allocation-policy.md`). Renamed in Session 2 human review — see `06-ai-working-record/ai-corrections.md` CORR-002.

This is a global reasoning process over all currently compatible configurations and waiting groups — explicitly **not** naive per-table greedy iteration (`for each table: find first group that fits; seat it`), which cannot correctly express smallest-fit preference or starvation protection.

```mermaid
flowchart TD
    Start(["A table/combination just became free"]) --> Compatible["Available table configurations\n→ compatible waiting groups\n(Stages 1-2)"]

    Compatible --> AnyCompatible{"Any compatible waiting group?"}
    AnyCompatible -->|no| Idle["Configuration stays free"]

    AnyCompatible -->|yes| DetermineEligible["Determine eligible allocations"]

    DetermineEligible --> AnyProtected{"Apply starvation protection:\nis any eligible group\nstarvation-protected for THIS\ncomplete configuration?"}

    AnyProtected -->|yes| ProtectedWins["Protected group gets priority\nfor this configuration (Stage 5)"]
    AnyProtected -->|no| SmallestFit["Prefer smallest suitable\navailable configuration (Stage 3)"]

    SmallestFit --> Aging["Apply waiting-time aging among\ngroups tied on fit (Stage 4)"]

    ProtectedWins --> Select["Select allocation"]
    Aging --> Select

    Select --> Allocate["Atomic database transaction (Stage 6)\n(both tables or none if combined)"]

    Allocate --> Success{"All required tables\nstill acquirable?"}
    Success -->|yes| Ready["Group becomes READY\n(SeatingAssignment: pending,\nseating_code generated) —\nNOT yet seated"]
    Success -->|no, lost race| Retry["Allocation fails cleanly,\nconfiguration re-evaluated"]
    Ready -.->|staff confirm code, separate\nlater step, see 03-staff-journey| Seated["Group seated"]
```

Critical rule reminder (`seating-allocation-policy.md` Stage 5): starvation protection only ever applies once the group's **complete** required configuration is simultaneously available — a lone free table that is only half of a protected group's need does not trigger `AnyProtected = yes`.

**Precise guarantee (corrected wording):** maximum-wait protection guarantees priority when the group's complete compatible seating configuration becomes available. It does not guarantee an absolute maximum total waiting time (`starvation-policy.md`).

**This entire flow ends at READY, not SEATED.** Everything above is the allocation service's decision — it runs on system events (join/release/no-show/leave), never on a staff action. Staff confirmation (`ready → seated`) is a separate, later flow — see `03-staff-journey.md` — that only validates and activates the reservation this flow already made; it never re-runs any step above.
