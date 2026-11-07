"""Run the real display/boot preparation; identity is verified in actual UI cases."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
OWNED = "00000000-0000-0000-0000-000000000001"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"


class SimulatorFrontendTests(unittest.TestCase):
    def bootstrap(self, frontend, *, failure="", override=True):
        with tempfile.TemporaryDirectory(prefix="takupoke-frontend-") as directory:
            root = Path(directory)
            (root / "tools").mkdir()
            (root / "bin").mkdir()
            for name in ("boot-simulator-ui.sh", "timed_command.py"):
                shutil.copyfile(ROOT / "tools" / name, root / "tools" / name)
            developer = root / "selected/Contents/Developer"
            developer.mkdir(parents=True)
            app = (developer / "Applications/Simulator.app" if frontend == "legacy" else
                   developer.parent / "Applications/DeviceHub.app")
            if frontend not in ("missing", "headless", "unknown"):
                app.mkdir(parents=True)
            fake = "#!" + sys.executable + "\n" + r"""
import json,os,sys
from pathlib import Path
args=sys.argv[1:];name=Path(sys.argv[0]).name
with open(os.environ['CALLS'],'a') as output: output.write(json.dumps([name]+args)+'\n')
failure=os.environ['FAILURE']
if name=='xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif name=='open':
    if failure=='frontend':sys.exit(43)
    if failure=='window' and any(arg.startswith('devices://') for arg in args):sys.exit(44)
elif args[:2]==['simctl','boot'] and failure=='boot':sys.exit(42)
elif args[:2]==['simctl','bootstatus'] and failure=='bootstatus':sys.exit(47)
elif args[:2] in (['simctl','list'],['simctl','spawn']):raise AssertionError('No independent preflight process or inventory')
"""
            for name in ("open", "xcrun", "xcode-select"):
                path = root / "bin" / name
                path.write_text(fake)
                path.chmod(0o755)
            calls = root / "calls"
            environment = os.environ | {"PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
                "CALLS": str(calls), "FAILURE": failure,
                "TKPK_SIMULATOR_FRONTEND": "headless" if frontend == "headless" else "unknown" if frontend == "unknown" else "gui",
                "SYNTHETIC_DEVELOPER": str(root / "wrong" if override else developer)}
            if override:
                environment["DEVELOPER_DIR"] = str(developer)
            else:
                environment.pop("DEVELOPER_DIR", None)
            result = subprocess.run(["bash", "tools/boot-simulator-ui.sh", OWNED, RUNTIME, "Fictional bootstrap"],
                                    cwd=root, env=environment, text=True, capture_output=True, timeout=12)
            recorded = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
            self.assertEqual(sum(call[:3] == ["xcrun", "simctl", "boot"] for call in recorded),
                             0 if frontend == "unknown" else 1)
            self.assertFalse(any(call[:3] in (["xcrun", "simctl", "shutdown"], ["xcrun", "simctl", "delete"],
                                              ["xcrun", "simctl", "launch"], ["xcrun", "simctl", "spawn"]) for call in recorded))
            self.assertNotIn("TAKUPOKE_OWNED_BOOT confirmed", result.stdout)
            return result, recorded, str(app)

    def test_selected_xcode_frontends_and_owned_window_preserve_boot_order(self):
        for frontend, override in (("legacy", True), ("hub", True), ("legacy", False)):
            with self.subTest(frontend=frontend, override=override):
                result, calls, app = self.bootstrap(frontend, override=override)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                boot = calls.index(["xcrun", "simctl", "boot", OWNED])
                status = calls.index(["xcrun", "simctl", "bootstatus", OWNED, "-b"])
                opens = [call for call in calls if call[0] == "open"]
                self.assertEqual(opens[0], ["open", "-a", app] + (["--args", "-CurrentDeviceUDID", OWNED] if frontend == "legacy" else []))
                self.assertLess(boot, calls.index(opens[0]))
                self.assertLess(calls.index(opens[0]), status)
                if frontend == "hub":
                    self.assertEqual(opens[1], ["open", "-a", app, "devices://device/open?id=" + OWNED])
                    self.assertLess(status, calls.index(opens[1]))
                self.assertEqual(len(opens), 2 if frontend == "hub" else 1)
                self.assertEqual(sum(call[0] == "xcode-select" for call in calls), int(not override))
                self.assertIn("stage=bootstatus-complete", result.stdout)

    def test_boot_frontend_window_errors_fail_without_retry(self):
        for failure, expected in (("boot", 42), ("frontend", 43), ("window", 44), ("bootstatus", 47)):
            with self.subTest(failure=failure):
                result, calls, _ = self.bootstrap("hub", failure=failure)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertNotIn("stage=bootstatus-complete", result.stdout)
        result, calls, _ = self.bootstrap("missing")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(call[0] == "open" or call[:3] == ["xcrun", "simctl", "bootstatus"] for call in calls))

    def test_headless_bootstatus_is_not_reported_as_completed_ui_execution(self):
        for failure, expected in (("", 0), ("boot", 42), ("bootstatus", 47)):
            with self.subTest(failure=failure):
                result, calls, _ = self.bootstrap("headless", failure=failure)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertFalse(any(call[0] in ("open", "xcode-select") for call in calls))
                self.assertEqual("stage=bootstatus-complete" in result.stdout, expected == 0)
                if expected == 0:
                    self.assertLess(calls.index(["xcrun", "simctl", "boot", OWNED]),
                                    calls.index(["xcrun", "simctl", "bootstatus", OWNED, "-b"]))
        result, calls, _ = self.bootstrap("unknown")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
