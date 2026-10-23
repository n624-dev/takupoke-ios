import importlib.util
import contextlib
import io
import os
import signal
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("parallel_build", Path(__file__).resolve().parents[1] / "tools/parallel_build.py")
parallel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parallel)


@unittest.skipUnless(os.name == "posix", "macOS CI process groups")
class ParallelBuildTests(unittest.TestCase):
    def test_exited_leader_cannot_leave_a_term_ignoring_descendant(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "child-ready"
            child = "import os,signal,sys,time; from pathlib import Path; signal.signal(signal.SIGTERM,signal.SIG_IGN); Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(30)"
            parent = "import subprocess,sys,time; from pathlib import Path; subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]); p=Path(sys.argv[2]); deadline=time.monotonic()+5; exec('while not p.exists() and time.monotonic()<deadline: time.sleep(.01)'); sys.exit(7 if p.exists() else 8)"
            pid = None
            try:
                result = parallel.run_commands([("owned-parent", [sys.executable, "-c", parent, child, str(marker)])], cleanup_grace=.2)
                self.assertEqual(result, 7)
                pid = int(marker.read_text())
                state = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
                self.assertTrue(not state or state.startswith("Z"), "A descendant is still executing after cleanup")
            finally:
                if marker.exists():
                    pid = int(marker.read_text())
                    try: os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError: pass

    def test_child_logs_keep_their_labels(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = parallel.run_commands([
                ("first", [sys.executable, "-c", "print('first output')"]),
                ("second", [sys.executable, "-c", "print('second output')"]),
            ])
        self.assertEqual(result, 0)
        self.assertIn("[first] first output", output.getvalue())
        self.assertIn("[second] second output", output.getvalue())

    def test_both_commands_start_before_either_finishes(self):
        with tempfile.TemporaryDirectory() as directory:
            commands = []
            for own, other in [("a", "b"), ("b", "a")]:
                script = """
from pathlib import Path
import sys, time
root = Path(sys.argv[1])
(root / sys.argv[2]).touch()
for _ in range(100):
    if (root / sys.argv[3]).exists():
        break
    time.sleep(.02)
else:
    sys.exit(3)
"""
                commands.append((own, [sys.executable, "-c", script, directory, own, other]))
            self.assertEqual(parallel.run_commands(commands), 0)

    def test_failure_stops_peer_and_propagates_status(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "ready"
            stopped = Path(directory) / "stopped"
            peer = """
import signal, sys, time
from pathlib import Path
def stop(*_):
    Path(sys.argv[2]).touch()
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
Path(sys.argv[1]).touch()
time.sleep(30)
"""
            failing = """
import sys, time
from pathlib import Path
for _ in range(100):
    if Path(sys.argv[1]).exists():
        sys.exit(7)
    time.sleep(.02)
sys.exit(8)
"""
            result = parallel.run_commands([
                ("peer", [sys.executable, "-c", peer, str(marker), str(stopped)]),
                ("failure", [sys.executable, "-c", failing, str(marker)]),
            ])
            self.assertEqual(result, 7)
            self.assertTrue(stopped.exists())
