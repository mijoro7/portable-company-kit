#!/usr/bin/env python3
"""
push-v0.1.py — push the kit to GitHub via the Composio GitHub toolkit.

Bypasses git push (no auth) by composing a single GITHUB_COMMIT_MULTIPLE_FILES
call that:
  1. Updates the new files (install.sh, setup-company.sh, Makefile, .env.example,
     CHANGELOG.md, README.md) onto the existing `main` branch.
  2. Leaves the Aug-2 baseline (COMPANY_OS.md, TOOLING_MATRIX.md, dna/, prompts/,
     skills/, test-results/) untouched.

Then creates a `v0.1` annotated tag pointing at the new commit.

Usage:
  python3 dist/push-v0.1.py [--dry-run]

Re-runs are idempotent: the commit upserts the same paths each time, GitHub
deduplicates by content.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
COMPOSIO = "/home/openclaw/.composio/composio"
HOME = "/home/openclaw"
OS_ENV = os.environ.copy()
OS_ENV["HOME"] = HOME

OWNER = "mijoro7"
REPO = "portable-company-kit"
BRANCH = "main"

# Files to ship on top of what's already on GitHub:
#   - new files (kit/0.1.1)
#   - README.md (updated to lead with quickstart)
# Paths are repo-relative (no leading "./").
NEW_FILES = [
    "install.sh",
    "setup-company.sh",
    "Makefile",
    ".env.example",
    "CHANGELOG.md",
    "README.md", "dist/push-v0.1.py",
]

# Files to explicitly NOT touch (left as-is on main):
#   COMPANY_OS.md, TOOLING_MATRIX.md, LICENSE, .gitignore, dna/, prompts/,
#   skills/, test-results/, dist/sync-multica-to-agentpulse.py (already shipped).


def build_upserts() -> list[dict]:
    upserts: list[dict] = []
    for rel in NEW_FILES:
        fpath = REPO_ROOT / rel
        if not fpath.exists():
            print(f"❌ missing local file: {fpath}", file=sys.stderr)
            sys.exit(1)
        content = fpath.read_text(encoding="utf-8")
        upserts.append({"path": rel, "content": content, "encoding": "utf-8"})
    return upserts


def compose(author_email: str = "bizy@openclaw.ai",
            author_name: str = "Bizy") -> dict:
    return {
        "owner": OWNER,
        "repo": REPO,
        "branch": BRANCH,
        "message": (
            "kit/0.1.1: clone-and-run kit (install.sh + setup-company.sh + Makefile + env)\n\n"
            "Make this repo actually deployable:\n"
            "- install.sh       — idempotent VPS provisioning (multica + openclaw + wrapper + systemd unit), --dry-run mode\n"
            "- setup-company.sh — the 60-second setup, as a runnable script; honours .env; idempotent + --dry-run\n"
            "- Makefile         — kit commands: install, setup, verify, demo, sync, sync-dry, lint, clean, version, install-dry, setup-dry, help\n"
            "- .env.example     — workspace/run-time/agent-id variables; cron expression stays quoted\n"
            "- CHANGELOG.md     — versioned kit history\n"
            "- README.md        — leading quickstart: clone → install → setup → run"
        ),
        "author": {"name": author_name, "email": author_email},
        "committer": {"name": author_name, "email": author_email},
        "upserts": build_upserts(),
    }


def run_composio(args: list[str], payload: dict) -> dict:
    payload_path = REPO_ROOT / "dist" / ".push-payload.json"
    payload_path.write_text(json.dumps(payload))
    full = [COMPOSIO, "execute", args[0], "-d", f"@{payload_path}"]
    full.extend(args[1:])
    res = subprocess.run(full, env=OS_ENV, capture_output=True, text=True, timeout=180)
    if res.returncode != 0:
        print(f"❌ composio failed:\n{res.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads(res.stdout) if res.stdout.strip() else {}


def main():
    dry_run = "--dry-run" in sys.argv
    payload = compose()

    if dry_run:
        print("── DRY RUN: would call GITHUB_COMMIT_MULTIPLE_FILES ──")
        print(f"    owner={payload['owner']}, repo={payload['repo']}, branch={payload['branch']}")
        print(f"    upserts ({len(payload['upserts'])}):")
        for u in payload["upserts"]:
            print(f"      - {u['path']} ({len(u['content'])} bytes)")
        return

    print(f"── Pushing {len(payload['upserts'])} files to {OWNER}/{REPO}@{BRANCH} ──")
    result = run_composio(["GITHUB_COMMIT_MULTIPLE_FILES"], payload)
    if not result.get("successful"):
        print(f"❌ commit failed: {result.get('data')}", file=sys.stderr)
        sys.exit(1)

    # response shape: data.sha (the new commit sha)
    commit_sha = (result.get("data") or {}).get("sha") or (result.get("data") or {}).get("commit", {}).get("sha")
    print(f"✓ commit {commit_sha} created")
    print(f"  URL: https://github.com/{OWNER}/{REPO}/commit/{commit_sha}")

    # ── Create v0.1 tag ─────────────────────────────────────────────────────
    if not commit_sha:
        # Fallback: parse the data blob for any sha-shaped string
        import re
        m = re.search(r"\b[0-9a-f]{40}\b", json.dumps(result))
        if m:
            commit_sha = m.group(0)
            print(f"  (recovered commit sha: {commit_sha})")

    if commit_sha:
        tag_payload = {
            "owner": OWNER,
            "repo": REPO,
            "ref": "refs/tags/v0.1",
            "sha": commit_sha,
        }
        tag_path = REPO_ROOT / "dist" / ".tag-payload.json"
        tag_path.write_text(json.dumps(tag_payload))
        print("── Updating v0.1 tag ──")
        # Composio's update_a_reference has a known bug (encodes tag as branch);
        # do delete + recreate instead of relying on update.
        # First: delete the existing tag (idempotent — 404 is fine).
        subprocess.run(
            [COMPOSIO, "execute", "GITHUB_DELETE_A_REFERENCE",
             "-d", json.dumps({"owner": OWNER, "repo": REPO, "ref": "refs/tags/v0.1"})],
            env=OS_ENV, capture_output=True, text=True, timeout=60,
        )
        # Then: create the tag pointing at the new commit.
        tag_res = subprocess.run(
            [COMPOSIO, "execute", "GITHUB_CREATE_A_REFERENCE", "-d", f"@{tag_path}"],
            env=OS_ENV, capture_output=True, text=True, timeout=60,
        )
        if tag_res.returncode == 0:
            try:
                result = json.loads(tag_res.stdout)
                if result.get("successful"):
                    print(f"✓ tag v0.1 created → {commit_sha[:8]}")
                    print(f"  URL: https://github.com/{OWNER}/{REPO}/releases/tag/v0.1")
                else:
                    print(f"⚠️  tag creation returned: {result.get('data')}")
            except json.JSONDecodeError:
                print(f"⚠️  tag creation output not JSON: {tag_res.stdout[:200]}")
        else:
            print(f"❌ tag creation failed: {tag_res.stderr}")
    else:
        print("⚠️  no commit sha available, skipping tag")


if __name__ == "__main__":
    main()
