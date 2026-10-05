"""Bounded text-only diagnostics for the owned fictional manual UI simulator.

Run before deleting the simulator/result bundle. No screenshots, attachment payloads,
log archives, or image/base64 contents are printed. Missing evidence stays unknown.
"""
import argparse
import hashlib
import json
import os
import signal
from pathlib import Path
import subprocess
import tempfile
import time

BUNDLE = "jp.n624.takupoke.app-checks"
MAX_OUTPUT = 262144
MAX_REPORT = 524288


def command(args, *, timeout=15, cap=MAX_OUTPUT):
    """Bound runtime and stored output, including noisy/unsupported Xcode tools."""
    started = time.monotonic()
    with tempfile.TemporaryFile() as output:
        process = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        reason = None
        try:
            while process.poll() is None:
                if time.monotonic() - started >= timeout:
                    reason = "timeout"
                    break
                if os.fstat(output.fileno()).st_size > cap:
                    reason = "output-cap"
                    break
                time.sleep(0.05)
            if reason:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            process.wait(timeout=2)
            output.seek(0)
            data = output.read(cap + 1)
            return {"exit": process.returncode, "limited": reason or
                    ("output-cap" if len(data) > cap else None),
                    "seconds": round(time.monotonic() - started, 2),
                    "text": data[:cap].decode("utf-8", errors="replace")}
        finally:
            if process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=2)


def legacy_failures(value):
    """Only explicit failure messages/locations; never dump attachment trees."""
    issues = value.get("issues", {}).get("testFailureSummaries", {}).get("_values", [])
    return [{key: item.get(key, {}).get("_value", "")[:8000]
             for key in ("testCaseName", "message", "issueType")}
            for item in issues[:32]]


def report_matches(path, started):
    if path.is_symlink() or not path.is_file() or path.suffix not in (".ips", ".crash"):
        return None
    stat = path.stat()
    if stat.st_mtime < started or stat.st_size > MAX_REPORT:
        return None
    raw = path.read_bytes()
    text = raw.decode("utf-8", errors="strict")
    # Jetsam is relevant only if this exact fictional process appears in the report.
    if BUNDLE not in text and '"AppChecks"' not in text and "Process:             AppChecks" not in text:
        return None
    return {"name": path.name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "text": text}


def collect(scratch, simulator, started, exit_code):
    deadline = time.monotonic() + 70
    result = {"originalExit": exit_code, "simulator": simulator,
              "crashCause": "unassessed", "commands": [], "reports": []}
    bundle = scratch / "ManualResults.xcresult"
    if bundle.exists():
        try:
            item = command(["xcrun", "xcresulttool", "get", "--legacy", "--path", str(bundle),
                            "--format", "json"], timeout=15)
            text = item.pop("text")
            result["commands"].append({"kind": "xcresult-failures", **item})
            if item["exit"] == 0 and item["limited"] is None:
                result["xcresultFailures"] = legacy_failures(json.loads(text))
        except (OSError, ValueError) as error:
            result["xcresultError"] = type(error).__name__
        # Export privately, then print ONLY exact-app text crash reports below.
        try:
            item = command(["xcrun", "xcresulttool", "export", "diagnostics", "--path", str(bundle),
                            "--output-path", str(scratch / "CrashDiagnostics")], timeout=15)
            item.pop("text")
            result["commands"].append({"kind": "xcresult-diagnostics-export", **item})
        except OSError as error:
            result["exportError"] = type(error).__name__
    if simulator and time.monotonic() < deadline:
        predicate = ('process == "AppChecks" OR eventMessage CONTAINS "' + BUNDLE + '"')
        try:
            item = command(["xcrun", "simctl", "spawn", simulator, "log", "show", "--last", "35m",
                            "--style", "ndjson", "--predicate", predicate], timeout=15)
            text = item.pop("text")
            result["commands"].append({"kind": "owned-app-unified-log", **item})
            # Explicit process-filtered text; no binary archive/attachment export.
            print("TAKUPOKE-MANUAL-UNIFIED-LOG " + json.dumps({"text": text}, ensure_ascii=False), flush=True)
        except OSError as error:
            result["logError"] = type(error).__name__
    roots = [scratch / "CrashDiagnostics", Path.home() / "Library/Logs/DiagnosticReports"]
    if simulator:
        roots.append(Path.home() / "Library/Developer/CoreSimulator/Devices" / simulator /
                     "data/Library/Logs/CrashReporter")
    seen = set()
    scanned = 0
    for root in roots:
        if not root.is_dir():
            continue
        for directory, dirs, files in os.walk(root, followlinks=False):
            dirs[:] = [d for d in dirs if not (Path(directory) / d).is_symlink()]
            if time.monotonic() >= deadline or scanned >= 1000 or len(result["reports"]) >= 4:
                result["reportCaptureLimited"] = True
                break
            for name in files:
                scanned += 1
                if scanned > 1000:
                    break
                try:
                    report = report_matches(Path(directory) / name, started)
                    if report and report["sha256"] not in seen:
                        seen.add(report["sha256"])
                        result["reports"].append(report)
                        if len(result["reports"]) >= 4:
                            break
                except (OSError, UnicodeError):
                    continue
    result["reportsScanned"] = scanned
    result["matchingTextReports"] = len(result["reports"])
    print("TAKUPOKE-MANUAL-DIAGNOSTICS " + json.dumps(result, ensure_ascii=False), flush=True)


def interrupted(signum, _frame):
    # Unwind command() so its owned process group is killed/reaped before exiting.
    raise SystemExit(128 + signum)


if __name__ == "__main__":
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, interrupted)
    parser = argparse.ArgumentParser()
    parser.add_argument("scratch", type=Path)
    parser.add_argument("simulator")
    parser.add_argument("started", type=float)
    parser.add_argument("exit_code", type=int)
    args = parser.parse_args()
    collect(args.scratch, args.simulator, args.started, args.exit_code)
