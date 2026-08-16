# FUTURE — Production Evolution (NOT IMPLEMENTED)

**Status: future evolution only. Nothing in this document is built in the two-day scope.** Consolidates the smaller real-world-messiness items the brief explicitly calls out as ours to choose, which this project deliberately does not attempt to build now (`02-product-decisions/scope-and-tradeoffs.md`).

## Groups that grow or shrink at the door

Real groups sometimes change size after joining (someone arrives late, someone leaves). Not handled in P0 — a joined group's size is treated as fixed for the duration of its wait. A future version could let a guest or staff member update group size, which would require re-running compatibility (`05-specifications/allocation-spec.md` §1) for that entry without disrupting others already mid-allocation.

## Guests who wander off without telling anyone

Not handled beyond the existing no-show mechanism, which requires an explicit staff action. A future version could add an idle/abandonment timeout that auto-flags a long-unresponsive active-visit token, distinct from staff-initiated no-show — this is tracked as `OPEN-007` in `02-product-decisions/decision-log.md` and intentionally left unresolved rather than defaulted.

## Staff overrides

P0 staff actions are limited to seat / release / no-show, matching the brief exactly. A future version could add: manual queue reordering, forced un-seat / undo, manual table-state correction (e.g., staff marks a table dirty/out-of-service), and editable seed data via a management UI (explicitly excluded even from the brief's own scope: "there is no screen to manage it").

## Multi-staff concurrent UI

The brief assumes one staff UI user; a future version supporting multiple simultaneous staff users would need UI-level conflict handling (e.g., "this group was just seated by someone else") layered on top of the backend concurrency safety that already exists for P0 (`03-architecture/domain-model.md`).

## Real notification delivery

P1 (if reached) builds the async job *mechanism* only (REQ-SHOW-003). Real SMS/push delivery integration, delivery-status tracking, and guest opt-out handling are future production concerns, not attempted here.

## Scaling beyond a single restaurant

The current design assumes one restaurant's ~40 tables. A future multi-location product would need tenant isolation across the entire data model, which is out of scope and not hinted at anywhere in the brief.
