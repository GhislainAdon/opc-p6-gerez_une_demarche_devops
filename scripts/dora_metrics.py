#!/usr/bin/env python3
"""dora_metrics.py — compute the four DORA metrics from the GitLab API.

Purpose : measure delivery performance for the performance report:
          - Deployment Frequency : successful pipelines on the delivery branch
          - Lead Time for Changes: commit timestamp -> pipeline success
          - Change Failure Rate  : failed / total pipelines on the branch
          - MTTR                 : mean time between a failed pipeline and the
                                   next successful one
Usage   : python3 scripts/dora_metrics.py [--branch solution] [--days 30]
Config  : GITLAB_TOKEN (env or .env file), GITLAB_PROJECT_ID (env, default from
          CI_PROJECT_ID) — token read from environment, never hard-coded.
Output  : human-readable summary + reports/dora_metrics.json

Standard library only — runnable in any CI job or workstation.
"""
import argparse
import datetime as dt
import json
import os
import pathlib
import statistics
import urllib.parse
import urllib.request

API = "https://gitlab.com/api/v4"


def load_env_token() -> str:
    tok = os.environ.get("GITLAB_TOKEN", "")
    if not tok and pathlib.Path(".env").exists():
        for line in pathlib.Path(".env").read_text().splitlines():
            if line.startswith("GITLAB_TOKEN="):
                tok = line.split("=", 1)[1].strip()
    if not tok:
        raise SystemExit("GITLAB_TOKEN missing (env or .env)")
    return tok


def api_get(path: str, token: str, params: dict) -> list:
    url = f"{API}{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"Private-Token": token})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def parse_ts(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--branch", default=os.environ.get("CI_COMMIT_REF_NAME", "solution"))
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--project-id", default=os.environ.get("GITLAB_PROJECT_ID") or os.environ.get("CI_PROJECT_ID", ""))
    args = ap.parse_args()
    if not args.project_id:
        raise SystemExit("GITLAB_PROJECT_ID missing")

    token = load_env_token()
    since = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=args.days)

    pipelines = api_get(
        f"/projects/{args.project_id}/pipelines",
        token,
        {"ref": args.branch, "per_page": 100, "updated_after": since.isoformat()},
    )
    finished = [p for p in pipelines if p["status"] in ("success", "failed")]
    successes = [p for p in finished if p["status"] == "success"]
    failures = [p for p in finished if p["status"] == "failed"]

    # Deployment frequency (per week)
    deploy_freq = len(successes) / max(args.days / 7, 1)

    # Lead time: commit created -> pipeline finished (success only)
    lead_times = []
    for p in successes[:20]:  # cap API calls
        try:
            commit = api_get(f"/projects/{args.project_id}/repository/commits/{p['sha']}", token, {})
            lead_times.append((parse_ts(p["updated_at"]) - parse_ts(commit["created_at"])).total_seconds())
        except Exception:  # noqa: BLE001 — skip unreadable commits
            continue

    # Change failure rate
    cfr = (len(failures) / len(finished) * 100) if finished else 0.0

    # MTTR: failed pipeline -> next success (chronological)
    ordered = sorted(finished, key=lambda p: p["updated_at"])
    restores = []
    fail_at = None
    for p in ordered:
        if p["status"] == "failed" and fail_at is None:
            fail_at = parse_ts(p["updated_at"])
        elif p["status"] == "success" and fail_at is not None:
            restores.append((parse_ts(p["updated_at"]) - fail_at).total_seconds())
            fail_at = None

    fmt_h = lambda s: f"{s / 3600:.1f} h"  # noqa: E731
    result = {
        "window_days": args.days,
        "branch": args.branch,
        "pipelines_total": len(finished),
        "deployment_frequency_per_week": round(deploy_freq, 2),
        "lead_time_median": fmt_h(statistics.median(lead_times)) if lead_times else "n/a",
        "change_failure_rate_pct": round(cfr, 1),
        "mttr": fmt_h(statistics.mean(restores)) if restores else "n/a",
    }

    print("== DORA metrics ==")
    for k, v in result.items():
        print(f"  {k:32}: {v}")
    pathlib.Path("reports").mkdir(exist_ok=True)
    pathlib.Path("reports/dora_metrics.json").write_text(json.dumps(result, indent=2))
    print("written: reports/dora_metrics.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
