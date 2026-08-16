---
description: Map the current implementation against requirement IDs and update the traceability table
---

Using the `requirement-traceability` skill:

1. Read `documents/01-requirements/traceability.md` and `documents/01-requirements/functional-requirements.md`.
2. If $ARGUMENTS is provided, scope to that requirement ID or area (e.g., `/requirements-check REQ-TABLE-006`, `/requirements-check staff`); otherwise check all P0 requirements.
3. For each in-scope requirement, check whether the codebase actually implements it (find the relevant file/module) and whether a test covers it, updating the Implementation and Test columns in `traceability.md` accordingly.
4. Flag any requirement that is still `—`/`—` if the surrounding work suggests it should already be done — that's a real gap, not a formatting nit.
5. Flag anything implemented in the codebase that does *not* map to any requirement ID — possible scope creep, worth a note even if not necessarily wrong.

Report a short summary: how many P0 requirements are fully traced (implementation + test), how many are partially traced, and how many are untouched. Do not implement anything to close gaps you find — that's a separate task for `backend-domain-agent` or `test-engineering-agent`, scoped and reviewed on its own.
