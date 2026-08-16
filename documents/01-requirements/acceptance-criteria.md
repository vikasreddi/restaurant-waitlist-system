# Acceptance Criteria

Acceptance criteria per requirement, phrased as Given/When/Then. These are behavioral specifications for the implementation phase and the test-suite (`05-specifications/test-strategy.md`), not implementation instructions.

## Guest

**REQ-GUEST-001 — Join**
- Given a guest opens the shared QR link, when they submit a valid group size and phone number, then a new queue entry is created and the guest is shown their position and an active-visit token.
- Given the same submission is retried (network retry, double-click), when it reaches the backend more than once, then only one queue entry exists (see REQ-IMP-003).

**REQ-GUEST-002 — View position**
- Given an active queue entry, when the guest views the page, then the current computed position is shown, not a stale or promised-exact number (REQ-QUEUE-004).

**REQ-GUEST-003 — Leave**
- Given an active (non-terminal) queue entry, when the guest chooses to leave, then the entry transitions to a terminal "left" state and no longer counts toward position calculations for others.

**REQ-GUEST-004 — Recover active visit**
- Given a guest has an active queue entry and closes the tab, when they reopen the page (same device/browser) via the stored active-visit token, then they see the same entry's current state, not a new join form.
- Given the entry has reached a terminal state (seated, left, no-show), when the guest reopens the page, then it does not behave as an active waitlist session (see `06-guest-identity`).

**REQ-GUEST-005 — Seating code**
- Given the allocation service selects a queue entry for a newly-available configuration (entry transitions `waiting → ready`), when the guest views the page, then a seating code is shown that staff can use to confirm that specific group's already-reserved table(s).

**REQ-GUEST-006 — No persistence between visits**
- Given a guest's entry reaches a terminal state, when they scan the QR code again on a new visit, then no prior visit data is surfaced to them and a new entry/token is required to join again.

**REQ-GUEST-007 / REQ-FE-006 — Double-join protection**
- Given a guest has already joined, when "Join" is clicked again (double-click or resubmission of the same in-flight request), then no second queue entry is created, and the guest is shown their existing position rather than an error or a duplicate join.

## Staff

**REQ-STAFF-001 — Login**
- Given valid staff credentials, when submitted, then the staff screen becomes accessible; given invalid credentials, then access is denied with an error state.

**REQ-STAFF-002 / 003 — Queue and table visibility**
- Given the staff screen is open, when the underlying queue or table state changes, then the displayed queue and table states reflect current backend state (exact refresh mechanism is a P1 concern, not required to be live for P0).

**REQ-STAFF-004 — Seat by code**
- Given a valid **`ready`** group's seating code — meaning its table(s) were already atomically reserved by the allocation service — when staff submit the code, then the reservation is confirmed and the entry transitions to "seated." Staff confirming does not itself choose or allocate tables; that decision was already made.
- Given an invalid, already-used, non-existent, or not-yet-`ready` code, when submitted, then the operation is rejected with a clear error and no state changes.
- Given a valid `ready` code whose reservation expired (DEC-015, 5-minute timeout) before staff submitted it, when submitted, then the operation is rejected with a distinct "reservation expired" outcome — the entry is `no_show`, not silently re-queued and not incorrectly seated.

**REQ-STAFF-005 — Release**
- Given a seated group's table(s), when staff mark them released, then the table(s) return to available (and, if combined, the combination dissolves per REQ-TABLE-008).
- Given the group's table set included a combination, when released, then both tables become independently available, not just one.

**REQ-STAFF-006 — No-show**
- Given a waiting (non-terminal) queue entry, when staff mark it as no-show, then it transitions to a distinct terminal "no-show" state and is excluded from position calculations for others.
- Given an entry already in a terminal state, when staff attempt to mark it no-show again, then the operation is a safe no-op or a clear rejection, not a state corruption.

## Tables / Combined Allocation

**REQ-TABLE-002/003 — Exclusivity**
- Given a table is occupied, when any allocation attempt targets it, then the attempt is rejected until the table is released.

**REQ-TABLE-006/007/008 — Atomic combination**
- Given a group needs two adjacent tables and both are free at the moment of allocation, when staff seat the group, then both tables are atomically marked occupied as one unit.
- Given only one of the two required tables is free, when an allocation is attempted, then it fails cleanly and neither table is touched.
- Given a combined group leaves, when staff release, then both tables become independently available.

## Queue / Position / Starvation

**REQ-QUEUE-001/002 — Non-FIFO position**
- Given a small group and an earlier-arriving large group both waiting, when a single small-capacity table frees, then the small group may be seated first if the large group's required configuration is not simultaneously available (see `seating-allocation-policy.md`).

**REQ-QUEUE-003 — No starvation**
- Given a large group has been waiting past the configured maximum-wait threshold, when its complete required configuration (e.g., both adjacent tables) becomes simultaneously available, then that group receives priority for that configuration over newly-eligible smaller groups (see `starvation-policy.md` for the exact rule and its cost).

## Infrastructure

**REQ-INFRA-001/002 — Persistence and migrations**
- Given the application is restarted, when it comes back up, then all queue and table state from before the restart is intact.
- Given a schema change is needed, when applied, then it is expressed as a versioned migration, not a manual/undocumented change.

**REQ-INFRA-004 — Runnable**
- Given a clean checkout, when `docker compose up` is run per the README, then both frontend and backend become reachable without additional manual setup beyond documented steps.

## Optional (P1)

**REQ-SHOW-001 — Live updates**
- Given a guest's position changes due to another group's activity, when using the chosen mechanism (polling/SSE/WebSocket), then the guest's displayed position updates without a manual page refresh, within the chosen mechanism's latency bound.

**REQ-SHOW-002 — Cache + invalidation**
- Given the guest read path is cached, when any state-changing event occurs (join, seat, release, no-show, leave, combination formed/dissolved), then subsequently-read positions reflect the new state, not a stale cached value.

**REQ-SHOW-003 — Async notification**
- Given a group is seated (or reaches ready-to-be-seated, per the chosen design), when the synchronous request completes, then the "table ready" notification is dispatched via a background job rather than blocking the request.
