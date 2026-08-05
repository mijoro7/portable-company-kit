# Changelog

All notable changes to the Portable Company Kit.

## [v0.2.0] - 2026-08-05

### Added
- **Chief-of-Staff agent**: New standing agent responsible for recruiting specialists from the upstream pool
- **Runtime-agnostic installation**: Kit now supports multiple runtimes (OpenClaw, Claude Code, Ollama) with auto-detection
- **Upstream specialist pool integration**: Access to 258+ specialist personas from msitarzewski/agency-agents

### Changed
- **Prompts upgraded**: Replaced placeholder department lead prompts with rich upstream personas:
  - Growth Lead: marketing-growth-hacker (200+ lines vs 53 lines)
  - Sales Lead: sales-outbound-strategist (469 lines vs 40 lines)
  - Product Lead: product-manager (460 lines vs 50 lines)
  - Success Lead: customer-success-manager (460 lines vs 45 lines)
- **setup-company.sh**: Completely rewritten to be runtime-agnostic
  - Auto-detects available runtimes (OpenClaw/Claude/Ollama)
  - Creates Chief-of-Staff agent
  - Uses `--instructions-file` instead of inline instructions
- **install.sh**: Completely rewritten for flexibility
  - `--runtime <type>` flag to specify runtime
  - `--skip-runtime` flag to install only Multica
  - Auto-detection when no runtime specified
  - Runtime registration happens automatically
- **.env.example**: Updated to use `RUNTIME` instead of `OPENCLAW_RUNTIME_ID`
- **Architecture**: 5 agents → 6 agents (CEO, Chief-of-Staff, 4 department leads)

### Architecture
```
CEO (orchestrator)
├── Chief-of-Staff (agent recruiter + auditor)
├── Growth Lead (marketing-growth-hacker persona)
├── Sales Lead (sales-outbound-strategist persona)
├── Product Lead (product-manager persona)
└── Success Lead (customer-success-manager persona)

Specialist Pool (258+ personas):
- Used on-demand by Chief-of-Staff when standing roles don't match
- 18 divisions: engineering, design, marketing, sales, product, etc.
- No bundling needed - spawn per-issue, archive after delivery
```

### Migration from v0.1
If you have a v0.1 deployment:
1. Pull latest changes
2. Update your prompts: `cp prompts/* <your-deployment>/prompts/`
3. Run setup-company.sh again - it's idempotent and will:
   - Create Chief-of-Staff agent
   - Update department lead prompts with richer personas
   - Preserve existing agents, squads, skills

## [v0.1.0] - 2026-08-04

### Initial Release
- 5-agent organization: CEO + 4 department leads
- Basic prompts for each role
- OpenClaw-only runtime support
- Multica + OpenClaw integration
- systemd daemon setup
- 6-corner verification complete
- AgentPulse one-way sync

### Verified Features
- Delegation loop (CEO → Lead → CEO review)
- Comment threads as audit trail
- Squad routing (assign to squad name)
- Skill binding (workspace skills to agents)
- Autopilot modes (run_only, create_issue)
- AgentPulse board sync
