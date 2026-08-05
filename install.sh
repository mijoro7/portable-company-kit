#!/usr/bin/env bash
# install.sh — Provision a fresh VPS for running this kit.
#
# Usage:
#   bash install.sh                  # install Multica + detect runtimes
#   bash install.sh --runtime openclaw    # install with OpenClaw runtime
#   bash install.sh --runtime claude      # install with Claude Code runtime
#   bash install.sh --runtime ollama      # install with Ollama runtime
#   bash install.sh --skip-runtime        # install only Multica, no runtime
#   bash install.sh --dry-run             # preview without changes
#
# This script is idempotent. Running it twice is safe.

set -euo pipefail

DRY_RUN=0
RUNTIME="${RUNTIME:-auto}"  # auto, openclaw, claude, ollama, skip

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --runtime) shift; RUNTIME="${1:-auto}" ;;
    --skip-runtime) RUNTIME="skip" ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

need_root() {
  [[ $EUID -eq 0 ]] || { echo "This script requires root. Re-run with sudo."; exit 1; }
}

# ─── 1. Preflight checks ──────────────────────────────────────────────────
echo "═══ Step 1: preflight ═══"
[[ $DRY_RUN -eq 1 ]] || need_root

for bin in curl jq python3 git systemctl; do
  command -v "$bin" &>/dev/null || {
    echo "❌ missing: $bin"
    echo "   install: apt-get install -y $bin   # or your distro's equivalent"
    exit 1
  }
done
echo "✓ all dependencies present"

# ─── 2. Install multica CLI ───────────────────────────────────────────────
echo
echo "═══ Step 2: multica CLI ═══"
if command -v multica &>/dev/null; then
  echo "✓ multica already installed at $(command -v multica)"
else
  echo "Installing multica CLI..."
  run curl -fsSL https://multica.ai/install.sh | bash
fi

# ─── 3. Install runtime (optional) ────────────────────────────────────────
echo
echo "═══ Step 3: runtime installation ═══"

if [[ "$RUNTIME" == "skip" ]]; then
  echo "Skipping runtime installation (--skip-runtime flag)"
  echo "You can register a runtime later with: multica runtime register <type>"
else
  # Auto-detect or install specified runtime
  case "$RUNTIME" in
    auto)
      # Check what's already installed
      if command -v openclaw &>/dev/null; then
        RUNTIME="openclaw"
        echo "✓ Detected OpenClaw runtime"
      elif command -v claude &>/dev/null; then
        RUNTIME="claude"
        echo "✓ Detected Claude Code runtime"
      elif command -v ollama &>/dev/null; then
        RUNTIME="ollama"
        echo "✓ Detected Ollama runtime"
      else
        echo "No runtime detected. Installing OpenClaw as default..."
        RUNTIME="openclaw"
      fi
      ;;
    openclaw)
      if command -v openclaw &>/dev/null; then
        echo "✓ OpenClaw already installed"
      else
        echo "Installing OpenClaw runtime..."
        run curl -fsSL https://openclaw.com/install.sh | bash
        echo "✓ OpenClaw installed"
      fi
      ;;
    claude)
      if command -v claude &>/dev/null; then
        echo "✓ Claude Code already installed"
      else
        echo "⚠️  Claude Code requires manual installation"
        echo "   Visit: https://claude.ai/download"
        echo "   After installation, register with: multica runtime register claude"
      fi
      ;;
    ollama)
      if command -v ollama &>/dev/null; then
        echo "✓ Ollama already installed"
      else
        echo "Installing Ollama runtime..."
        run curl -fsSL https://ollama.ai/install.sh | sh
        echo "✓ Ollama installed"
      fi
      ;;
    *)
      echo "Unknown runtime: $RUNTIME"
      echo "Valid options: auto, openclaw, claude, ollama, skip"
      exit 1
      ;;
  esac

  # Register the runtime with Multica
  echo
  echo "Registering runtime with Multica..."
  case "$RUNTIME" in
    openclaw)
      if ! run multica runtime list | grep -q "openclaw"; then
        run multica runtime register openclaw \
          --name "OpenClaw" \
          --command "openclaw runtime start --port {{PORT}}"
        echo "✓ OpenClaw runtime registered"
      else
        echo "✓ OpenClaw runtime already registered"
      fi
      ;;
    claude)
      if ! run multica runtime list | grep -q "claude"; then
        run multica runtime register claude \
          --name "Claude Code" \
          --command "claude --daemon --port {{PORT}}"
        echo "✓ Claude runtime registered"
      else
        echo "✓ Claude runtime already registered"
      fi
      ;;
    ollama)
      if ! run multica runtime list | grep -q "ollama"; then
        run multica runtime register ollama \
          --name "Ollama" \
          --command "ollama serve --port {{PORT}}"
        echo "✓ Ollama runtime registered"
      else
        echo "✓ Ollama runtime already registered"
      fi
      ;;
  esac
fi

# ─── 4. Multica daemon as systemd --user service ────────────────────────
echo
echo "═══ Step 4: multica-daemon systemd service ═══"
SERVICE=/etc/systemd/system/multica-daemon.service

if [[ -f "$SERVICE" ]]; then
  echo "✓ systemd service already installed"
else
  echo "Installing multica-daemon service..."
  run tee "$SERVICE" > /dev/null <<UNIT
[Unit]
Description=Multica Agent Daemon
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/multica daemon start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  run systemctl daemon-reload
  run systemctl enable --now multica-daemon
  echo "✓ multica-daemon service installed and started"
fi

# ─── 5. Done ──────────────────────────────────────────────────────────────
echo
echo "═══ Installation complete ═══"
echo
echo "Next steps:"
echo "  1. cd portable-company-kit"
echo "  2. cp .env.example .env"
echo "  3. Edit .env with your settings:"
echo "     - MULTICA_WORKSPACE_ID (required)"
echo "     - RUNTIME (optional: auto/openclaw/claude/ollama/skip)"
echo "  4. bash setup-company.sh"
echo
if [[ "$RUNTIME" == "skip" ]]; then
  echo "Remember to register a runtime before running setup-company.sh:"
  echo "  multica runtime register <type>"
fi
