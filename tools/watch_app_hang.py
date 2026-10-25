"""Opt-in, read-only sampling of the owned fictional app during a quiet AX query."""
import argparse
import json
import os
from pathlib import Path
import re
import tempfile
import time

from notification_service_trace import BUNDLE, observe_command

LIBRARIES = {"Takupoke", "GRDB", "GRDBSQLite", "SwiftUI", "SwiftUICore", "UIKitCore",
             "AttributeGraph", "Foundation", "CoreFoundation", "QuartzCore", "dyld",
             "libdispatch.dylib", "libsystem_kernel.dylib", "libsystem_pthread.dylib",
             "libsystem_platform.dylib", "libswiftCore.dylib", "libswift_Concurrency.dylib"}
SNAPSHOT_PID = re.compile(r"Requesting snapshot of accessibility hierarchy for app with pid ([1-9]\d{0,7})\b")
CASE = re.compile(r"Test Case '-\[PickerTapChecks.ApplicationChecks (test\w+)\]' (started|passed|failed)")
TARGET_CASE = "testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch"
FRAME = re.compile(r"\s*[+|!: ]*\d+\s+(.+?)\s+\(in ([A-Za-z0-9_.-]+)\)")
SYMBOL = re.compile(r"[A-Za-z0-9_.$:<>?&*, ()\[\]+=-]{1,240}")


def main_thread_frames(text):
    """Keep bounded public code symbols, never headers, paths or other threads."""
    active = False
    frames = []
    for line in text.splitlines():
        if "com.apple.main-thread" in line and re.match(r"\s*\d+\s+Thread_", line):
            active = True
            continue
        if active and re.match(r"\s*\d+\s+Thread_", line):
            break
        if not active:
            continue
        match = FRAME.match(line)
        if match and match[2] in LIBRARIES and SYMBOL.fullmatch(match[1]):
            frame = {"library": match[2], "symbol": match[1]}
            if not frames or frame != frames[-1]:
                frames.append(frame)
        if len(frames) == 48:
            break
    return frames


def collect(simulator, pid, *, root=None):
    result = {"trigger": "quiet-after-snapshot", "pid": pid, "executableMatches": False}
    app = observe_command(["xcrun", "simctl", "get_app_container", simulator, BUNDLE, "app"], 5,
                          max_bytes=4096)
    bundle = app.stdout.strip()
    if app.returncode != 0 or not Path(bundle).is_absolute() or Path(bundle).name != "Takupoke.app":
        result["status"] = "owned-app-unavailable"
        return result
    executable = observe_command(["ps", "-ww", "-p", str(pid), "-o", "comm="], 5, max_bytes=4096)
    if executable.returncode != 0 or executable.stdout.strip() != str(Path(bundle) / "Takupoke"):
        result["status"] = "process-mismatch-or-exited"
        return result
    result["executableMatches"] = True
    with tempfile.TemporaryDirectory(prefix="takupoke-owned-stack-", dir=root) as directory:
        path = Path(directory) / "sample.txt"
        sampled = observe_command(["sample", str(pid), "1", "10", "-file", str(path)], 5,
                                  max_bytes=65536)
        result["sampleExit"] = sampled.returncode
        if sampled.returncode != 0 or not path.is_file() or path.is_symlink():
            result["status"] = "sample-unavailable"
            return result
        if path.stat().st_size > 4 * 1024 * 1024:
            result["status"] = "sample-limited"
            return result
        try:
            result["frames"] = main_thread_frames(path.read_text(encoding="utf-8"))
            result["status"] = "sampled" if result["frames"] else "no-recognized-main-thread"
        except (OSError, UnicodeError):
            result["status"] = "sample-unreadable"
    return result


def watch(log, stop, simulator, *, quiet=20, interval=.5, parent=None, sample=None):
    parent = os.getppid() if parent is None else parent
    offset = 0
    tail = b""
    last_change = time.monotonic()
    pid = None
    active = False
    sampled = set()
    while not stop.exists() and os.getppid() == parent:
        if log.is_file() and not log.is_symlink():
            with log.open("rb") as stream:
                stream.seek(offset)
                chunk = stream.read(1024 * 1024)
            if chunk:
                offset += len(chunk)
                last_change = time.monotonic()
                lines = (tail + chunk).split(b"\n")
                tail = lines.pop()[-8192:]
                for line in lines:
                    if len(line) > 8192:
                        continue
                    text = line.decode("utf-8", errors="replace")
                    case = CASE.search(text)
                    if case:
                        active = case[1] == TARGET_CASE and case[2] == "started"
                        pid = None
                    match = SNAPSHOT_PID.search(text)
                    if active and match:
                        pid = int(match[1])
        elapsed = time.monotonic() - last_change
        if active and pid is not None and pid not in sampled and len(sampled)<2 and elapsed >= quiet and not stop.exists():
            sampled.add(pid)
            result = collect(simulator, pid, root=log.parent) if sample is None else sample(simulator, pid)
            result["quietSeconds"] = round(elapsed, 3)
            print("TAKUPOKE_APP_STACK " + json.dumps(result), flush=True)
        time.sleep(interval)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--stop", type=Path, required=True)
    parser.add_argument("--simulator", required=True)
    args = parser.parse_args()
    try:
        watch(args.log, args.stop, args.simulator)
    except (OSError, ValueError):
        print('TAKUPOKE_APP_STACK {"status":"observer-unavailable"}', flush=True)
