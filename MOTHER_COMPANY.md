# MOTHER COMPANY — A Portable Company Kit for Multica

> **Status:** DRAFT (in progress). Last updated: 2026-08-04.
> **Purpose:** A reusable recipe for spinning up an autonomous AI-run business on Multica — a known-good org chart, prompt patterns, real CLI commands, and the gotchas we've already paid for. Anyone (human or AI agent) should be able to clone this, change a few variables, and be running a 5-agent company end-to-end inside an hour.
> **Naming:** "Mother Company" is the family name; the kit itself is also called "Portable Company" or "AI Business-in-a-Box". Pick one for the public name later.

---

## 0. What this kit gives you

- **5 agents** on a shared workspace: 1 CEO + 4 department leads (Growth, Sales, Product, Success). CEO is an orchestrator, **not** a doer.
- **4 squads** (one per department). Each squad has exactly one member (the dept lead). Squads exist so a future hire slots in without renaming people.
- **Stable skill binding** per agent (workspace skill → agent assignment) so voice/rulepacks auto-load every run.
- **Autopilots** for daily/weekly rituals (standups, follow-ups, dashboards) that have NO associated issue — pure run_only.
- **One-way Multica → AgentPulse board sync** via `dist/sync-multica-to-agentpulse.py`. Re-runnable; de-dupes by title; moves existing tasks if their Multica status changes.
- **Audit trail** on every issue via threaded comments. One issue = one ticket, with multiple comment threads if needed. Sub-issues only for genuine parallel tracks.
- **A reviewer loop**: only the CEO marks `done`. Leads mark `in_review` and @-mention CEO.

## 1. Prerequisites

| What | Why | Notes |
|---|---|---|
| Multica workspace | Holds the company | 1 workspace per company. NOT 1 per agent. |
| OpenClaw runtime | Executes agents | Use UUID, not name (two CEOs may exist if you also have Claude runtime). |
| A Linux box with `multica` CLI | You (the human) drive setup | The `multica` binary ships with the daemon. |
| `~/.local/bin/openclaw` wrapper | Bypass MUL-5467 (5s `openclaw config file` hardcoded timeout) | See Gotcha G3. |
| systemd --user service `multica-daemon` | Survive session restarts | See Gotcha G4. |

## 2. Org chart (the one we use)

```
                        CEO  (orchestrator-only)
                          │
        ┌─────────────────┼─────────────────┐
   Growth Lead       Sales Lead       Product Lead      Success Lead
   (outbound,        (pipeline,        (specs,             (onboarding,
    content)         demos, quotes)   experiments)        retention)
```

Hard rules from the test company:
- CEO does not do departmental work — only delegate, review, close.
- Each lead does NOT do work outside their department. If a Growth task asks for sales copy the lead marks it `blocked` and comments with the right squad.
- The "single ticket, threaded comments" rule: leads do not invent sub-issues. Comments carry the audit trail.
- Reviewer pattern: leads flip to `in_review` only; CEO flips to `done`.

## 3. Variables you change

When cloning this kit to a new company, edit:

| Variable | Default | Where |
|---|---|---|
| Workspace name | `my_admin` | `multica workspace create` |
| Workspace UUID | (assigned) | Put into the agent update commands |
| Company name ("Acme Corp") | `Bluewave Coffee Co.` | Skill: `bluewave-brand-voice` content |
| Brand voice rules | (custom) | Skill: `bluewave-brand-voice` |
| Standup cron time | `0 9 * * * Africa/Nairobi` | Autopilot trigger |
| Department set | Growth/Sales/Product/Success | CEO agent identity prompt |
| Timezone | per founder | Autopilot trigger |

## 4. The 60-second setup

```bash
# 0. prerequisites
export MULTICA_WORKSPACE_ID=<ws-uuid>
export MULTICA_TOKEN=<token>

# 1. create the CEO + 4 department leads
multica agent create --name "CEO" --runtime <runtime-id> --description "..." \
  --instructions-file ./prompts/ceo.md

for DEPT in growth sales product success; do
  multica agent create --name "$(titlecase $DEPT) Lead" --runtime <runtime-id> \
    --instructions-file ./prompts/$DEPT-lead.md
done

# 2. create squads (one per dept)
for DEPT in growth sales product success; do
  multica squad create --name "$(titlecase $DEPT) Squad"
  # then add the matching lead as the only member, role=lead
done

# 3. bind the brand-voice skill (or any skill) to the writers
multica skill create --name <name> --description "..." --content-file ./skills/<name>.md
SKILL_ID=$(multica skill list --output json | jq -r '.[] | select(.name=="<name>").id')
multica agent skills add <growth-lead-uuid> --skill-ids $SKILL_ID
multica agent skills add <sales-lead-uuid>   --skill-ids $SKILL_ID
# (don't bind to CEO — CEO doesn't write customer copy)

# 4. autopilots (the 24/7 layer)
multica autopilot create --title "Daily CEO standup" \
  --description "<the standup prompt>" --agent <ceo-uuid> --mode run_only
multica autopilot trigger-add <autopilot-id> --kind schedule \
  --cron "0 9 * * *" --timezone "Africa/Nairobi"
```

