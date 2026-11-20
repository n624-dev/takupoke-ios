"""Forward only the owned fixture's numeric and fixed-stage events to the job log."""
import argparse
import json
import os
import re
import selectors
import signal
import subprocess
import time
import uuid

SUBSYSTEM = "jp.n624.takupoke.ci"
CATEGORY = "simulator"
DECIMAL = r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"
EVENT = re.compile(
    rf"CI_SIMULATOR_EVENT pid=([0-9]{{1,10}}) seq=([0-9]{{1,20}}) time={DECIMAL} uptime={DECIMAL} "
    rf"(?:stage=[a-z0-9-]{{1,64}}|delivered=\d+|dispatch=\d+ "
    rf"(?:touch=\d+ phase=\d+ event={DECIMAL} x={DECIMAL} y={DECIMAL}|"
    rf"(?:press|event-type)=\d+ event={DECIMAL}))"
)


def fixture_event(line):
    """Return an allowlisted event and its ordering keys, never raw host output."""
    if len(line) > 8192:
        return None
    try:
        record = json.loads(line)
    except (UnicodeError, ValueError):
        return None
    if not isinstance(record, dict) or record.get("subsystem") != SUBSYSTEM or record.get("category") != CATEGORY:
        return None
    event = record.get("eventMessage")
    if not isinstance(event, str):
        return None
    match = EVENT.fullmatch(event)
    if not match:
        return None
    return int(match[1]), int(match[2]), event


def forward(simulator):
    last_sequence = {}
    received = 0
    stop_at = None
    command = ["xcrun", "simctl", "spawn", simulator, "log", "stream", "--style", "ndjson",
               "--level", "info", "--predicate", f'subsystem == "{SUBSYSTEM}" AND category == "{CATEGORY}"']
    print(f"CI_SIMULATOR_TRACE state=start simulator={simulator}", flush=True)
    try:
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        print(f"CI_SIMULATOR_TRACE state=unavailable simulator={simulator}", flush=True)
        return

    def request_stop(_signum, _frame):
        nonlocal stop_at
        if stop_at is None:
            stop_at = time.monotonic() + 0.5

    def signal_owned_group(signum):
        try:
            os.killpg(child.pid, signum)
        except ProcessLookupError:
            pass

    previous = {signum: signal.signal(signum, request_stop) for signum in (signal.SIGINT, signal.SIGTERM)}
    try:
        with child.stdout as stream, selectors.DefaultSelector() as selector:
            selector.register(stream, selectors.EVENT_READ)
            incomplete = b""
            discarding = False
            while stop_at is None or time.monotonic() < stop_at:
                if not selector.select(timeout=0.25):
                    continue
                chunk = os.read(stream.fileno(), 65536)
                if not chunk:
                    break
                if discarding:
                    _, separator, chunk = chunk.partition(b"\n")
                    if not separator:
                        continue
                    discarding = False
                *lines, incomplete = (incomplete + chunk).split(b"\n")
                if len(incomplete) > 8192:
                    incomplete = b""
                    discarding = True
                for raw in lines:
                    event = fixture_event(raw)
                    if event is None:
                        continue
                    pid, sequence, message = event
                    prior = last_sequence.get(pid, 0)
                    if sequence > prior + 1:
                        print(f"CI_SIMULATOR_TRACE state=sequence-gap pid={pid} after={prior} next={sequence}", flush=True)
                    last_sequence[pid] = max(prior, sequence)
                    print(message, flush=True)
                    received += 1
    finally:
        signal_owned_group(signal.SIGTERM)
        try:
            status = child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            signal_owned_group(signal.SIGKILL)
            status = child.wait()
        for signum, handler in previous.items():
            signal.signal(signum, handler)
        state = "stopped" if stop_at is not None else "ended"
        print(f"CI_SIMULATOR_TRACE state={state} simulator={simulator} exit={status} records={received}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("simulator", type=lambda value: str(uuid.UUID(value)).upper())
    forward(parser.parse_args().simulator)
