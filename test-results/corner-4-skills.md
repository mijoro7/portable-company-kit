# Corner 4 — Skills (the gotcha & the fix)

**Goal:** Verify workspace skills can be bound to agents and produce skill-driven output.

## Round 1 (MYA-10) — workspace-skill NOT bound

**Test:** Created workspace skill `bluewave-brand-voice` (UUID `70968b5d-...`). Wrote an issue that *spelled out the brand-voice rules* in its description.

**Output:** Agent produced brand-voice-correct copy. CEO approved. Marked `done`.

**But:** The agent honored the *brief*, not the *skill*. Confirmed by:
- `ls workdir/skills/` showed only 8 runtime-bundled `multica-*` skills.
- Daemon prep-stage log: `skills:0ms@4ms` (0ms because nothing to consider).
- Agent prompt's `## Skills` block listed only the 8 bundled, not `bluewave-brand-voice`.

**Lesson:** workspace skills are **NOT auto-injected**. They're a knowledge base — agents only see them if explicitly bound.

## Round 2 (MYA-11) — workspace skill BOUND via `multica agent skills add`

**Setup:**
```bash
multica agent skills add 3c39591a-... --skill-ids 70968b5d-...
multica agent skills add c35ffda7-... --skill-ids 70968b5d-...
```

**Test:** Wrote an issue with a **vague** brief ("Customer-facing outbound copy only. No further guidance — the agent should rely on its bound skill.").

**Output:** Agent produced a perfect cold-DM script with all brand-voice rules applied (sensory-first, coastal metaphor, no banned phrases, required tagline). CEO closed with: *"The script looks great—evocative, brand-aligned, and perfectly targeted."* Status `done`.

**Confirmation:** Agent prompt's `## Skills` block now lists `bluewave-brand-voice` alongside the 8 bundled ones:
```
- **bluewave-brand-voice**
- **multica-autopilots**
- **multica-creating-agents**
- ... (8 total)
```

## The pattern

1. `multica skill create` → make the knowledge.
2. `multica agent skills add <agent> --skill-ids <uuid>` → bind it.
3. Briefs stay generic (don't paste rules into every brief).

## Misleading UX in Multica

The skill `description` field can say "Auto-load when X" — that's wrong. The skill is loaded iff bound. **Don't trust that field's wording.**
