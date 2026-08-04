# Portable Company Kit

> A reusable recipe for spawning an autonomous AI-run business on [Multica](https://multica.ai) — a known-good org chart, prompt patterns, real CLI commands, and the gotchas we've paid for. **Clone → install → setup → run.** A 5-agent company, end-to-end, in under 5 minutes.

**Status:** v0.1 (2026-08-04). Six corners verified end-to-end on the test company `my_admin`.

## 🚀 Quickstart

```bash
git clone https://github.com/mijoro7/portable-company-kit.git
cd portable-company-kit
bash install.sh                 # provisions multica + openclaw + systemd unit
cp .env.example .env            # fill in MULTICA_WORKSPACE_ID, MULTICA_TOKEN
make setup                     # creates the 5 agents, 4 squads, 1 skill, 1 autopilot
make verify                    # confirms everything is wired
make demo                      # creates a real issue, watches it route
make sync                      # (optional) syncs your board to AgentPulse
```

That's it. You now have a CEO + 4 department leads (Growth/Sales/Product/Success) plus a brand-voice skill bound to the writer leads and a daily 09:00 CEO standup autopilot.

**Total operations:** ~12. **Total time:** ~5 min on a fresh Ubuntu VPS with sudo.

## What you get

- **5-agent org** in one workspace: 1 CEO + 4 department leads.
- **4 squads** (one per department) so a future hire slots in without renaming people.
- **Stable skill binding** per agent via `multica agent skills add`.
- **Autopilots** for daily/weekly rituals (standups, follow-ups, dashboards).
- **One-way board sync** to AgentPulse via `dist/sync-multica-to-agentpulse.py`. Re-runnable; de-dupes by title; moves existing tasks if their Multica status changes.
- **Reviewer loop**: leads mark `in_review`, CEO marks `done`.
- **Audit trail on every issue** via threaded comments.

## Read next

- **[MOTHER_COMPANY.md](./MOTHER_COMPANY.md)** — the master guide. 12 sections covering: org chart, variables, canonical prompts, skill binding pattern, issue workflow, autopilot modes, **12 known gotchas (G1–G12)**, what's not covered, open issues, verified test matrix, naming.
- **[CHANGELOG.md](./CHANGELOG.md)** — versioned state of the kit.
- **[test-results/](./test-results/)** — receipts per corner (what was tested, what passed).

## Start here

Read **[MOTHER_COMPANY.md](./MOTHER_COMPANY.md)** — that's the master guide. It covers:

1. Prerequisites
2. Org chart
3. Variables you change per company
4. 60-second setup recipe
5. Canonical prompts (in `prompts/`)
6. Skill binding pattern
7. Issue workflow
8. Autopilot modes (`run_only` vs `create_issue`)
9. **12 known gotchas** (G1–G12)
10. Open issues + naming

## Repo layout

```
company-engine/
├── README.md                              ← you are here
├── MOTHER_COMPANY.md                       ← the master guide
├── COMPANY_OS.md                           ← original org chart (Aug 2 baseline)
├── TOOLING_MATRIX.md                       ← original tooling map (Aug 2 baseline)
├── dna/                                    ← per-role prompt DNA (Aug 2 baseline)
│   ├── core/bootloader.md
│   ├── core/ceo.md
│   ├── growth/head-of-growth.md
│   └── sops/{first-loop,lead-gen-workflow,onboarding-flow}.md
├── prompts/                                ← canonical per-role prompts (from MOTHER_COMPANY §5)
│   ├── ceo.md
│   ├── growth-lead.md
│   ├── sales-lead.md
│   ├── product-lead.md
│   └── success-lead.md
├── skills/                                 ← workspace-skill recipes
│   └── bluewave-brand-voice.md             ← voice rule example
├── dist/                                   ← shippable CLI helpers
│   └── sync-multica-to-agentpulse.py       ← one-way board sync (idempotent)
└── test-results/                           ← corner-by-corner receipts
    ├── corner-1-delegation.md
    ├── corner-2-comments.md
    ├── corner-3-squad-routing.md
    ├── corner-4-skills.md
    ├── corner-5-autopilots.md
    └── corner-6-agentpulse-sync.md
```

## Prerequisites

| What | Why |
|---|---|
| A Multica workspace | Holds the company |
| OpenClaw runtime | Executes agents. (Claude runtime also works but not authed in our env.) |
| A Linux box with `multica` CLI | You drive setup from your laptop. |
| `~/.local/bin/openclaw` wrapper | See gotcha G3 — bypasses Multica's 5s `openclaw config file` timeout. |
| `multica-daemon` as `systemd --user` service | See gotcha G4 — survives session restarts. |

## 60-second setup

```bash
export MULTICA_WORKSPACE_ID=<ws-uuid>

# 1. CEO + 4 leads
multica agent create --name "CEO" --runtime <runtime-id> --instructions-file ./prompts/ceo.md
for DEPT in growth sales product success; do
  multica agent create --name "$(titlecase $DEPT) Lead" --runtime <runtime-id> \
    --instructions-file ./prompts/$DEPT-lead.md
done

# 2. Squads (one per dept, single member each)
for DEPT in growth sales product success; do
  multica squad create --name "$(titlecase $DEPT) Squad"
done

# 3. Bind brand-voice (or any) skill
multica skill create --name <name> --content-file ./skills/<name>.md
SKILL_ID=$(multica skill list --output json | jq -r '.[] | select(.name=="<name>").id')
multica agent skills add <growth-lead-uuid> --skill-ids $SKILL_ID
multica agent skills add <sales-lead-uuid>   --skill-ids $SKILL_ID

# 4. Autopilot for daily standup
multica autopilot create --title "Daily CEO standup" \
  --description "<standup prompt>" --agent <ceo-uuid> --mode run_only
multica autopilot trigger-add <autopilot-id> --kind schedule \
  --cron "0 9 * * *" --timezone "Africa/Nairobi"

# 5. (optional) sync to AgentPulse for cross-tool visibility
python3 dist/sync-multica-to-agentpulse.py --limit 50
```

After ~5 min you'll have a working company. See **[MOTHER_COMPANY.md](./MOTHER_COMPANY.md)** for the full version, including the 12 gotchas.

## Naming convention

- Issues: `MYA-<N>` (auto-incremented; one number for the issue's whole lifetime)
- Agents: `CEO`, `Growth Lead`, `Sales Lead`, `Product Lead`, `Success Lead`
- Squads: `Growth Squad`, etc.
- Skills: `kebab-case-name` (e.g. `bluewave-brand-voice`)

## Provenance

- **Aug 2, 2026** — initial commit; `COMPANY_OS.md` + `TOOLING_MATRIX.md` + `dna/` drafts.
- **Aug 4, 2026** — v0.1: live-tested all 6 corners of Multica (delegation, comments, squad routing, skills, autopilots, AgentPulse sync). Master guide added.
- The companion repo `autonomous-company-engine` holds the original baseline; this repo is the live-tested, shippable version.

## License

MIT. Use it, fork it, swap the brand voice, run a coffee company.
