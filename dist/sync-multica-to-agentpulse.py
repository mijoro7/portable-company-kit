#!/usr/bin/env python3
"""
sync-multica-to-agentpulse.py — Pull a Multica workspace's issues and sync to AgentPulse columns.

This is a one-way sync (Multica → AgentPulse), good enough for board parity testing.

Status mapping:
  Multica status       → AgentPulse column
  ---------------------+----------------
  todo / backlog       → Backlog
  in_progress          → In Progress
  in_review            → In Progress  (treat as "in flight")
  blocked              → In Progress  (visible but flagged)
  done                 → Done
  cancelled            → Done

Usage:
  python3 sync-multica-to-agentpulse.py [--limit N] [--dry-run]

Reads:
  - Multica: `multica issue list --output json`
  - AgentPulse board context + columns from local API
Writes:
  - Posts matching AgentPulse tasks (or moves them if a title match is found).
"""

import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

AP_PROJECT_ID = "6a4b8374d8c4fdd53d59185d"
AP_INVOKE = "http://api.rectify.so/v1/agent-pulse/ai-tools/invoke"
AP_CONTEXT = "http://api.rectify.so/v1/agent-pulse/ai-tools/board-context"
AP_TOKEN = os.environ.get("OPENCLAW_GATEWAY_TOKEN")

COLUMN_MAP = {
    "backlog": "backlog",
    "todo": "backlog",
    "in_progress": "in_progress",
    "in_review": "in_progress",
    "blocked": "in_progress",
    "done": "done",
    "cancelled": "done",
}


def ap_request(tool, args):
    body = json.dumps(
        {"projectId": AP_PROJECT_ID, "tool": tool, "args": args}
    ).encode()
    req = urllib.request.Request(
        AP_INVOKE,
        data=body,
        headers={
            "x-api-token": AP_TOKEN,
            "x-agent-name": "main",
            "Content-Type": "application/json",
            "User-Agent": "multica-sync/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        payload = json.loads(r.read())
    # invoke wraps: {"tool":..., "ok":..., "result": <actual>}  ; sometimes result is a list, sometimes a dict.
    inner = payload.get("result", payload) if isinstance(payload, dict) else payload
    if isinstance(inner, list):
        return inner
    if isinstance(inner, dict) and inner.get("ok") is True:
        return inner.get("result", inner)
    return inner


def ap_context():
    return ap_request("list_columns", {})


def ap_tasks():
    return ap_request("list_tasks", {})


def multica_list(limit=50):
    out = subprocess.run(
        ["multica", "issue", "list", "--limit", str(limit), "--output", "json"],
        capture_output=True, text=True, timeout=15,
    )
    data = json.loads(out.stdout or "{}")
    return data.get("issues", data) if isinstance(data, dict) else data


def column_id_for(context, slug):
    for col in context["columns"]:
        if col["slug"] == slug:
            return col["id"]
    return None


def existing_title(context, title):
    """Check if a task with this title already exists on the board."""
    titles = {t["title"]: t for t in context.get("tasks", [])}
    return titles.get(title)


def main():
    dry_run = "--dry-run" in sys.argv
    limit = 50
    if "--limit" in sys.argv:
        i = sys.argv.index("--limit")
        limit = int(sys.argv[i + 1])

    issues = multica_list(limit=limit)
    cols = ap_context()
    tasks = ap_tasks()
    ctx = {"columns": cols if isinstance(cols, list) else [], "tasks": tasks if isinstance(tasks, list) else []}
    print(f"Multica: {len(issues)} issues")
    print(f"AgentPulse: {len(ctx.get('tasks', []))} existing tasks")
    print()

    created = moved = skipped = errors = 0
    for issue in issues:
        ident = issue["identifier"]
        title = issue["title"]
        status = issue["status"]
        target_slug = COLUMN_MAP.get(status, "backlog")
        target_col = column_id_for(ctx, target_slug)
        if not target_col:
            print(f"  {ident} → no column for {target_slug!r}, skipping")
            skipped += 1
            continue

        priority = (issue.get("priority") or "medium").lower()
        if priority not in ("low", "medium", "high"):
            priority = "medium"

        desc_parts = [f"Synced from Multica {ident} (status={status})."]
        if issue.get("description"):
            desc_parts.append(f"\n\n{issue['description'][:500]}")
        desc = "\n".join(desc_parts)

        existing = existing_title(ctx, title)
        target_col_name = next((c["name"] for c in ctx["columns"] if c["id"] == target_col), "?")
        if existing:
            target_col_id = target_col
            existing_col = existing.get("columnId")
            if existing_col == target_col_id:
                print(f"  {ident} → '{title[:50]}' already in {target_col_name}, skipping")
                skipped += 1
            else:
                if dry_run:
                    print(f"  [dry] would move {ident} → {target_col_name}")
                else:
                    r = ap_request("move_task", {"taskId": existing["id"], "columnId": target_col})
                    moved += 1
                    print(f"  {ident} → MOVED to {target_col_name}")
        else:
            if dry_run:
                print(f"  [dry] would create {ident} → {target_col_name}")
            else:
                try:
                    r = ap_request("create_task", {
                        "title": title,
                        "description": desc,
                        "priority": priority,
                        "columnId": target_col,
                    })
                    created += 1
                    print(f"  {ident} → CREATED in {target_col_name}")
                except urllib.error.HTTPError as e:
                    print(f"  {ident} → ERROR {e.code}: {e.read().decode()}")
                    errors += 1

    print()
    print(f"Done. created={created} moved={moved} skipped={skipped} errors={errors}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
