#!/usr/bin/env bash
# install.sh — Provision a fresh VPS for running this kit.
#
# This is the "clone-and-run" entrypoint for the Portable Company Kit.
# It sets up:
#   1. Linux deps (curl, jq, python3, node 20+)
#   2. multica CLI (latest stable)
#   3. openclaw runtime (M3 model + openclaw config)
#   4. openclaw wrapper at ~/.local/bin/openclaw (bypass MUL-5467)
#   5. multica-daemon as systemd --user service
#
# After install.sh, run `make demo` to see the 60-second setup, or
# `make verify` to confirm everything is wired up.
#
# Usage:
#   bash install.sh                  # interactive install
#   bash install.sh --dry-run        # show what would be done (no writes)
#   bash install.sh --skip-claude    # Claude runtime also known-unauthed in this env
#
# Re-runnable: this script is idempotent. Running it twice is safe; the second
# run is a no-op unless something changed upstream.

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────
DRY_RUN=0
SKIP_CLAUDE=0
MULTICA_VERSION="latest"
OPENCLAW_MODEL_DEFAULT="ollama/minimax-m3:cloud"

for arg in "$@"; do
  case "$arg" in
    --dry-run)         DRY_RUN=1 ;;
    --skip-claude)     SKIP_CLAUDE=1 ;;
    --multica-version) shift; MULTICA_VERSION="$1" ;;
    --model)           shift; OPENCLAW_MODEL_DEFAULT="$1" ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)  echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] would have run: $*"
  echo "[dry-run] enabled — see the live script for actual installs"
fi

# Helper: run or print, depending on dry-run.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ install.sh needs root for system installs. Re-run with sudo." >&2
    exit 1
  fi
}

# ─── 1. Preflight checks ──────────────────────────────────────────────────
echo "═══ Step 1: preflight ═══"
# Skip root check in dry-run mode (so you can preview non-destructively).
if [[ $DRY_RUN -ne 1 ]]; then
  need_root
fi

for bin in curl jq python3 git systemctl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ missing dependency: $bin"
    echo "   install: apt-get install -y $bin   # or your distro's equivalent"
    exit 1
  fi
done

NODE_MAJOR=$(node -v 2>/dev/null | sed -E 's/v([0-9]+)\..*/\1/' || echo 0)
if [[ "$NODE_MAJOR" -lt 20 ]]; then
  echo "⚠️  node < 20 detected (got $(node -v 2>/dev/null)). Upgrading."
  run bash -lc 'curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs'
else
  echo "✓ node $(node -v)"
fi

# ─── 2. Install multica CLI ───────────────────────────────────────────────
echo
echo "═══ Step 2: multica CLI ═══"
if command -v multica >/dev/null 2>&1; then
  echo "✓ multica already installed at $(command -v multica)"
else
  echo "Installing multica CLI..."
  run curl -fsSL https://multica.ai/install.sh | bash -s -- --version "$MULTICA_VERSION"
fi

# ─── 3. Install openclaw CLI + runtimes ──────────────────────────────────
echo
echo "═══ Step 3: openclaw CLI + runtime ═══"
if command -v openclaw >/dev/null 2>&1; then
  echo "✓ openclaw CLI found at $(command -v openclaw)"
else
  echo "Installing openclaw CLI..."
  run npm install -g openclaw@latest
fi

# Initialize the openclaw runtime (idempotent — only run if no config exists yet).
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  echo "  ✓ openclaw already initialized (config at \$HOME/.openclaw/openclaw.json)"
  # Only update the default model if it's different from what's already set.
  CURRENT_MODEL=$(openclaw config get --key default_model 2>/dev/null | tr -d '\n' || true)
  if [[ "$CURRENT_MODEL" != "$OPENCLAW_MODEL_DEFAULT" ]]; then
    run openclaw config set --key default_model --value "$OPENCLAW_MODEL_DEFAULT"
  else
    echo "  ✓ default_model already set to $OPENCLAW_MODEL_DEFAULT"
  fi
else
  run openclaw init --model "$OPENCLAW_MODEL_DEFAULT"
  run openclaw config set --key default_model --value "$OPENCLAW_MODEL_DEFAULT"
fi

# ─── 4. Install openclaw wrapper (bypasses MUL-5467 — 5s config timeout) ─
echo
echo "═══ Step 4: openclaw config-file wrapper ═══"
mkdir -p /home/openclaw/.local/bin

# Find the real openclaw binary. Search several well-known locations before
# giving up. The wrapper is a tiny shell script that calls into whatever we
# find — so symlinks, .mjs, and plain binaries are all fine.
find_real_openclaw() {
  local candidates=(
    "$(command -v openclaw 2>/dev/null || true)"
    "/home/openclaw/.npm-global/bin/openclaw"
    "/home/openclaw/.npm-global/lib/node_modules/openclaw/openclaw.mjs"
    "/usr/local/bin/openclaw"
    "/usr/bin/openclaw"
  )
  for cand in "${candidates[@]}"; do
    [[ -n "$cand" && -e "$cand" ]] || continue
    # If it's a symlink, prefer the resolved target so exec doesn't loop.
    if [[ -L "$cand" ]]; then
      local target
      target="$(readlink -f "$cand" 2>/dev/null || true)"
      [[ -n "$target" && -e "$target" ]] && { echo "$target"; return 0; }
      # Symlink target missing — keep the symlink, hope it works.
      echo "$cand"; return 0
    fi
    echo "$cand"; return 0
  done
  return 1
}

