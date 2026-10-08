import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import importlib.util

TOOL = Path(__file__).resolve().parents[1] / "tools/timed_command.py"


@unittest.skipUnless(os.name == "posix", "macOS CI process groups")
class TimedCommandTests(unittest.TestCase):
    def test_exited_leader_does_not_leave_term_ignoring_descendant_running(self):
        spec = importlib.util.spec_from_file_location("owned_timing", TOOL)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            ready = Path(directory) / "child-ready"
            child = "import signal,time,os; from pathlib import Path; signal.signal(signal.SIGTERM,signal.SIG_IGN); p=Path(" + repr(str(ready)) + "); tmp=p.with_suffix('.pending'); tmp.write_text(str(os.getpid())); tmp.replace(p); time.sleep(30)"
            parent = "import subprocess,sys,time; from pathlib import Path; subprocess.Popen([sys.executable,'-c',sys.argv[1]]); p=Path(sys.argv[2]); deadline=time.monotonic()+5\nwhile not p.exists() and time.monotonic()<deadline: time.sleep(.01)\nraise SystemExit(7)"
            leader = subprocess.Popen([sys.executable, "-c", parent, child, str(ready)], start_new_session=True)
            child_pid = None
            try:
                self.assertEqual(leader.wait(timeout=7), 7)
                self.assertTrue(ready.exists())
                child_pid = int(ready.read_text())
                os.kill(child_pid, 0)
                module.terminate_owned_group(leader, grace=0.2)
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    state = subprocess.run(["ps", "-o", "stat=", "-p", str(child_pid)], capture_output=True, text=True).stdout.strip()
                    if not state or state.startswith("Z"):
                        break  # A zombie has stopped; its parent is already reaped.
                    time.sleep(0.02)
                self.assertTrue(not state or state.startswith("Z"), "Owned descendant is still running")
                self.assertEqual(leader.returncode, 7)
            finally:
                # Even a failure before reading child-ready must reclaim the
                # complete process group created by this test.
                try: os.killpg(leader.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                leader.wait()

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
