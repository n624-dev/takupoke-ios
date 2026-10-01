"""Run isolated simulator checks alongside host checks and the iPhone build."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time


def run_commands(commands):
    processes = []
    readers = []
    started = time.monotonic()
    previous = {}
    output_lock = threading.Lock()

    def forward(name, stream):
        for line in stream:
            with output_lock:
                print(f"[{name}] {line}", end="", flush=True)
        stream.close()

    def interrupted(signum, _frame):
        raise SystemExit(128 + signum)

    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, interrupted)
        for name, command in commands:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       start_new_session=True, text=True, errors="replace")
            processes.append((name, process))
            print(f"Started: {name}", flush=True)
            reader = threading.Thread(target=forward, args=(name, process.stdout), daemon=True)
            readers.append(reader)
            reader.start()
        pending = list(processes)
        while pending:
            for entry in pending[:]:
                name, process = entry
                code = process.poll()
                if code is None:
                    continue
                pending.remove(entry)
                print(f"Finished: {name}, exit={code}, elapsed={time.monotonic() - started:.1f}s", flush=True)
                if code:
                    return code if code > 0 else 128 - code
            if pending:
                time.sleep(0.2)
        return 0
    finally:
        # Terminate entire process groups so swiftc/xcodebuild cannot outlive the
        # caller. Shell EXIT traps remove their own temporary data and simulator.
        for _, process in processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 15
        for _, process in processes:
            try:
                process.wait(timeout=max(0, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        for reader in readers:
            reader.join(timeout=3)
        for sig, handler in previous.items():
            signal.signal(sig, handler)


if __name__ == "__main__":
    scratch = str(Path(sys.argv[1]).resolve())
    sys.exit(run_commands([
        ("Picker UI", ["bash", "tools/test-picker-ui.sh"]),
        ("Host tests and iPhone build", ["bash", "tools/build-ios-app.sh", scratch]),
    ]))
