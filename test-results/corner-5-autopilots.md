# Corner 5 — Autopilots

**Goal:** Verify `multica autopilot create` + schedule trigger runs the assigned agent on a cron, in `run_only` mode.

## Setup

```bash
multica autopilot create \
  --title "Daily CEO standup: scan inbox + propose 3 actions" \
  --description "Standup task for the CEO. Read any unread comments on assigned issues, draft a 3-bullet status (In Progress / Blocked / Next), and post it as a comment on any issues that need attention. If nothing is pending, post a one-liner 'no action needed' comment on the latest in_progress issue." \
  --agent ea7c88c6-dd93-4af4-8c4e-cb660ba07053 \
  --mode run_only

multica autopilot trigger-add <autopilot-id> \
  --kind schedule --cron "0 9 * * *" \
  --timezone "Africa/Nairobi" \
  --label "Daily standup 09:00 Nairobi"
```

**Autopilot UUID:** `5fbf383f-526a-4082-9c5f-a75e7c13b98b`
**Next scheduled fire:** 2026-08-05 06:00:00Z (= 09:00 Nairobi)

## Manual trigger test

```bash
multica autopilot trigger 5fbf383f-526a-4082-9c5f-a75e7c13b98b
```

**Result:** ✅

Two runs fired back-to-back:

| Run ID | Started | Completed | Status |
|---|---|---|---|
| `4b616aa1-e718-4dc1-b84d-cf87b4210220` | 11:33:30Z | 11:35:26Z | completed |
| `03f398b1-a17a-4e82-aae6-2a070501318f` | 11:34:25Z | 11:36:33Z | completed |

Both produced a clean "no actions needed" standup summary. The CEO correctly identified:
- Assigned issues: MYA-3, MYA-6 → both `done`.
- Global `in_progress` issues: none.

## What `run_only` means

- No issue is created. No comment posted (unless the autopilot description says to).
- The agent runs with the autopilot's `description` as its prompt.
- Result is captured as `multica autopilot runs <id>` output (visible in the web UI or via `--output json`).

## When to use this vs `create_issue`

| Mode | Use case |
|---|---|
| `run_only` | Recurring chores: standups, weekly summaries, scans. No ticket. |
| `create_issue` | Recurring tickets: weekly invoice, daily check-in. Each trigger makes a fresh issue. |

## Gotchas

- `--timezone IANA` is required for cron schedule triggers. Default is UTC.
- `--issue-title-template` only interpolates `{{date}}`. Anything else is rejected.
- Use `multica autopilot trigger <id>` to fire immediately instead of waiting for the cron.
