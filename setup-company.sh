#!/usr/bin/env bash
# setup-company.sh — Run the "60-second setup" from a clone of this repo.
#
# Usage:
#   1. cp .env.example .env
#   2. edit .env with your MULTICA_WORKSPACE_ID and friends
#   3. bash setup-company.sh            # create agents + squads + skills + autopilot
#   4. bash setup-company.sh --dry-run  # preview without writes
#
# Idempotent: re-running is safe. Agents/squads already existing are skipped.

set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  esac
done

# run <command...> — runs the command; in --dry-run mode prints the command (verbose) and produces empty stdout.
# If output is captured (e.g. $(run ... | jq)), the empty stdout is what jq sees, returning null.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] $*" >&2
  else
    "$@"
  fi
}

# ─── Load .env ────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "❌ .env not found. Run: cp .env.example .env  then fill it in." >&2
  exit 1
fi
# Use a temp shell so `*` in cron expressions don't glob-expand.
set -a
while IFS='=' read -r key val; do
  case "$key" in
    '' | '#'*)
      continue
      ;;
  esac
  val="${val%\"}"; val="${val#\"}"
  val="${val%\'}"; val="${val#\'}"
  export "$key=$val"
done < .env
set +a

echo "═══ Portable Company Kit — setup-company.sh ═══"
echo "Workspace : ${MULTICA_WORKSPACE_ID:-<unset>}"
echo "Runtime    : ${OPENCLAW_RUNTIME_ID:-default}"
echo "Departments: ${DEPARTMENTS:-Growth,Sales,Product,Success}"
echo "Standup    : ${STANDUP_CRON:-'0 9 * * *'} ${STANDUP_TZ:-UTC}"
echo

# ─── Preflight ───────────────────────────────────────────────────────────
for cmd in multica jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "❌ missing: $cmd — run install.sh first" >&2; exit 1; }
done
[[ -n "${MULTICA_WORKSPACE_ID:-}" ]] || { echo "❌ MULTICA_WORKSPACE_ID not set" >&2; exit 1; }
[[ -n "${MULTICA_TOKEN:-}" ]] || { echo "❌ MULTICA_TOKEN not set (run 'multica login')" >&2; exit 1; }

# ─── 1. Create CEO + 4 (or N) leads ──────────────────────────────────────
echo "═══ Step 1: create CEO + department leads ═══"
CEO_PROMPT="$(cat prompts/ceo.md)"

CEO_ID=$(run multica agent create \
  --name "CEO" \
  --runtime "${OPENCLAW_RUNTIME_ID}" \
  --description "Orchestrator. Delegates and reviews only." \
  --instructions "$CEO_PROMPT" \
  --output json 2>/dev/null | jq -r '.id // empty') || CEO_ID=""
echo "  CEO: ${CEO_ID:-<exists, skipping>}"

IFS=',' read -ra DEPT_LIST <<< "${DEPARTMENTS:-Growth,Sales,Product,Success}"
declare -A LEAD_ID

for DEPT in "${DEPT_LIST[@]}"; do
  # Department name in singular form ("Growth") -> "growth-lead.md"
  SHORT=$(echo "$DEPT" | tr '[:upper:]' '[:lower:]')
  PROMPT_FILE="prompts/${SHORT}-lead.md"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "  ⚠️  no prompt file at $PROMPT_FILE — skipping ${DEPT} Lead"
    continue
  fi
  INSTRUCTIONS="$(cat "$PROMPT_FILE")"
  ID=$(run multica agent create \
    --name "${DEPT} Lead" \
    --runtime "${OPENCLAW_RUNTIME_ID}" \
    --description "${DEPT} department lead." \
    --instructions "$INSTRUCTIONS" \
    --output json 2>/dev/null | jq -r '.id // empty') || ID=""
  LEAD_ID[$DEPT]="${ID:-<exists>}"
  echo "  ${DEPT} Lead: ${LEAD_ID[$DEPT]}"
done

# ─── 2. Create squads ────────────────────────────────────────────────────
echo
echo "═══ Step 2: create squads (1 per dept) ═══"
declare -A SQUAD_ID

for DEPT in "${DEPT_LIST[@]}"; do
  ID=$(run multica squad create \
    --name "${DEPT} Squad" \
    --output json 2>/dev/null | jq -r '.id // empty') || ID=""
  SQUAD_ID[$DEPT]="${ID:-<exists>}"
  echo "  ${DEPT} Squad: ${SQUAD_ID[$DEPT]}"
done

# ─── 3. Bind the brand-voice skill ───────────────────────────────────────
echo
echo "═══ Step 3: bind brand-voice skill ═══"
SKILL_FILE="skills/bluewave-brand-voice.md"
if [[ -f "$SKILL_FILE" ]]; then
  SKILL_ID=$(run multica skill create \
    --name "bluewave-brand-voice" \
    --description "Voice rule pack for ${COMPANY_NAME:-this company} — auto-load when bound." \
    --content-file "$SKILL_FILE" \
    --output json 2>/dev/null | jq -r '.id // empty') || SKILL_ID=""

  if [[ -n "$SKILL_ID" ]]; then
    echo "  Skill: $SKILL_ID"
    # Bind to every writer (Growth Lead + Sales Lead) — not the CEO.
    for DEPT in Growth Sales; do
      LEAD="${LEAD_ID[$DEPT]:-}"
      if [[ -n "$LEAD" && "$LEAD" != "<exists>" ]]; then
        run multica agent skills add "$LEAD" --skill-ids "$SKILL_ID"
      fi
    done
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "  Skill: <exists, listing skipped in --dry-run mode>"
    else
      echo "  Skill already exists, listing…"
      SKILL_ID=$(multica skill list --output json | jq -r '.[] | select(.name=="bluewave-brand-voice").id')
      echo "  Found: $SKILL_ID"
      for DEPT in Growth Sales; do
        LEAD="${LEAD_ID[$DEPT]:-}"
        if [[ -n "$LEAD" && "$LEAD" != "<exists>" ]]; then
          run multica agent skills add "$LEAD" --skill-ids "$SKILL_ID"
        fi
      done
    fi
  fi
else
  echo "  ⚠️  no skills/bluewave-brand-voice.md — skipping skill setup"
fi

# ─── 4. Register daily CEO standup autopilot ──────────────────────────────
echo
echo "═══ Step 4: register daily CEO standup autopilot ═══"
AP_ID=$(run multica autopilot create \
  --title "Daily CEO standup: scan inbox + propose 3 actions" \
  --description "Standup task for the CEO. Read assigned in-progress issues, draft a 3-bullet status (In Progress / Blocked / Next), and post a summary. If nothing pending, post a one-liner 'no action needed'." \
  --agent "${CEO_ID:-<ceo-id>}" \
  --mode run_only \
  --output json 2>/dev/null | jq -r '.id // empty') || AP_ID=""
echo "  Autopilot: ${AP_ID:-<exists>}"

if [[ -n "$AP_ID" ]]; then
  run multica autopilot trigger-add "$AP_ID" \
    --kind schedule \
    --cron "${STANDUP_CRON:-0 9 * * *}" \
    --timezone "${STANDUP_TZ:-UTC}" \
    --label "Daily standup"
fi

# ─── 5. Done ──────────────────────────────────────────────────────────────
echo
echo "═══ Setup complete ═══"
echo "Next:"
echo "  • make verify   # confirm everything is wired"
echo "  • make demo     # create a test issue + watch it route"
echo "  • make sync     # push to AgentPulse (if configured)"
