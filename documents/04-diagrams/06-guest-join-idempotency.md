# Diagram — Guest Join Idempotency

```mermaid
sequenceDiagram
    participant G as Guest browser
    participant API as Backend API
    participant DB as Database

    G->>G: Generate idempotency_key = UUID-A for this join attempt
    G->>API: POST join (group_size, phone_number, idempotency_key=UUID-A)
    Note over G,API: Network fails / times out before response
    G->>API: Retry — POST join (idempotency_key=UUID-A, same key reused)
    API->>DB: BEGIN TRANSACTION
    API->>DB: INSERT idempotency_records (unique on idempotency_key)

    alt key not seen before
        DB-->>API: insert succeeded
        API->>DB: INSERT queue_entries (status=waiting)
        API->>DB: COMMIT
        API-->>G: 201 Created — position + active-visit token
    else key already exists (retry / double-click / bad signal resend)
        DB-->>API: unique constraint conflict
        API->>DB: ROLLBACK insert attempt
        API->>DB: SELECT existing queue_entry for this key
        API-->>G: 200 OK — same position + same active-visit token\n(no second entry created)
    end
```

Notes:
- The unique constraint on `idempotency_key` (`03-architecture/data-model.md`) is the enforcement point — this is a database guarantee, not a frontend-only debounce (guards against the AI-agent risk of "idempotency implemented only in the frontend," Phase 1 analysis §20).
- Phone number is never the idempotency key (DEC-007) — two different guests could share a phone number, and one guest could legitimately submit two genuinely different requests.
- A double-click that fires two near-simultaneous requests with the *same* key resolves the same way: one wins the insert, the other observes the conflict and returns the existing entry.
- A genuinely new join attempt (a different visit, not a retry) generates a new key (e.g., UUID-B) — the idempotency key identifies *this specific join attempt*, not the guest or their phone number.
