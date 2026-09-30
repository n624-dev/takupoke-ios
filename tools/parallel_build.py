"""Run isolated simulator checks alongside host checks and the iPhone build."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


def run_commands(commands):
    processes = []
    logs = []
    started = time.monotonic()
    previous = {}

    def interrupted(signum, _frame):
        raise SystemExit(128 + signum)

    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, interrupted)
        for name, command in commands:
            log = tempfile.TemporaryFile()
            logs.append(log)
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            processes.append((name, process, log))
            print(f"Started: {name}", flush=True)
        pending = list(processes)
        while pending:
            for entry in pending[:]:
                name, process, log = entry
                code = process.poll()
                if code is None:
                    continue
                pending.remove(entry)
                log.seek(0)
                print(log.read().decode(errors="replace"), end="", flush=True)
                print(f"Finished: {name}, exit={code}, elapsed={time.monotonic() - started:.1f}s", flush=True)
                if code:
                    return code if code > 0 else 128 - code
            if pending:
                time.sleep(0.2)
        return 0
    finally:
        # Terminate entire process groups so swiftc/xcodebuild cannot outlive the
        # caller. Shell EXIT traps remove their own temporary data and simulator.
        for _, process, _ in processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 15
        for _, process, _ in processes:
            try:
                process.wait(timeout=max(0, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        for log in logs:
            log.close()
        for sig, handler in previous.items():
            signal.signal(sig, handler)


if __name__ == "__main__":
    scratch = str(Path(sys.argv[1]).resolve())
    sys.exit(run_commands([
        ("Picker UI", ["bash", "tools/test-picker-ui.sh"]),
        ("Application UI", ["bash", "tools/test-app-ui.sh"]),
        ("Host tests and iPhone build", ["bash", "tools/build-ios-app.sh", scratch]),
    ]))
