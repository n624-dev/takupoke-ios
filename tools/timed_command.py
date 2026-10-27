"""Measure a command while preserving live output and cancellation cleanup."""
import argparse
import math
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


def run(label, command, cleanup_grace=15, timeout=None):
    started = time.monotonic()
    previous = {}
    process = None
    interruption = None
    cleaning = False
    print(f"TIMING start: {label}", flush=True)

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
        process = subprocess.Popen(command, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            print(f"TIMING timeout: {label}, limit={timeout:g}s", flush=True)
            return 124
        return code if code >= 0 else 128 - code
    finally:
        cleaning = True
        try:
            if process is not None:
                terminate_owned_group(process, grace=cleanup_grace)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
            print(f"TIMING finish: {label}, elapsed={time.monotonic() - started:.1f}s", flush=True)
        if interruption is not None:
            raise SystemExit(interruption)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float)
    parser.add_argument("--cleanup-grace", type=float, default=15)
    parser.add_argument("label")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or any(value is not None and (not math.isfinite(value) or value <= 0)
                               for value in (args.timeout, args.cleanup_grace)):
        parser.error("a command and finite positive time limits are required")
    sys.exit(run(args.label, args.command, timeout=args.timeout, cleanup_grace=args.cleanup_grace))