Total operations: ~12. Time: <5 min after the prompts exist.

## 5. Canonical prompts (the actual files)

Each prompt lives at `./prompts/<role>.md` in this repo. See:
- `prompts/ceo.md`
- `prompts/growth-lead.md`
- `prompts/sales-lead.md`
- `prompts/product-lead.md`
- `prompts/success-lead.md`

These are what `multica agent create --instructions-file` consumes. **Do not** paste the prompt into `--instructions` inline — long strings break shell parsing. Use a file.

## 6. Skill binding pattern (the key gotcha!)

If you skip this, your workspace skill is invisible to agents.

```bash
# 1. Create
multica skill create --name <name> --description "..." --content-file ./skills/<name>.md
# returns skill UUID

# 2. Bind to each agent that needs it
multica agent skills add <agent-uuid> --skill-ids <skill-uuid>

# Verify
multica agent skills list <agent-uuid>
```

**Without step 2**, the skill exists in the workspace DB but never appears in any agent's `## Skills` block in the system prompt.

## 7. Issue workflow (the one true way)

```
HUMAN                                  CEO                          LEAD
─────                                  ───                          ────
creates issue, --assignee CEO          (assigned) wakes up
                                       reads brief
                                       posts comment with
                                       [@Lead](mention://agent/<uuid>)
                                       and the specific sub-task
                                                                       (re-triggered)
                                                                       reads trigger comment
                                                                       does the work
                                                                       flips in_review
                                                                       posts deliverable comment
                                       (re-triggered by mention)
                                       reviews deliverable
                                       flips done
                                       posts 1-line closing
```

The audit trail lives in the comment thread on the **same issue**. Do not create sub-issues to look organized.

## 8. Autopilot modes (run_only vs create_issue)

| Mode | What it does | When to use |
|---|---|---|
| `run_only` | Runs the agent with a fixed description. No issue. Pure agent run; result captured as autopilot run output. | Recurring chores: standups, weekly summaries, scans. |
| `create_issue` | Creates a fresh issue (with `--issue-title-template`) on each trigger, assigning it. | Recurring tickets: "weekly invoice", "daily check-in". |

Cron supports standard 5-field expressions + `--timezone IANA`. The first run is at the next matching minute boundary, not immediately. To test a cron-scheduled autopilot without waiting, use `multica autopilot trigger <id>`.

## 9. Known gotchas (paid for in blood)

### G1. Multica `--assignee` is positional in some commands, named in others
- `multica issue create` → `--assignee "<Name>"` or `--assignee-id <uuid>` (named)
- `multica issue update --assignee` does NOT stick — reassignments must use `multica issue assign`. **Always use `multica issue assign <id> --to <name>` for reassignments.**

### G2. Mention wakeup is the ONLY ambient-to-agent handoff
Mention syntax: `[@Name](mention://agent/<uuid>)` on its own line.
- No mention → no agent-to-agent handoff. Plain comment does not re-enqueue.
- Sub-issue completion does NOT wake the parent. Use stages + `@mention` if you need a handoff.

### G3. `openclaw config file` hardcoded 5s timeout (MUL-5467)
The Multica daemon shells out to `openclaw config file` to discover the OpenClaw config path. It has a 5-second hardcoded timeout. On a slow node, this fails. **Workaround:** install a wrapper at `~/.local/bin/openclaw` that echoes the config path and exits in 2ms. Original goes to `~/.local/bin/openclaw.real`. Path lookup order must put `~/.local/bin` first.

### G4. Daemon stops when session cleans up
Run the daemon as `systemd --user` service:
```ini
[Unit]
Description=Multica agent runtime daemon
[Service]
Type=simple
ExecStart=/home/openclaw/.local/bin/multica daemon start --foreground
Restart=on-failure
RestartSec=5
[Install]
WantedBy=default.target
```
Then `systemctl --user enable --now multica-daemon`. Survives logout.

### G5. Long instruction strings break `--instructions`
Always `--instructions-file <path>`, never `--instructions "<long string>"`. The agent update command-line silently truncates or escapes badly.

### G6. `multica skill get <name>` fails
The skill CLI uses UUIDs. `multica skill get bluewave-brand-voice` returns "invalid skill id". `multica skill list` returns the UUID; use it.

