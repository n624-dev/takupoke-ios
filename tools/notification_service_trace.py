"""Observe the disposable Simulator's notification services without changing them."""
import json
from datetime import datetime, timezone
import math
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile
import time

SERVICES = ("usernotificationsd", "SpringBoard", "lsd", "runningboardd", "launchd")
BUNDLE = "jp.n624.takupoke.app-checks"
LOG_PREDICATE = (
    '(' + ' OR '.join(f'process == "{name}"' for name in SERVICES[1:])
    + f') AND eventMessage CONTAINS "{BUNDLE}"'
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
    r"unrecognized|unknown|unsupported|predicate|argument|format|option|memory|limit|"
    r"presented|presenting|dismissed|deferred|suppressed|queued|queue|busy|ready|visible|"
    r"hidden|waiting|blocking|blocked|approved|allowed|enabled|disabled|permission|prompt|"
    r"dialog|rejected|reason|session|assertion|transaction|locked|unlocked|connected|"
    r"display|screen|interactive|unavailable|attempt|delegate|true|false|not)\b", re.I)

LAUNCH_ERROR = re.compile(
    r"\b(?:Error\s+)?Domain=(FBSOpenApplicationServiceErrorDomain|FBProcessExit|"
    r"RBSRequestErrorDomain|NSPOSIXErrorDomain|NSMachErrorDomain)\s+Code=(-?\d{1,10})\b"
)


def launch_error_codes(message):
    """Keep nested OS error codes; never copy failure reasons or UserInfo."""
    result = []
    for match in LAUNCH_ERROR.finditer(message):
        domain, raw_code = match.groups()
        code = int(raw_code)
        if -(2**31) <= code < 2**31:
            result.append({"domain": domain, "code": code})
        if len(result) == 8:
            break
    return result


def fixed_words(message, pattern=WORDS):
    # Framework type names use camel case; expose only the same fixed terms.
    separated = re.sub(r"(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", " ", message)
    return pattern.findall(separated)[:24]


AX_SERVICES = ("VoiceOverTouch", "AccessibilityUIServer", "AXUIServer", "accessibilityd",
               "voiceservicesd", "SpringBoard", "backboardd")
AX_WORDS = re.compile(WORDS.pattern +
                     r"|\b(?:voiceover|speech|focus|utterance|touch|gesture|hid|event|port|initialize)\b", re.I)
AX_PREDICATE = (
    '(' + ' OR '.join(f'process == "{name}"' for name in AX_SERVICES[:5]) + ')'
    ' OR ((process == "SpringBoard" OR process == "backboardd") AND ('
    + ' OR '.join(f'eventMessage CONTAINS[c] "{word}"'
                  for word in ("voiceover", "accessib", "HID", "touch", "gesture")) + '))'
)


def collect_accessibility(simulator):
    """Read OS state after failure; never enable a service or resend an input."""
    base = ["xcrun", "simctl", "spawn", simulator]
    health = observe_command(base + ["launchctl", "list"], 5, max_bytes=65536)
    statuses = []
    seen = set()
    for line in health.stdout.splitlines() if len(health.stdout.encode()) <= 65536 else []:
        fields = line.split()
        service = fields[2].rsplit(".", 1)[-1] if len(fields) == 3 else None
        if service in AX_SERVICES and service not in seen:
            if (re.fullmatch(r"\d+|-", fields[0]) and len(fields[1]) <= 11 and
                    re.fullmatch(r"-?\d+", fields[1])):
                code = int(fields[1])
                if not -(2**31) <= code < 2**31:
                    continue
                seen.add(service)
                statuses.append({"service": service, "running": fields[0] != "-", "exit": code})
    logs = observe_command(base + ["log", "show", "--last", "10m", "--style", "json", "--info",
                                  "--predicate", AX_PREDICATE], 10, max_bytes=4 * 1024 * 1024)
    size = len(logs.stdout.encode())
    events = "failed"
    if logs.returncode == 0:
        if size > 4 * 1024 * 1024:
            events = "limited"
        else:
            try:
                entries = json.loads(logs.stdout)
                if not isinstance(entries, list):
                    raise ValueError("Expected an OS log array")
                events = []
                for entry in entries:
                    if not isinstance(entry, dict):
                        continue
                    process = PurePosixPath(str(entry.get("processImagePath", ""))).name
                    message = str(entry.get("eventMessage", ""))
                    if process not in AX_SERVICES or (process in AX_SERVICES[-2:] and
                            not re.search(r"voiceover|accessib|HID|touch|gesture", message, re.I)):
                        continue
                    # Only fixed words and known process names leave the owned Simulator.
                    events.append({"process": process, "words": fixed_words(message, AX_WORDS)})
                events = events[:40] + events[-40:] if len(events) > 80 else events
            except (ValueError, TypeError):
                events = "invalid-format"
    print("TAKUPOKE_AX_SERVICES " + json.dumps({"services": statuses,
        "healthLimited": len(health.stdout.encode()) > 65536,
        "healthExit": health.returncode, "logExit": logs.returncode, "logBytes": size,
        "healthErrorWords": fixed_words(health.stderr or "", AX_WORDS),
        "errorWords": fixed_words(logs.stderr or "", AX_WORDS), "events": events}))


