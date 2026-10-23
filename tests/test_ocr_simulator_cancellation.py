"""Execute the real owned-device try/finally with fictional Apple command boundaries."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix", "POSIX research-runner cancellation")
class OCRSimulatorCancellationTests(unittest.TestCase):
    def test_term_during_create_and_boot_removes_only_the_owned_device(self):
        probe = r'''import ast, importlib.util, sys, time
from pathlib import Path
from types import SimpleNamespace
path, root, stage = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
spec = importlib.util.spec_from_file_location("owned_comparison", path)
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
def record(value):
    with (root / "calls").open("a") as stream: stream.write(value + "\n")
def wait_release():
    deadline = time.monotonic() + 8
    while not (root / "release").exists() and time.monotonic() < deadline: time.sleep(.01)
    if not (root / "release").exists(): raise RuntimeError("owned probe release timed out")
def command(*args, **kwargs):
    if args[:3] == ("xcrun", "simctl", "create"):
        record("create")
        if stage == "create": (root / "ready").touch(); wait_release()
        return "owned-fictional-id"
    if args == ("xcode-select", "-p"): return str(root)
    if args[:3] == ("xcrun", "simctl", "shutdown"):
        assert args[3] == "owned-fictional-id"
        record("shutdown")
        if stage == "boot": (root / "shutdown-ready").touch(); wait_release()
        return ""
    if args[:3] == ("xcrun", "simctl", "delete"):
        assert args[3] == "owned-fictional-id"
        record("delete"); return ""
    raise RuntimeError("Unexpected fictional command")
def boot(identity, developer):
    assert identity == "owned-fictional-id"
    (root / "ready").touch()
    time.sleep(30)
module.command = command; module.boot_owned_simulator = boot
if hasattr(module, "shared"): module.shared.command = command
module.args = SimpleNamespace(study=root)
module.runtime = {"identifier": "fictional-runtime", "version": "26.5"}
module.device = {"identifier": "fictional-device"}
main = next(node for node in ast.parse(path.read_text()).body if isinstance(node, ast.FunctionDef) and node.name == "main")
owned_try = next(node for node in main.body if isinstance(node, ast.Try) and any(
    isinstance(item, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "owned" for target in item.targets) for item in node.body))
prefix = [node for node in main.body[:main.body.index(owned_try)] if isinstance(node, ast.Assign) and any(
    isinstance(target, ast.Name) and target.id in {"owned", "process", "cancel_scope"} for target in node.targets)]
# Use the unchanged product try/finally and its real shared shutdown/delete.
exec(compile(ast.Module(body=prefix + [owned_try], type_ignores=[]), str(path), "exec"), module.__dict__)
'''
        for folder in ["ocr-ios-runtime-parity", "ocr-ios-ascii-runtime-parity"]:
            for stage in ["create", "boot"]:
                with self.subTest(program=folder, stage=stage), tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    process = subprocess.Popen([sys.executable, "-c", probe, str(ROOT / "tools" / folder / "compare.py"), str(root), stage],
                                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                    try:
                        deadline = time.monotonic() + 5
                        while not (root / "ready").exists() and process.poll() is None and time.monotonic() < deadline: time.sleep(.01)
                        self.assertTrue((root / "ready").exists(), "The real owned try must reach the controlled stage")
                        process.send_signal(signal.SIGTERM)
                        if stage == "boot":
                            deadline = time.monotonic() + 5
                            while not (root / "shutdown-ready").exists() and process.poll() is None and time.monotonic() < deadline: time.sleep(.01)
                            if process.poll() is None: process.send_signal(signal.SIGINT)
                        (root / "release").touch()
                        output, _ = process.communicate(timeout=6)
                        self.assertEqual(process.returncode, 143, output)
                        self.assertEqual((root / "calls").read_text().splitlines(), ["create", "shutdown", "delete"])
                    finally:
                        if process.poll() is None: process.kill()
                        process.communicate(timeout=5)
