# Changelog

All notable changes to this kit. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Pending
- Public name decision (Mother Company / Portable Company Kit / AI Business-in-a-Box / Self-Running Company).
- Tagged `v0.1` GitHub release.
- File Multica feedback items: MUL-5467 follow-up, "auto-load when X" misleading wording.

## [0.1.0] — 2026-08-04

### Added
- `install.sh` — VPS provisioning (multica + openclaw + wrapper + systemd unit). Idempotent + `--dry-run` mode.
- `setup-company.sh` — the 60-second setup recipe, as a runnable script. Honours `.env`. Idempotent + `--dry-run`.
- `Makefile` — kit-level commands: `install`, `setup`, `setup-dry`, `verify`, `demo`, `sync`, `sync-dry`, `lint`, `clean`, `version`, `help`.
- `.env.example` — variables for workspace id, runtime id, model, standup cron+timezone, brand, departments, AgentPulse project + token, notification chat id. **Cron expression must stay quoted.**
- `CHANGELOG.md` — this file.
- `MOTHER_COMPANY.md` — master guide (12 sections, 258 lines, 12 gotchas).
- `README.md` — entrypoint with clone-and-run instructions.
- `LICENSE` — MIT.
- `.gitignore` — excludes env, tokens, logs, multica daemon workdirs.
- `prompts/` — canonical per-role prompts (CEO + Growth/Sales/Product/Success leads).
- `skills/bluewave-brand-voice.md` — example workspace skill recipe.
- `dist/sync-multica-to-agentpulse.py` — one-way Multica → AgentPulse sync (idempotent, title-dedup).
- `test-results/corner-{1..6}.md` — receipts per test corner (delegation / comments / squad-routing / skills / autopilots / AgentPulse sync).

### Verified end-to-end on the `my_admin` test company
- ✅ Corner 1: single-issue delegation loop (MYA-8)
- ✅ Corner 2: threaded comment audit trail (MYA-8)
- ✅ Corner 3: squad routing (MYA-9)
- ✅ Corner 4: workspace skill binding, brand-voice copy (MYA-11)
- ✅ Corner 5: autopilot `run_only` + cron 09:00 Africa/Nairobi
- ✅ Corner 6: AgentPulse round-trip sync (9 issues; MYA-4 status flip → column move)

### Known limitations (carrying into 0.2.0)
- Boss mode (full review/close loop with sub-issues) untested at >1 lead per squad.
- Round-robin squad member routing — only first-available member is picked; no fairness.
- Two-way AgentPulse sync — only one-way works today.
- `create_issue` autopilot mode not yet exercised (only `run_only`).
- Claude-runtime agents unverified (runtime not authed in this env).
- Repo has no `v0.1` tag yet on GitHub (Composio publishing uploads files but doesn't push refs).

### Provenance
- Aug 2 baseline: `COMPANY_OS.md` + `TOOLING_MATRIX.md` + `dna/` — original org-chart/dna drafts by Tzo.
- Aug 4: v0.1 kit assembled, live-tested, shipped.

[Unreleased]: https://github.com/mijoro7/portable-company-kit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mijoro7/portable-company-kit/releases/tag/v0.1.0
