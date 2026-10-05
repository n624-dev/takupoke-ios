"""Wait for this run's required checks before publishing the locally built IPA."""
import argparse
import json
import os
import subprocess
import time
from ui_test_manifest import ALL_UI_REQUIRED_JOBS

REPOSITORY = "n624-dev/takupoke-ios"
REQUIRED = ALL_UI_REQUIRED_JOBS | {"Distribution tests", "Native PDF and recovery tests"}


def api(path, *, pages=False):
    args = ["gh", "api", "--header", "Cache-Control: no-cache"]
    if pages:
        args += ["--paginate", "--slurp"]
    return json.loads(subprocess.check_output(args + [path], text=True))


def check_snapshot(run, jobs, *, run_id, attempt, commit):
    if (run.get("id") != run_id or run.get("run_attempt") != attempt
            or run.get("head_sha") != commit or run.get("head_branch") != "main"
            or run.get("repository", {}).get("full_name") != REPOSITORY
            or run.get("event") not in ("push", "workflow_dispatch")):
        raise ValueError("Publication checks belong to an unexpected run or commit")
    found = {}
    for job in jobs:
        name = job.get("name")
        if name not in REQUIRED:
            continue
        if name in found:
            raise ValueError("Duplicate required check: " + name)
        if (job.get("run_id") != run_id or job.get("run_attempt") != attempt
                or job.get("head_sha") != commit):
            raise ValueError("Required check belongs to another run, attempt or commit")
        found[name] = job
        if job.get("status") == "completed" and job.get("conclusion") != "success":
            raise ValueError("Required check did not succeed: " + name)
    pending = sorted(name for name in REQUIRED
                     if name not in found or found[name].get("status") != "completed")
    return pending


def wait_for_checks(run_id, attempt, commit, *, timeout=2400, interval=60,
                    read=api, clock=time.monotonic, sleep=time.sleep):
    deadline = clock() + timeout
    previous = None
    while True:
        # Current run metadata also detects a newer rerun attempt.
        run = read(f"repos/{REPOSITORY}/actions/runs/{run_id}")
        pages = read(f"repos/{REPOSITORY}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100",
                     pages=True)
        jobs = [job for page in pages for job in page["jobs"]]
        pending = check_snapshot(run, jobs, run_id=run_id, attempt=attempt, commit=commit)
        if clock() > deadline:
            raise TimeoutError("Required publication checks timed out")
        if not pending:
            print("All required checks succeeded for this run, attempt and commit.", flush=True)
            return
        if pending != previous:
            print("Waiting for: " + ", ".join(pending), flush=True)
            previous = pending
        remaining = deadline - clock()
        if remaining <= 0:
            raise TimeoutError("Required publication checks timed out")
        sleep(min(interval, remaining))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout-seconds", type=int, default=2400)
    args = parser.parse_args()
    if (os.environ.get("GITHUB_REPOSITORY") != REPOSITORY
            or os.environ.get("GITHUB_REF") != "refs/heads/main"
            or os.environ.get("GITHUB_EVENT_NAME") not in ("push", "workflow_dispatch")):
        raise ValueError("Publication gate is restricted to the trusted main workflow")
    run_id = int(os.environ["GITHUB_RUN_ID"])
    attempt = int(os.environ["GITHUB_RUN_ATTEMPT"])
    commit = os.environ["GITHUB_SHA"]
    if run_id <= 0 or attempt <= 0 or len(commit) != 40 or any(c not in "0123456789abcdef" for c in commit):
        raise ValueError("Invalid publication context")
    wait_for_checks(run_id, attempt, commit, timeout=args.timeout_seconds)


if __name__ == "__main__":
    main()