def observations(entries):
    if not isinstance(entries, list):
        raise ValueError("Expected an OS log array")
    result = []
    important = []
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
        observation = {"process": process, "words": fixed_words(message)}
        codes = launch_error_codes(message)
        if codes:
            observation["launchErrors"] = codes
        result.append(observation)
        if re.search(r"authoriz|permission|notif|alert|prompt|timeout|fail|error|invalidated|interrupted",
                     message, re.I):
            important.append(len(result) - 1)
    # Preserve request evidence before repeated accessibility-client messages.
    # Keep chronology even when the bounded selection favours relevant events.
    selected = set(important if len(important) <= 80 else important[:60] + important[-20:])
    for index in range(len(result) - 1, -1, -1):
        if len(selected) >= 80:
            break
        selected.add(index)
    return [result[index] for index in sorted(selected)]


def observe_command(command, timeout, *, max_bytes=None):
    try:
        if max_bytes is not None:
            # Anonymous owned files keep subprocess output out of memory while it runs.
            # Close/unlink even on timeout; read only the bounded prefix afterward.
            with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
                result = subprocess.run(command, stdout=output, stderr=errors, timeout=timeout)
                output.seek(0)
                errors.seek(0)
                return subprocess.CompletedProcess(command, result.returncode,
                    output.read(max_bytes + 1).decode("utf-8", errors="replace"),
                    errors.read(65536).decode("utf-8", errors="replace"))
        return subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(command, -1, "", "timeout")
    except OSError:
        return subprocess.CompletedProcess(command, -1, "", "unavailable")


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
    health = observe_command(base + ["launchctl", "list"], 5)
    statuses = []
    for line in health.stdout.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[2].rsplit(".", 1)[-1] in SERVICES:
            if re.fullmatch(r"\d+|-", fields[0]) and re.fullmatch(r"-?\d+", fields[1]):
                statuses.append({"service": fields[2].rsplit(".", 1)[-1],
                                 "running": fields[0] != "-", "exit": int(fields[1])})
    trace_error = None
    if trace is None:
        try:
            trace = owned_trace(simulator)
        except subprocess.TimeoutExpired:
            trace, trace_error = "", "timeout"
        except (OSError, ValueError):
            trace, trace_error = "", "unavailable"
    window = request_window(trace, time.time() if now is None else now)
    dates = ["--last", "10m"]
    if window:
        def formatted(stamp):
            return datetime.fromtimestamp(stamp, timezone.utc).strftime("%Y-%m-%d %H:%M:%S%z")
        dates = ["--start", formatted(window["start"]), "--end", formatted(window["end"])]
    logs = observe_command(base + ["log", "show"] + dates + ["--style", "json", "--info",
                           "--predicate", LOG_PREDICATE], 10, max_bytes=4 * 1024 * 1024)
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
        "healthErrorWords": fixed_words(health.stderr or ""), "traceError": trace_error,
        "errorWords": fixed_words(logs.stderr or ""), "window": window, "events": events}))


if __name__ == "__main__":
    accessibility = sys.argv[1:2] == ["--accessibility"]
    try:
        if accessibility:
            collect_accessibility(sys.argv[2])
        else:
            collect(sys.argv[1])
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        print(("TAKUPOKE_AX_SERVICES" if accessibility else
               "TAKUPOKE_NOTIFICATION_SERVICES") + " unavailable")
