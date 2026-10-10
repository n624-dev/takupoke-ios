"""Observe the disposable Simulator's notification services without changing them."""
import json
from pathlib import PurePosixPath
import re
import subprocess
import sys

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


def collect(simulator):
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
    logs = subprocess.run(base + ["log", "show", "--last", "10m", "--style", "json", "--info",
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
        "errorWords": WORDS.findall(logs.stderr or "")[:24], "events": events}))


if __name__ == "__main__":
    try:
        collect(sys.argv[1])
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        print("TAKUPOKE_NOTIFICATION_SERVICES unavailable")
