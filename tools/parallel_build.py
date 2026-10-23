"""Run isolated commands with live logs and process-group cleanup."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time


def run_commands(commands, cleanup_grace=15):
    processes = []
    readers = []
    started = time.monotonic()
    previous = {}
    output_lock = threading.Lock()
    interruption = None
    cleaning = False

    def forward(name, stream):
        for line in stream:
            with output_lock:
                print(f"[{name}] {line}", end="", flush=True)
        stream.close()

    def interrupted(signum, _frame):
        nonlocal interruption
        if interruption is not None:
            return
        interruption = 128 + signum
        if not cleaning:
            raise SystemExit(interruption)

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
        cleaning = True
        try:
            # Observe each owned group even if its leader has already exited.
            for _, process in processes:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            deadline = time.monotonic() + cleanup_grace
            for _, process in processes:
                while True:
                    process.poll()
                    try:
                        os.killpg(process.pid, 0)
                    except ProcessLookupError:
                        break
                    if time.monotonic() >= deadline:
                        try:
                            os.killpg(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        break
                    time.sleep(.05)
                process.wait()
            for reader in readers:
                reader.join(timeout=3)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        if interruption is not None:
            raise SystemExit(interruption)


if __name__ == "__main__":
    scratch = str(Path(sys.argv[1]).resolve())
    # The Files view service and accessibility snapshots need the runner while
    # the picker is live. Do not compete with host Swift compilation here.
    for command in [
        ("Picker UI", ["bash", "tools/test-picker-ui.sh"]),
        ("Host tests and iPhone build", ["bash", "tools/build-ios-app.sh", scratch]),
    ]:
        status = run_commands([command])
        if status:
            sys.exit(status)
