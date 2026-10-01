import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

TOOL = Path(__file__).resolve().parents[1] / "tools/timed_command.py"


class TimedCommandTests(unittest.TestCase):
    def test_child_output_and_exit_status_are_preserved(self):
        result = subprocess.run([sys.executable, str(TOOL), "synthetic stage", sys.executable,
                                 "-c", "print('synthetic output'); raise SystemExit(7)"],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 7)
        self.assertLess(result.stdout.index("TIMING start"), result.stdout.index("synthetic output"))
        self.assertLess(result.stdout.index("synthetic output"), result.stdout.index("TIMING finish"))
        self.assertIn("elapsed=", result.stdout)

    @unittest.skipUnless(os.name == "posix", "macOS process groups")
    def test_cancellation_reaches_child_and_allows_its_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            ready, cleaned = Path(directory) / "ready", Path(directory) / "cleaned"
            script = """
import signal, sys, time
from pathlib import Path
def stop(*_):
    Path(sys.argv[2]).touch()
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
Path(sys.argv[1]).touch()
time.sleep(30)
"""
            process = subprocess.Popen([sys.executable, str(TOOL), "synthetic cancellation",
                sys.executable, "-c", script, str(ready), str(cleaned)], stdout=subprocess.DEVNULL)
            try:
                deadline = time.monotonic() + 5
                while not ready.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(ready.exists())
                process.send_signal(signal.SIGTERM)
                self.assertEqual(process.wait(timeout=5), 143)
                self.assertTrue(cleaned.exists())
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
