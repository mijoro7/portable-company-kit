# Corner 2 — Comments & blockers

**Goal:** Verify comment-thread audit trail on a single issue (deliverable + reviewer on same issue).

**Test issue:** MYA-8 (same as Corner 1, reused).

**Result:** ✅

- Comment thread `b0b68428-8b95-46d7-abdc-30ac1e77607a` (root) — Growth Lead delivered.
- Comment thread `3aa06436-...` (child) — CEO reviewed and closed.

**Key lesson:** Multica comment threading supports parent/child. Use a parent_id to keep the audit trail on one issue, no extra issues needed.
