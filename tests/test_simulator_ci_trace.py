"""Verify live Simulator diagnostics and their public output boundary with a command double."""
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from simulator_ci_trace import CATEGORY, SUBSYSTEM, fixture_event

DEVICE = "11111111-1111-4111-8111-111111111111"
PREFIX = "CI_SIMULATOR_EVENT pid={} seq={} time=1795153028.100 uptime=1423.123456 "


def event(sequence, payload, *, pid=482, **metadata):
    record = {"subsystem": SUBSYSTEM, "category": CATEGORY, "eventMessage": PREFIX.format(pid, sequence) + payload}
    return json.dumps(record | metadata).encode()


class SimulatorCITraceTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler for log interpolation type check")
    def test_fixture_output_compiles_with_escaping_log_interpolation(self):
        source = (ROOT / "tests/ui/ApplicationFixture+CITrace.swift").read_text(encoding="utf-8")
        start = source.index("private final class FixtureCITraceOutput:")
        end = source.index("// Compiled only into", start)
        # Apple Logger defers evaluating interpolation. Preserve that compiler
        # constraint when testing the actual output class without the Apple SDK.
        log_interface = """
import Foundation

private enum LogPrivacy { case `public` }
private struct LogMessage: ExpressibleByStringInterpolation {
    struct StringInterpolation: StringInterpolationProtocol {
        init(literalCapacity: Int, interpolationCount: Int) {}
        mutating func appendLiteral(_ value: String) {}
        mutating func appendInterpolation<T>(_ value: @autoclosure @escaping () -> T) {}
        mutating func appendInterpolation(_ value: @autoclosure @escaping () -> String, privacy: LogPrivacy) {}
    }
    init(stringLiteral value: String) {}
    init(stringInterpolation: StringInterpolation) {}
}

private struct Logger {
    init(subsystem: String, category: String) {}
    func notice(_ message: LogMessage) {}
}
"""
        with tempfile.TemporaryDirectory(prefix="takupoke-log-interpolation-") as temporary:
            file = Path(temporary) / "Output.swift"
            file.write_text(log_interface + source[start:end], encoding="utf-8")
            result = subprocess.run(["swiftc", "-typecheck", "-module-cache-path", str(file.parent / "modules"),
                                     str(file)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_parses_fixed_fields_and_rejects_unrelated_or_unstructured_output(self):
        payloads = (
            "stage=fixture-ready",
            "dispatch=2 touch=1 phase=2 event=1423.61 x=162.50 y=62.33",
            "dispatch=3 press=1 event=1.6e+03",
            "dispatch=4 event-type=10 event=42.33",
            "delivered=4",
        )
        for number, payload in enumerate(payloads, 1):
            with self.subTest(payload=payload):
                self.assertEqual(fixture_event(event(number, payload)), (482, number, PREFIX.format(482, number) + payload))
        for record in (
            b"raw host log", b"[]", b"\xff", event(1, "stage=fixture-ready", subsystem="com.apple.UIKit"),
            event(1, "stage=fixture-ready", category="other"), event(1, "stage=invalid /fictional/path"),
            event(1, "dispatch=3 press=1 event=NaN"), event(1, "stage=fixture-ready\nraw"),
            event(1, "stage=fixture-ready", extra="x" * 8192),
        ):
            self.assertIsNone(fixture_event(record))

    @unittest.skipUnless(os.name == "posix", "Simulator command process groups")
    def test_streams_over_128_events_while_owned_command_runs_and_stops_it(self):
        with tempfile.TemporaryDirectory(prefix="takupoke-simulator-ci-trace-") as temporary:
            root = Path(temporary)
            fixture = root / "records.jsonl"
            fixture.write_bytes(b"\n".join([
                event(1, "stage=fixture-ready"), event(1, "stage=event-observer-installed", pid=483), b"x" * 66000,
                event(2, "stage=fictional-secret /path"),
                *(event(i, f"dispatch={i} touch=1 phase=1 event=1423.61 x=162.50 y=62.33")
                  for i in range(3, 260)),
            ]) + b"\n")
            fake = root / "xcrun"
            fake.write_text("#!" + sys.executable + "\n" + """
import os, sys, time
from pathlib import Path
assert sys.argv[1:9] == ['simctl', 'spawn', os.environ['SIMULATOR'], 'log', 'stream', '--style', 'ndjson', '--level']
assert sys.argv[9:] == ['info', '--predicate', 'subsystem == "jp.n624.takupoke.ci" AND category == "simulator"']
Path(os.environ['PID_FILE']).write_text(str(os.getpid()))
sys.stdout.buffer.write(Path(os.environ['RECORDS']).read_bytes())
sys.stdout.buffer.flush()
while True: time.sleep(1)
""")
            fake.chmod(0o755)
            pid_file = root / "pid"
            env = os.environ | {"PATH": temporary + os.pathsep + os.environ["PATH"],
                                "RECORDS": str(fixture), "SIMULATOR": DEVICE, "PID_FILE": str(pid_file)}
            with subprocess.Popen([sys.executable, "-B", "tools/simulator_ci_trace.py", DEVICE],
                                  cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    result = b""
                    try:
                        while b"seq=259 " not in result:
                            self.assertTrue(selector.select(timeout=3), result[-300:])
                            chunk = os.read(process.stdout.fileno(), 65536)
                            self.assertTrue(chunk, result[-300:])
                            result += chunk
                        self.assertIsNone(process.poll())
                    finally:
                        process.send_signal(signal.SIGTERM)
                        stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(stderr, b"")
            log = (result + stdout).decode()
            self.assertIn("state=sequence-gap pid=482 after=1 next=3", log)
            self.assertIn("state=observer-install-unseen pid=482", log)
            self.assertNotIn("state=observer-install-unseen pid=483", log)
            self.assertIn(f"state=stopped simulator={DEVICE} exit=-15 records=259", log)
            self.assertNotIn("fictional-secret", log)
            with self.assertRaises(ProcessLookupError):
                os.kill(int(pid_file.read_text()), 0)


if __name__ == "__main__":
    unittest.main()
