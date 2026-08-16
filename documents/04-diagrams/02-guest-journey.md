# Diagram — Guest Journey

```mermaid
stateDiagram-v2
    [*] --> Landing: scan shared QR code
    Landing --> Joining: enter group size + phone number
    Joining --> Waiting: join accepted (idempotent)
    Joining --> Landing: validation error (retry)

    Waiting --> Waiting: position updates (re-render on change)
    Waiting --> ReadyCodeShown: allocation service reserves a\nconfiguration (status: ready)
    Waiting --> Left: guest leaves voluntarily
    Waiting --> NoShow: staff marks no-show

    ReadyCodeShown --> Seated: staff enters code, confirms\nthe existing reservation
    ReadyCodeShown --> Left: guest leaves while ready
    ReadyCodeShown --> NoShow: staff marks no-show, OR\n5-min timeout (DEC-015, lazy-evaluated)

    Left --> [*]
    NoShow --> [*]
    Seated --> [*]

    Landing --> Waiting: reopen page with active-visit token\n(recovers existing entry, REQ-GUEST-004)
    Landing --> ReadyCodeShown: reopen page while ready\n(same token, recovers the code)
```

Notes:
- "Reopen page" only resumes a *non-terminal* (`Waiting`/`ReadyCodeShown`) entry — a terminal entry (`Left`/`NoShow`/`Seated`) does not behave as an active session again (DEC-006).
- `ReadyCodeShown` **is** a persisted `QueueEntry` status (`ready`) — revised from an earlier version of this diagram, which described it as UI-only. The allocation decision (which table(s), the `seating_code`) is made and reserved the moment the entry enters this state, *before* staff act — see `03-architecture/domain-model.md` for the authoritative state machine and `05-specifications/domain-model-proposal.md` §0 for why.
- The `ReadyCodeShown → NoShow` edge has two triggers that land on the identical outcome: staff manually marking no-show, or DEC-015's 5-minute lazy-evaluated expiration firing on the next operation that touches this entry. The guest-facing result is the same either way — no distinct "expired" state is shown.