### G7. CEO output_bytes is usually 0
The daemon deletes `./reply.md` at the end of a run (cleanup rule). When the CEO is the reviewer, that's fine — the deliverable lands in the issue comment, not the reply file. Cosmetic warning `Exec failed: remove ./reply.md` in daemon log; ignore.

### G8. Agent prompt bootstrap can take 30s+
First run with full workspace context can take 25–35s for `bundle-tools` stage. Subsequent runs are faster. Don't kill runs <2min — they're working.

### G9. Workspace skills are NOT auto-injected
The 8 `multica-*` skills are always there. Custom workspace skills require `multica agent skills add`. Don't trust the description field's "auto-load when X" wording.

### G10. Autopilot runs return to the autopilot itself, not to an issue
`run_only` mode produces no issue and no comment. The result is captured as `autopilot runs <id>` output, viewable via the Multica web UI or `multica autopilot runs <id> --output json`. Use this for pure observability/automation tasks.

### G11. `--timezone IANA` is required for schedule triggers (cron)
Default cron expression is UTC. If your business runs on Nairobi time, pass `--timezone "Africa/Nairobi"` or the standup fires at the wrong wall-clock hour.

### G12. AgentPulse sync is not built-in
Multica and AgentPulse are separate products with separate APIs. There is no native two-way sync. We wrote `dist/sync-multica-to-agentpulse.py` for one-way (Multica → AgentPulse) board parity. Run it on demand or schedule via cron / Multica autopilot.

**Key gotchas in the sync script:**
- AgentPulse invoke API wraps replies as `{"tool":..., "ok":..., "result":...}` — unwrap the `result` key.
- Tasks are de-duped by exact title match. Move uses `columnId`, not column name.
- Status mapping: `todo/backlog → Backlog`, `in_progress/in_review/blocked → In Progress`, `done/cancelled → Done`.

## 10. What this kit does NOT yet cover

- **Project management hierarchy** (projects-and-resources skill): tested lightly, not part of the standard company.
- **Cross-workspace portability**: this kit assumes 1 workspace per company. Multi-workspace consolidation not tested.
- **Bidirectional AgentPulse sync**: corner #6 still pending (planned).
- **Claude runtime**: not authenticated in our environment; OpenClaw-only. If you have Claude auth, agents can also live there with the same prompts.
- **Multi-member squads**: squads with >1 member work but weren't tested for routing (lead picks first available, no round-robin observed).

## 11. Open issue tracker

Things we want to fix before calling this kit "1.0":
- [ ] CEO prompt needs cleaner split between (a) "fresh root assigned to me" mode and (b) "re-triggered via @mention as reviewer" mode. Currently single-flow mode; the dual mode is implicit via Trigger context.
- [ ] Autopilot test for `create_issue` mode (we only tested `run_only`).
- [ ] Round-robin squad member assignment (if a squad has 2+ leads).
- [ ] File Multica feedback item about misleading "Auto-load when X" wording on the skill description field.
- [ ] Two-way AgentPulse sync (currently one-way, Multica → AgentPulse).
- [ ] Promote the master guide from `.md` to a Feishu doc (Tzo's preference for shipping docs).

---

## 12. What's verified end-to-end

| Test | Issue | Round-trip |
|---|---|---|
| Delegation loop (single issue + @mention) | MYA-8 | CEO → Growth Lead → CEO review → `done` ✅ |
| Comments & blockers (deliverable + reviewer on same issue) | MYA-8 | Comment thread `b0b68428` ✅ |
| Squad routing (assign to squad name) | MYA-9 | "Growth Squad" → Growth Lead ✅ |
| Skill binding (workspace skill `bluewave-brand-voice` → Growth Lead + Sales Lead) | MYA-11 | Agent prompt `## Skills` block includes skill; brand-voice copy produced from skill rules (not brief) ✅ |
| Autopilot (`run_only` + cron 09:00 Nairobi) | n/a | Manual trigger + scheduled trigger both ran CEO standup ✅ |
| AgentPulse sync (one-way Multica → AgentPulse) | n/a | 9 issues synced to AgentPulse board; MYA-4 status flip → task moved Backlog → In Progress ✅ |

---

## 13. Naming the kit (open question)

Candidates so far:
- **Mother Company** (current working name, Tzo's origin).
- **Portable Company Kit** (descriptive, low marketing energy).
- **AI Business-in-a-Box** (searchable, more aspirational, captures the "give me everything to run a business in one tarball" feel).
- **Self-Running Company** (closer to OpenAI's "self-running" framing, less anthropomorphic).

Pick one before sharing the repo publicly.
