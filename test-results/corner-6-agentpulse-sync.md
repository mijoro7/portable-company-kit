# Corner 6 — AgentPulse sync

**Goal:** Verify Multica → AgentPulse one-way board sync.

## What was built

`dist/sync-multica-to-agentpulse.py` — idempotent pull-and-apply script. Reads Multica issues + AgentPulse columns, creates missing tasks, moves out-of-place tasks.

## Status mapping

| Multica status | → AgentPulse column |
|---|---|
| `todo`, `backlog` | Backlog |
| `in_progress`, `in_review`, `blocked` | In Progress |
| `done`, `cancelled` | Done |

## Dedup

By exact title match. Re-running the script is safe and only changes tasks that need moving.

## Round-trip test (2026-08-04)

1. Initial sync (`--limit 5`) — created MYA-7..11 in AgentPulse `Done` column (1m 0s).
2. Full sync (`--limit 10`) — dedup skipped the 5 already-there, created MYA-3/5/6 in `Done` and MYA-4 in `Backlog` (0m 30s).
3. Flipped MYA-4 in Multica: `todo → in_progress`.
4. Re-sync: `MYA-4 → MOVED to In Progress` ✅ (0m 5s).
5. Cleanup: flipped MYA-4 back to `todo`.

## Why this exists

No native Multica↔AgentPulse bridge. The script fills the gap for board-parity testing and the eventual "human-facing dashboard" use case.

## Future work

- Two-way sync (AgentPulse task completion → Multica issue `done`).
- Bidirectional metadata for sync IDs (so edits flow both ways).
- Wrap as a `multica autopilot` (schedule it every N minutes).
