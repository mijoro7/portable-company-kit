# Portable Company Kit — Makefile
#
# Run `make help` for a list of commands. All targets are designed to be run
# from the repo root after `bash install.sh` and `make setup`.
#
# Conventions:
#   - silent / dry modes print `[dry-run]` instead of writing anywhere
#   - all targets compose: `make install setup demo sync` is the canonical quickstart

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

# Pick up .env if it exists (for make setup / make demo / make sync).
# `include` doesn't work — Make parses `.env` and chokes on shell-style `=` lines.
# `set -a` from a shell source would work, but Make can't source. So extract keys
# with sed and hand them to Make as `export KEY := …` lines. (-d'\n' on xargs
# keeps them separate.)
ifneq (,$(wildcard ./.env))
ENV_KEYS := $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env | xargs -d '\n')
$(foreach k,$(ENV_KEYS),$(eval export $(k) := $$(shell sed -n 's/^$(k)=//p' .env)))
endif

.PHONY: help install setup verify demo sync clean lint version

help:  ## show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version:  ## print kit version
	@echo "Portable Company Kit v0.1 — 2026-08-04"

install:  ## provision a fresh VPS with multica + openclaw + systemd unit
	bash install.sh

install-dry:  ## preview the install (no writes)
	bash install.sh --dry-run

setup:  ## create the 5 agents + 4 squads + skill + autopilot (requires .env)
	bash setup-company.sh

setup-dry:  ## preview the setup without writing
	bash setup-company.sh --dry-run

verify:  ## confirm multica + openclaw + daemon are wired
	@echo "==> multica"
	@command -v multica >/dev/null && multica --version || echo "  ✗ multica not on PATH"
	@echo "==> openclaw"
	@command -v openclaw >/dev/null && openclaw --version || echo "  ✗ openclaw not on PATH"
	@echo "==> multica daemon"
	@systemctl --user is-active multica-daemon 2>&1 | head -1
	@echo "==> .env"
	@if [[ -f .env ]]; then echo "  ✓ present"; else echo "  ✗ missing — cp .env.example .env"; fi
	@echo "==> workspace"
	@if [[ -n "$${MULTICA_WORKSPACE_ID:-}" ]]; then echo "  ✓ $$MULTICA_WORKSPACE_ID"; else echo "  ✗ MULTICA_WORKSPACE_ID not set"; fi

demo:  ## create a test issue, watch it route, post a comment, sync to AgentPulse
	@bash -c 'set -e; \
	  ISSUE_ID=$$(multica issue create \
	    --title "DEMO-$$(date +%s): write a tagline for $$COMPANY_NAME" \
	    --description "Open this and watch the lead pick it up." \
	    --assignee "Growth Lead" \
	    --status todo \
	    --priority medium \
	    --output json | jq -r .id); \
	  echo "Created issue $$ISSUE_ID — now waiting for lead to deliver..."; \
	  sleep 30; \
	  multica issue comment list $$ISSUE_ID --roots-only --summary'

sync:  ## push the workspace's issues to AgentPulse (one-way)
	@if [[ -z "$$RECTIFY_GATEWAY_TOKEN" ]]; then \
	  echo "⚠️  RECTIFY_GATEWAY_TOKEN not set in .env. Sync script will skip."; \
	else \
	  python3 dist/sync-multica-to-agentpulse.py --limit 50; \
	fi

sync-dry:  ## preview the AgentPulse sync (no writes)
	python3 dist/sync-multica-to-agentpulse.py --limit 50 --dry-run

lint:  ## syntax-check the kit's bash + python
	bash -n install.sh
	bash -n setup-company.sh
	python3 -m py_compile dist/sync-multica-to-agentpulse.py
	@echo "✓ all scripts parse"

clean:  ## remove generated artifacts (does not touch multica state)
	rm -f .env
	rm -rf workdir/
	@echo "✓ cleaned local artifacts (multica state untouched)"
