# Portable Company Kit

Turn Multica into a fully autonomous AI-run business. This kit provisions a 6-agent organization with runtime-agnostic support (OpenClaw, Claude Code, Ollama) and access to 258+ specialist personas.

## Architecture

```
CEO (orchestrator)
├── Chief-of-Staff (agent recruiter + auditor)
├── Growth Lead (marketing-growth-hacker persona)
├── Sales Lead (sales-outbound-strategist persona)
├── Product Lead (product-manager persona)
└── Success Lead (customer-success-manager persona)

Specialist Pool (258+ personas)
└── 18 divisions: engineering, design, marketing, sales, product, etc.
```

The Chief-of-Staff recruits specialists from the upstream pool when standing roles don't match a brief. See [mother-company/docs/upstream-pool.md](https://github.com/mijoro7/mother-company/blob/main/docs/upstream-pool.md) for the full catalog.

## Quick Start

### 1. Install

```bash
bash install.sh
```

The installer auto-detects your runtime (OpenClaw/Claude/Ollama) or you can specify:

```bash
bash install.sh --runtime openclaw   # explicit
bash install.sh --runtime claude     # Claude Code
bash install.sh --runtime ollama     # Ollama
bash install.sh --skip-runtime       # only Multica
```

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env`:
```bash
MULTICA_WORKSPACE_ID=your-workspace-uuid
RUNTIME=auto  # or: openclaw, claude, ollama
```

### 3. Setup

```bash
bash setup-company.sh
```

Creates 6 agents, 4 squads, binds brand-voice skill, registers daily standup autopilot.

### 4. Test

```bash
bash demo.sh
```

Creates a test issue, watches it route through the delegation loop, verifies the audit trail.

## What You Get

- **6 standing agents**: CEO, Chief-of-Staff, Growth Lead, Sales Lead, Product Lead, Success Lead
- **4 squads**: Growth Squad, Sales Squad, Product Squad, Success Squad (each with 1 agent)
- **Brand-voice skill**: Bound to Growth Lead and Sales Lead (not CEO)
- **Daily standup autopilot**: CEO runs every day at 09:00 Africa/Nairobi
- **Rich upstream personas**: Department leads use battle-tested prompts (200-469 lines each)
- **Specialist pool access**: 258+ personas across 18 divisions, recruited on-demand by Chief-of-Staff

## Runtime Support

The kit is **runtime-agnostic**. During installation:

- **Auto-detection**: If you don't specify `--runtime`, the installer checks for OpenClaw, Claude, and Ollama in that order. First match wins.
- **Explicit**: Use `--runtime <type>` to force a specific runtime.
- **Skip**: Use `--skip-runtime` to install only Multica (for manual runtime setup later).

At setup time, `setup-company.sh` auto-detects the registered runtime and configures all agents accordingly.

## Files

```
portable-company-kit/
├── install.sh           # Provision Multica + runtime (runtime-agnostic)
├── setup-company.sh     # Create agents, squads, skills, autopilot
├── demo.sh              # Test the delegation loop
├── .env.example         # Configuration template
├── prompts/             # Agent prompts
│   ├── ceo.md
│   ├── chief-of-staff.md
│   ├── growth-lead.md
│   ├── sales-lead.md
│   ├── product-lead.md
│   └── success-lead.md
└── skills/
    └── bluewave-brand-voice.md
```

## Companion Repo

This kit installs and configures. The **playbook** (org chart design, agent recruiting workflow, specialist pool reference) lives in [mother-company](https://github.com/mijoro7/mother-company).

## Migration from v0.1

If you have a v0.1 deployment:

1. Pull latest changes: `git pull`
2. Update prompts: `cp prompts/* <your-deployment>/prompts/`
3. Run `bash setup-company.sh` again (idempotent)
   - Creates Chief-of-Staff agent
   - Updates department lead prompts with richer personas
   - Preserves existing agents, squads, skills

## Status

**v0.2.0** - Runtime-agnostic, 6-agent architecture, upstream specialist pool integration.

## License

MIT
