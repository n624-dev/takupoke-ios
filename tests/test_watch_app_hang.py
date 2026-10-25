"""Owned-process sampling, strict output filtering and observer lifecycle."""
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import watch_app_hang as module

SAMPLE = """Process: private-header
Call graph:
    100 Thread_123 DispatchQueue_1: com.apple.main-thread (serial)
    + 100 start (in dyld) + 20 [0x1234]
    +   100 sqlite3_step (in GRDBSQLite) + 30 [0x2345]
    +     100 /private/token/body (in Takupoke) + 40
    +     100 secret_symbol (in UnknownPrivateLibrary) + 40
    +     100 \"private body\" (in Takupoke) + 40
    100 Thread_456 DispatchQueue_2: private-worker (serial)
    + 100 worker_body (in Takupoke) + 20
"""


class AppHangObservationTests(unittest.TestCase):
    def test_main_thread_export_rejects_headers_paths_body_unknown_libraries_and_other_threads(self):
        self.assertEqual(module.main_thread_frames(SAMPLE), [
            {"library": "dyld", "symbol": "start"},
            {"library": "GRDBSQLite", "symbol": "sqlite3_step"},
        ])
        many = SAMPLE.split("    + 100 start", 1)[0] + "".join(
            f"    + 100 public_symbol_{i} (in Takupoke) + 1\n" for i in range(100))
        self.assertEqual(len(module.main_thread_frames(many)), 48)
        self.assertEqual(module.main_thread_frames("no recognized thread"), [])

    def test_process_mismatch_never_samples_or_exports_private_command_output(self):
        responses = [subprocess.CompletedProcess([], 0, "/owned/Takupoke.app\n", ""),
                     subprocess.CompletedProcess([], 0, "/another/private/app\n", "private token")]
        with patch.object(module, "observe_command", side_effect=responses) as command:
            result = module.collect("owned-device", 123)
        self.assertEqual(command.call_count, 2)
        self.assertEqual(result["status"], "process-mismatch-or-exited")
        self.assertFalse(result["executableMatches"])
        self.assertNotIn("private", json.dumps(result))

    def test_exact_owned_app_is_sampled_once_and_owned_raw_file_is_removed(self):
        sample_files = []

        def command(args, timeout, *, max_bytes):
            if args[0] == "xcrun":
                return subprocess.CompletedProcess(args, 0, "/owned/Takupoke.app\n", "")
            if args[0] == "ps":
                return subprocess.CompletedProcess(args, 0, "/owned/Takupoke.app/Takupoke\n", "")
            self.assertEqual(args[:4], ["sample", "123", "1", "10"])
            self.assertEqual(timeout, 5)
            path = Path(args[-1])
            sample_files.append(path)
            path.write_text(SAMPLE)
            return subprocess.CompletedProcess(args, 0, "private stdout", "private stderr")

        with patch.object(module, "observe_command", side_effect=command):
            result = module.collect("owned-device", 123)
        self.assertEqual(result["status"], "sampled")
        self.assertTrue(result["executableMatches"])
        self.assertEqual(len(result["frames"]), 2)
        self.assertEqual(len(sample_files), 1)
        self.assertFalse(sample_files[0].parent.exists())
        self.assertNotIn("private", json.dumps(result))

    def test_quiet_snapshot_samples_once_and_stop_marker_ends_observer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log, stop = root / "phase.log", root / "stop"
            log.write_text("Test Case '-[PickerTapChecks.ApplicationChecks " + module.TARGET_CASE + "]' started.\n"
                           "Requesting snapshot of accessibility hierarchy for app with pid 123\n")
            clock = [0.0]
            calls = []

            def sleep(_):
                clock[0] += 1
                if clock[0] == 6:
                    stop.touch()

            def collect(simulator, pid):
                calls.append((simulator, pid))
                return {"status": "observed"}

            output = io.StringIO()
            with patch.object(module.time, "monotonic", side_effect=lambda: clock[0]), \
                    patch.object(module.time, "sleep", side_effect=sleep), redirect_stdout(output):
                module.watch(log, stop, "owned-device", quiet=2, sample=collect)
            self.assertEqual(calls, [("owned-device", 123)])
            self.assertEqual(len(output.getvalue().splitlines()), 1)
            self.assertTrue(stop.exists())

    def test_only_rows_case_and_at_most_two_owned_processes_are_observed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log, stop = root / "phase.log", root / "stop"
            log.write_text("Test Case '-[PickerTapChecks.ApplicationChecks testOther]' started.\n"
                           "Requesting snapshot of accessibility hierarchy for app with pid 999\n")
            clock, calls = [0.0], []

            def sleep(_):
                clock[0] += 1
                if clock[0] in (3, 8, 13):
                    pid = {3:123, 8:124, 13:125}[clock[0]]
                    with log.open("a") as stream:
                        if clock[0] == 3:
                            stream.write("Test Case '-[PickerTapChecks.ApplicationChecks " + module.TARGET_CASE + "]' started.\n")
                        stream.write(f"Requesting snapshot of accessibility hierarchy for app with pid {pid}\n")
                if clock[0] == 20:
                    stop.touch()

            def collect(simulator, pid):
                calls.append(pid)
                return {"status": "observed"}

            with patch.object(module.time, "monotonic", side_effect=lambda: clock[0]), \
                    patch.object(module.time, "sleep", side_effect=sleep), redirect_stdout(io.StringIO()):
                module.watch(log, stop, "owned-device", quiet=2, sample=collect)
            self.assertEqual(calls, [123, 124])

    def test_no_snapshot_or_finished_phase_does_not_sample(self):
        for text in ["private text\n", "Requesting snapshot of accessibility hierarchy for app with pid 0\n",
                     "Requesting snapshot of accessibility hierarchy for app with pid 123456789\n"]:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                log, stop = root / "phase.log", root / "stop"
                log.write_text(text)
                clock = [0.0]

                def sleep(_):
                    clock[0] += 1
                    if clock[0] == 5:
                        stop.touch()

                with patch.object(module.time, "monotonic", side_effect=lambda: clock[0]), \
                        patch.object(module.time, "sleep", side_effect=sleep), \
                        patch.object(module, "collect") as collect:
                    module.watch(log, stop, "owned-device", quiet=2, sample=collect)
                collect.assert_not_called()

    def test_normal_runner_collects_current_input_format_without_unrelated_body(self):
        source = (ROOT / "tools/test-app-ui.sh").read_text()
        script = source.split("<<'PY_TRACE'\n", 1)[1].split("\nPY_TRACE", 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            container = root / "container"
            (container / "tmp").mkdir(parents=True)
            lifecycle = "TAKUPOKE_LIFECYCLE pid=123 time=42.0 stage=fixture-ready"
            delivery = "TAKUPOKE_INPUT pid=123 time=43.0 phase=ended x=30.00 y=40.00 views=UIKit.UIView gestures=Tap:3:1:0:1"
            (container / "tmp/takupoke-fictional-launch-owned.log").write_text(
                lifecycle + "\n" + delivery + "\nprivate unrelated body\n")
            binary = root / "xcrun"
            binary.write_text("#!" + sys.executable + "\nprint(" + repr(str(container)) + ")\n")
            binary.chmod(0o700)
            result = subprocess.run([sys.executable, "-B", "-", "owned-device"], input=script,
                                    cwd=ROOT, env=os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"]},
                                    text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [lifecycle, delivery])


if __name__ == "__main__":
    unittest.main()
