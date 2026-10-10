"""Observe the disposable Simulator's notification services without changing them."""
import json
from datetime import datetime, timezone
import math
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time

SERVICES = ("usernotificationsd", "SpringBoard", "lsd")
BUNDLE = "jp.n624.takupoke.app-checks"
LOG_PREDICATE = (
    f'((process == "SpringBoard" OR process == "lsd") AND eventMessage CONTAINS "{BUNDLE}")'
    ' OR (process == "usernotificationsd" AND ('
    + " OR ".join(f'eventMessage CONTAINS[c] "{word}"'
                  for word in ("authoriz", "connection", "error", "fail", "timeout", BUNDLE)) + '))'
)
WORDS = re.compile(
    r"\b(?:authorization|authorized|notDetermined|denied|granted|request|requested|"
    r"notification|notifications|connection|service|client|invalid|invalidated|"
    r"interrupted|failed|failure|error|timeout|timed|out|registered|registration|"
    r"present|presentation|alert|pending|response|reply|completion|cancelled|"
    r"foreground|background|active|inactive|suspended|terminated|running|"
    r"unrecognized|unknown|unsupported|predicate|argument|format|option|memory|limit)\b", re.I)


def observations(entries):
    if not isinstance(entries, list):
        raise ValueError("Expected an OS log array")
    result = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        process = PurePosixPath(str(entry.get("processImagePath", ""))).name
        message = str(entry.get("eventMessage", ""))
        if process not in SERVICES or not (
            BUNDLE in message or (process == "usernotificationsd" and
                                 re.search(r"authoriz|connection|error|fail|timeout", message, re.I))
        ):
            continue
        # Publish only a fixed vocabulary, never identifiers, payloads or raw OS text.
        result.append({"process": process, "words": WORDS.findall(message)[:24]})
    return result[-80:]


def request_window(trace, now):
    pattern = re.compile(r"TAKUPOKE_LIFECYCLE pid=(\d+) time=(\d+(?:\.\d+)?) "
                         r"stage=notification-auth-(request|returned|callback)")
    requests = {}
    latest = None
    for line in trace.splitlines():
        match = pattern.fullmatch(line)
        if not match:
            continue
        pid, stamp, stage = match.groups()
        stamp = float(stamp)
        if not math.isfinite(stamp) or not 0 <= now - stamp <= 7200:
            continue
        if stage == "request":
            requests[pid] = {"time": stamp, "returned": False, "callback": False}
            latest = requests[pid]
        elif pid in requests and stamp >= requests[pid]["time"]:
            if stage == "returned":
                requests[pid]["returned"] = True
            else:
                requests[pid]["callback"] = True
    request = next((request for request in requests.values() if not request["callback"]), latest)
    if request is None:
        return None
    return {**request, "start": request["time"] - 5, "end": min(now, request["time"] + 75)}


def owned_trace(simulator):
    result = subprocess.run(["xcrun", "simctl", "get_app_container", simulator, BUNDLE, "data"],
                            capture_output=True, text=True, timeout=5)
    if result.returncode:
        return ""
    root = Path(result.stdout.strip())
    if not root.is_absolute():
        return ""
    owned = root / "tmp/takupoke-fictional-launch-owned.log"
    if owned.is_symlink() or owned.parent.is_symlink() or not owned.is_file() or owned.stat().st_size > 65536:
        return ""
    return owned.read_text(encoding="utf-8")


def collect(simulator, *, trace=None, now=None):
    base = ["xcrun", "simctl", "spawn", simulator]
    health = subprocess.run(base + ["launchctl", "list"], capture_output=True,
                            text=True, timeout=5)
    statuses = []
    for line in health.stdout.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[2].rsplit(".", 1)[-1] in SERVICES:
            if re.fullmatch(r"\d+|-", fields[0]) and re.fullmatch(r"-?\d+", fields[1]):
                statuses.append({"service": fields[2].rsplit(".", 1)[-1],
                                 "running": fields[0] != "-", "exit": int(fields[1])})
    window = request_window(owned_trace(simulator) if trace is None else trace,
                            time.time() if now is None else now)
    dates = ["--last", "10m"]
    if window:
        def formatted(stamp):
            return datetime.fromtimestamp(stamp, timezone.utc).strftime("%Y-%m-%d %H:%M:%S%z")
        dates = ["--start", formatted(window["start"]), "--end", formatted(window["end"])]
    logs = subprocess.run(base + ["log", "show"] + dates + ["--style", "json", "--info",
                                  "--predicate", LOG_PREDICATE], capture_output=True,
                          text=True, timeout=10)
    byte_count = len(logs.stdout.encode())
    if logs.returncode:
        events = "failed"
    elif byte_count > 4 * 1024 * 1024:
        events = "limited"
    else:
        try:
            events = observations(json.loads(logs.stdout))
        except (ValueError, TypeError):
            events = "invalid-format"
    print("TAKUPOKE_NOTIFICATION_SERVICES " + json.dumps({"services": statuses,
        "healthExit": health.returncode, "logExit": logs.returncode, "logBytes": byte_count,
        "errorWords": WORDS.findall(logs.stderr or "")[:24], "window": window, "events": events}))


if __name__ == "__main__":
    try:
        collect(sys.argv[1])
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        print("TAKUPOKE_NOTIFICATION_SERVICES unavailable")
