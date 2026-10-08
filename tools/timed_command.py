"""Measure a command while preserving live output and cancellation cleanup."""
import os
import signal
import subprocess
import sys
import time


def terminate_owned_group(process, grace=15):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait()
        return
    # wait() only observes the leader. A child can ignore TERM after its
    # leader has already exited, so observe the owned group independently.
    deadline = time.monotonic() + grace
    while True:
        process.poll()  # Reap our leader without mistaking it for the group.
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
        time.sleep(0.05)
    process.wait()


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
            terminate_owned_group(process)
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        print(f"TIMING finish: {label}, elapsed={time.monotonic() - started:.1f}s", flush=True)


if __name__ == "__main__":
    sys.exit(run(sys.argv[1], sys.argv[2:]))
