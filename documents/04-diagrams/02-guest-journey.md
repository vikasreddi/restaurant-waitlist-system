# Diagram — Guest Journey

```mermaid
stateDiagram-v2
    [*] --> Landing: scan shared QR code
    Landing --> Joining: enter group size + phone number
    Joining --> Waiting: join accepted (idempotent)
    Joining --> Landing: validation error (retry)

    Waiting --> Waiting: position updates (re-render on change)
    Waiting --> ReadyCodeShown: seating configuration allocated
    Waiting --> Left: guest leaves voluntarily
    Waiting --> NoShow: staff marks no-show

    ReadyCodeShown --> Seated: staff enters code, seats group

    Left --> [*]
    NoShow --> [*]
    Seated --> [*]

    Landing --> Waiting: reopen page with active-visit token\n(recovers existing entry, REQ-GUEST-004)
```

Notes:
- "Reopen page" only resumes a *non-terminal* (`Waiting`/`ReadyCodeShown`) entry — a terminal entry (`Left`/`NoShow`/`Seated`) does not behave as an active session again (DEC-006).
- `ReadyCodeShown` corresponds to the guest seeing their seating code (REQ-GUEST-005); it is not itself a persisted `QueueEntry` status beyond `waiting` — see `03-architecture/domain-model.md` for the authoritative state machine.
