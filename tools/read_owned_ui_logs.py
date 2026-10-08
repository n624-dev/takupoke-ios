"""Read one immutable fictional QA run; emit bounded text, no images/artifacts."""
import json
import re
import subprocess
import tempfile
from pathlib import Path

REPO = "n624-dev/takupoke-ios"
RUN = 37773544786
SOURCE = "8b9e6d53d555b377aa9d4fbcae3b7f6e1c7eaaf6"
MAX_BYTES = 64 * 1024 * 1024


def api(path):
    result = subprocess.run(["gh", "api", path], capture_output=True, timeout=45)
    if result.returncode:
        raise RuntimeError("GitHub metadata read failed; endpoint credentials omitted")
    return json.loads(result.stdout)


def read_log(job_id):
    # This process owns the temporary bytes; no artifact or cache is uploaded.
    with tempfile.TemporaryDirectory(prefix="owned-fictional-ui-log-") as owned:
        target = Path(owned) / "job.txt"
        with target.open("wb") as stream:
            process = subprocess.Popen(["gh", "api", f"repos/{REPO}/actions/jobs/{job_id}/logs"],
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            try:
                total = 0
                while True:
                    chunk = process.stdout.read(65536)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > MAX_BYTES:
                        process.kill()
                        raise RuntimeError("Owned log exceeds diagnostic byte cap")
                    stream.write(chunk)
                status = process.wait(timeout=60)
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
        if status:
            return None
        return target.read_text(encoding="utf-8", errors="replace")


def summarize(raw):
    # These jobs only run the pinned independent fictional fixtures. Never
    # emit screenshot payloads or URLs/credentials from runner/network errors.
    lines = [line for line in raw.splitlines() if "_IMAGE " not in line]
    marker = re.compile(r"Test Case|Executed .* tests?|Verified .* completion|NATIVE_TAB|NATIVE_SWITCH|NOTIFICATION_SWITCH|AI_SWITCH|TAKUPOKE-MANUAL-(ACK|EDIT|REVIEW|APP-STATE|INPUT|COORDINATOR|PROCESS)|error:|XCTAssert|Assertion Failure|failed|unresolved|No safe visible|Fixture menu|Opened menu")
    selected = set(i for i,line in enumerate(lines) if marker.search(line))
    for i,line in enumerate(lines):
        if re.search(r"error:|XCTAssert|Assertion Failure|Test Case.* failed|unresolved|No safe visible|Fixture menu|Opened menu",line):
            selected.update(range(max(0,i-12),min(len(lines),i+30)))
    for i in sorted(selected)[-220:]:
        line = re.sub(r"https?://[^\s\"<>]+", "[URL omitted]", lines[i])
        print(line[:1600])


def main():
    run = api(f"repos/{REPO}/actions/runs/{RUN}")
    if (run.get("head_sha") != SOURCE or run.get("head_branch") != "codex/pdf-local-recovery"
            or run.get("repository", {}).get("full_name") != REPO or run.get("run_attempt") != 1
            or run.get("event") != "workflow_dispatch"):
        raise RuntimeError("Diagnostic source identity mismatch")
    jobs = api(f"repos/{REPO}/actions/runs/{RUN}/attempts/1/jobs?per_page=100")["jobs"]
    for job in jobs:
        if not (job["name"].startswith("Application iOS ") or job["name"].startswith("Manual correction iOS ")):
            continue
        if job.get("run_id") != RUN or job.get("head_sha") != SOURCE or job.get("run_attempt") != 1:
            raise RuntimeError("Diagnostic job identity mismatch")
        print(json.dumps({"jobId":job["id"],"name":job["name"],"status":job["status"],"conclusion":job["conclusion"]},ensure_ascii=False))
        if job["status"] == "queued":
            continue
        raw = read_log(job["id"])
        if raw is None:
            print("Owned job log is not available yet.")
        else:
            summarize(raw)


if __name__ == "__main__":
    main()
