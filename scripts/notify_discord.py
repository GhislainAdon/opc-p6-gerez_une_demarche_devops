#!/usr/bin/env python3
"""notify_discord.py — pipeline result notification.

Purpose : post the CI pipeline outcome to the team Discord channel so both
          Dev and Ops teams get real-time feedback without polling GitLab.
Usage   : python3 scripts/notify_discord.py [status]
          `status` defaults to $CI_JOB_STATUS / "unknown".
Config  : the webhook is routed per environment branch. The script uses
          DISCORD_WEBHOOK_URL_<BRANCH> (e.g. DISCORD_WEBHOOK_URL_DEV / _TEST /
          _PROD) when it exists, and falls back to DISCORD_WEBHOOK_URL for any
          other branch. All are masked GitLab CI/CD variables — never committed.
          All other fields are read from standard GitLab CI variables.
Exit    : 0 on success or when the webhook is not configured (no-op),
          1 on HTTP error, so the notify job surfaces delivery problems.

Standard library only (urllib) — no pip install needed in CI.
"""
import json
import os
import sys
import urllib.request

COLORS = {"success": 0x2ECC71, "failed": 0xE74C3C, "canceled": 0x95A5A6}


def resolve_webhook() -> str:
    """Pick the environment webhook (DISCORD_WEBHOOK_URL_<BRANCH>) if defined,
    otherwise fall back to the generic DISCORD_WEBHOOK_URL."""
    branch = os.environ.get("CI_COMMIT_REF_NAME", "")
    key = "DISCORD_WEBHOOK_URL_" + branch.upper().replace("-", "_")
    return os.environ.get(key) or os.environ.get("DISCORD_WEBHOOK_URL", "")


def build_payload(status: str) -> dict:
    project = os.environ.get("CI_PROJECT_PATH", "local/project")
    branch = os.environ.get("CI_COMMIT_REF_NAME", "?")
    sha = os.environ.get("CI_COMMIT_SHORT_SHA", "?")
    title = os.environ.get("CI_COMMIT_TITLE", "")
    url = os.environ.get("CI_PIPELINE_URL", "")
    author = os.environ.get("GITLAB_USER_NAME", "CI")
    emoji = "✅" if status == "success" else ("❌" if status == "failed" else "⚠️")
    return {
        "username": "Orion CI",
        "embeds": [
            {
                "title": f"{emoji} Pipeline {status} — {project}",
                "url": url,
                "color": COLORS.get(status, 0xF1C40F),
                "fields": [
                    {"name": "Branche", "value": branch, "inline": True},
                    {"name": "Commit", "value": f"`{sha}` {title}"[:1024], "inline": True},
                    {"name": "Auteur", "value": author, "inline": True},
                ],
            }
        ],
    }


def main() -> int:
    webhook = resolve_webhook()
    if not webhook:
        print("No Discord webhook for this branch — skipping notification (no-op).")
        return 0
    status = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get("CI_JOB_STATUS", "unknown")).lower()
    req = urllib.request.Request(
        webhook,
        data=json.dumps(build_payload(status)).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "orion-ci-notifier/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"Discord notified (HTTP {resp.status}).")
            return 0
    except Exception as exc:  # noqa: BLE001 — report any delivery failure
        print(f"ERROR: Discord notification failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
