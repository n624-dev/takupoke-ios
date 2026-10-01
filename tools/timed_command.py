"""Measure a command while preserving live output and cancellation cleanup."""
import os
import signal
import subprocess
import sys
import time


def run(label, command):
    started = time.monotonic()
    previous = {}
    process = None
    print(f"TIMING start: {label}", flush=True)

    def interrupted(signum, _frame):
        raise SystemExit(128 + signum)

    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, interrupted)
        process = subprocess.Popen(command, start_new_session=True)
        code = process.wait()
        return code if code >= 0 else 128 - code
    finally:
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        print(f"TIMING finish: {label}, elapsed={time.monotonic() - started:.1f}s", flush=True)


if __name__ == "__main__":
    sys.exit(run(sys.argv[1], sys.argv[2:]))
