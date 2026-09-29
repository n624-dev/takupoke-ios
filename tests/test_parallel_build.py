import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("parallel_build", Path(__file__).resolve().parents[1] / "tools/parallel_build.py")
parallel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parallel)


@unittest.skipUnless(os.name == "posix", "macOS CI process groups")
class ParallelBuildTests(unittest.TestCase):
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
