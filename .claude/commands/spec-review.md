---
description: Review current specifications and/or an implementation plan against documents/01-05 before starting implementation
---

Review the specification and/or implementation plan for the task at hand, using the same responsibilities as the `spec-reviewer` agent (`.claude/agents/spec-reviewer.md`):

1. Identify which requirement IDs (`REQ-*`) from `documents/01-requirements/` this task is meant to cover, and confirm `documents/01-requirements/traceability.md` agrees.
2. Read the governing specification in `documents/05-specifications/` and the relevant part of `documents/03-architecture/domain-model.md`.
3. Check for: contradictions with an approved decision (`documents/02-product-decisions/decision-log.md`) or invariant; missing acceptance criteria; unnecessary complexity beyond what the spec calls for; and anything that would implement a `documents/07-future-evolution/` item.
4. If $ARGUMENTS is provided, scope the review to that specific area (e.g., `/spec-review allocation`, `/spec-review release`); otherwise review the task currently being planned or worked on in this conversation.

Report using the spec-reviewer output format:

```
Requirements checked:
Potential issues:
Missing cases:
Recommended changes:
Approval status:
```

If you find a contradiction or a missing product decision, do not resolve it — report it as `BLOCKED — HUMAN DECISION REQUIRED` per `CLAUDE.md`.