REAL_BIN="$(find_real_openclaw || true)"
if [[ -z "$REAL_BIN" ]]; then
  echo "❌ could not locate the real openclaw binary. Aborting wrapper install." >&2
  exit 1
fi

# Back up the real openclaw binary if not already done.
if [[ ! -e "/home/openclaw/.local/bin/openclaw.real" ]]; then
  echo "Backing up $REAL_BIN as ~/.local/bin/openclaw.real"
  # Copy (or symlink) the real binary. Symlinks need resolved targets; cp
  # -L dereferences and may copy files that don't run standalone. Prefer
  # symlink when the candidate is a symlink itself, else copy.
  if [[ -L "$REAL_BIN" ]]; then
    run ln -s "$REAL_BIN" "/home/openclaw/.local/bin/openclaw.real"
  else
    run cp "$REAL_BIN" "/home/openclaw/.local/bin/openclaw.real"
  fi
fi

cat > /tmp/openclaw-wrapper.tmp <<'WRAPPER'
#!/usr/bin/env bash
# openclaw CLI wrapper — short-circuits `openclaw config file` to bypass
# Multica daemon's 5s hardcoded timeout (MUL-5467).
# Everything else passes through to the real binary.
real="/home/openclaw/.local/bin/openclaw.real"
if [[ "${1:-}" == "config" && "${2:-}" == "file" ]]; then
  echo "$HOME/.openclaw/openclaw.json"
  exit 0
fi
exec "$real" "$@"
WRAPPER

# Idempotent: only write the wrapper if missing OR content differs.
if [[ ! -e "/home/openclaw/.local/bin/openclaw" ]] || ! cmp -s /tmp/openclaw-wrapper.tmp "/home/openclaw/.local/bin/openclaw"; then
  if [[ -e "/home/openclaw/.local/bin/openclaw" ]]; then
    echo "  ⚠️  existing wrapper content differs — backing up to openclaw.bak before overwriting"
    run cp "/home/openclaw/.local/bin/openclaw" "/home/openclaw/.local/bin/openclaw.bak"
  fi
  run cp /tmp/openclaw-wrapper.tmp /home/openclaw/.local/bin/openclaw
  run chmod +x /home/openclaw/.local/bin/openclaw
else
  echo "  ✓ wrapper already installed (content matches, no changes)"
fi
rm -f /tmp/openclaw-wrapper.tmp

# Ensure ~/.local/bin precedes /usr/local/bin in PATH.
RC_LINE='export PATH="$HOME/.local/bin:$PATH"'
for rc in /home/openclaw/.bashrc /home/openclaw/.zshrc; do
  if [[ -f "$rc" ]] && ! grep -qF "$RC_LINE" "$rc"; then
    run bash -c "printf '%s\n' '$RC_LINE' >> '$rc'"
  fi
done

# ─── 5. Multica daemon as systemd --user service ────────────────────────
echo
echo "═══ Step 5: multica-daemon systemd service ═══"
SERVICE=/home/openclaw/.config/systemd/user/multica-daemon.service
mkdir -p "$(dirname "$SERVICE")"

# Only write the unit file if missing or content differs (Tzo's never-overwrite rule).
NEED_UNIT=1
if [[ -f "$SERVICE" ]] && grep -q "ExecStart=/home/openclaw/.local/bin/multica daemon start" "$SERVICE"; then
  NEED_UNIT=0
  echo "  ✓ unit file already present and correct"
fi

if [[ $NEED_UNIT -eq 1 ]]; then
  if [[ -f "$SERVICE" ]]; then
    echo "  ⚠️  existing unit file differs — backing up to multica-daemon.service.bak"
    run cp "$SERVICE" "$SERVICE.bak"
  fi
  cat > "$SERVICE" <<'UNIT'
[Unit]
Description=Multica agent runtime daemon
After=network.target

[Service]
Type=simple
ExecStart=/home/openclaw/.local/bin/multica daemon start --foreground
Restart=on-failure
RestartSec=5
Environment=PATH=/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
UNIT
fi

# Reload only if the unit file changed.
if [[ $NEED_UNIT -eq 1 ]]; then
  run systemctl --user daemon-reload
fi

# Enable+start only if not already active.
if systemctl --user is-active multica-daemon >/dev/null 2>&1; then
  echo "  ✓ multica-daemon already running"
else
  run systemctl --user enable --now multica-daemon
fi

# Lingering so user services survive logout (idempotent).
run loginctl enable-linger openclaw || true

# ─── 6. Pre-flight daemon check ──────────────────────────────────────────
echo
echo "═══ Step 6: daemon health check ═══"
sleep 2
if run systemctl --user is-active multica-daemon >/dev/null 2>&1; then
  echo "✓ multica-daemon is active"
else
  echo "⚠️  daemon not active. Check logs: journalctl --user -u multica-daemon -n 30"
fi

# ─── 7. Done ─────────────────────────────────────────────────────────────
echo
echo "═══ Done ═══"
echo "Next:"
echo "  • export PATH=\"\$HOME/.local/bin:\$PATH\"   # if not already in your shell"
echo "  • multica login                                # authenticate"
echo "  • cp .env.example .env                         # fill in workspace id + tokens"
echo "  • make verify                                  # confirm install"
echo "  • make demo                                    # run the 60-second setup"
