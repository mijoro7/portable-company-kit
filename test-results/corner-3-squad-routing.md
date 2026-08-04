# Corner 3 — Squad routing

**Goal:** Verify assigning an issue to a Squad (not an individual agent) routes to the squad's leader.

**Test issue:** MYA-9 "TEST3 (squad routing): Growth Squad — write 3 subject-line variants..."

**Run:**
```bash
multica issue create --title "..." --assignee "Growth Squad" --status todo --priority medium
```

**Result:** ✅

- Daemon resolved "Growth Squad" → its only member (Growth Lead, UUID `3c39591a-...`).
- Lead posted 3 subject-line variants via comment, @mentioned CEO.
- CEO closed: "The subject lines provided by the Growth Lead are excellent and cover the key psychological angles needed for this outreach."

**Key lesson:** `--assignee "<Squad Name>"` works. Squad-to-member resolution is automatic. No need to know member UUIDs to route to a squad.
