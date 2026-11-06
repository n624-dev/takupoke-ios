"""Execute the real shared bootstrap with isolated, stateful Apple command doubles."""
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
            for name in ("boot-simulator-ui.sh", "timed_command.py", "notification_service_trace.py", "simulator-ui-identity.swift"):
                shutil.copyfile(ROOT / "tools" / name, root / "tools" / name)
            developer = root / "selected/Contents/Developer"
            developer.mkdir(parents=True)
            if frontend == "legacy":
                app = developer / "Applications/Simulator.app"
            else:
                app = developer.parent / "Applications/DeviceHub.app"
            if frontend != "missing":
                app.mkdir(parents=True)
            fake = "#!" + sys.executable + "\n" + r'''
import json,os,sys
from pathlib import Path
args=sys.argv[1:];name=Path(sys.argv[0]).name
with open(os.environ['CALLS'],'a') as output: output.write(json.dumps([name]+args)+'\n')
failure=os.environ['FAILURE']
if name=='xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif name=='codesign':
    assert Path(args[-1]).is_file()
    if failure=='sign':sys.exit(46)
elif name=='open':
    if failure=='frontend':sys.exit(43)
    if failure=='window' and any(arg.startswith('devices://') for arg in args):sys.exit(44)
elif args[:2]==['simctl','boot'] and failure=='boot':sys.exit(42)
elif args[:2]==['simctl','bootstatus'] and failure=='bootstatus':sys.exit(47)
elif args[:3]==['--sdk','iphonesimulator','--show-sdk-path']:print('/fictional/sdk')
elif args[:3]==['--sdk','iphonesimulator','swiftc']:
    if failure=='compile':sys.exit(41)
    assert Path('tools/simulator-ui-identity.swift').is_file()
    Path(args[args.index('-o')+1]).write_text('fictional probe')
elif args[:2]==['simctl','spawn']:
    if failure=='spawn':sys.exit(48)
    assert args[2]==os.environ['OWNED'] and args[-1].endswith('/identity')
    print(json.dumps({'udid':os.environ['OWNED'],'runtime':'26.5.0' if failure=='identity' else '27.0.0',
        'simulatorCompileTarget':True,'pid':123}))
elif args[:2]==['simctl','list']:raise AssertionError('Readiness must not use inventory')
'''
            for name in ("open", "xcrun", "xcode-select", "codesign"):
                path = root / "bin" / name
                path.write_text(fake)
                path.chmod(0o755)
            calls = root / "calls"
            environment = os.environ | {"PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
                "CALLS": str(calls), "FAILURE": failure, "TMPDIR": directory,
                "OWNED": OWNED, "RUNTIME": RUNTIME,
                "SYNTHETIC_DEVELOPER": str(root / "wrong" if override else developer)}
            if override:
                environment["DEVELOPER_DIR"] = str(developer)
            else:
                environment.pop("DEVELOPER_DIR", None)
            result = subprocess.run(["bash", "tools/boot-simulator-ui.sh", OWNED, RUNTIME, "Fictional bootstrap"],
                                    cwd=root, env=environment, text=True, capture_output=True, timeout=12)
            recorded = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertNotIn("PRIVATE", result.stdout + result.stderr)
            self.assertEqual(sum(call[:3] == ["xcrun", "simctl", "boot"] for call in recorded),
                             0 if failure in ("compile", "sign") else 1)
            self.assertEqual(list(root.glob("takupoke-ui-identity.*")), [])
            self.assertFalse(any(call[:3] in (["xcrun", "simctl", "shutdown"], ["xcrun", "simctl", "delete"],
                                              ["xcrun", "simctl", "launch"]) for call in recorded))
            return result, recorded, str(app)

    def test_selected_xcode_frontends_and_owned_window_are_ready_before_returning(self):
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
                self.assertFalse(any(call[:3] == ["xcrun", "simctl", "list"] for call in calls))
                compiler = next(i for i, call in enumerate(calls) if call[:4] == ["xcrun", "--sdk", "iphonesimulator", "swiftc"])
                self.assertLess(compiler, boot)
                self.assertIn("-module-cache-path", calls[compiler])
                observations = [i for i, call in enumerate(calls) if call[:3] == ["xcrun", "simctl", "spawn"]]
                self.assertEqual(len(observations), 1)
                self.assertLess(status, observations[0])
                if frontend == "hub":
                    self.assertEqual(opens[1], ["open", "-a", app, "devices://device/open?id=" + OWNED])
                    self.assertLess(status, calls.index(opens[1]))
                    self.assertLess(calls.index(opens[1]), observations[0])
                else:
                    self.assertEqual(len(opens), 1)
                self.assertEqual(sum(call[0] == "xcode-select" for call in calls), int(not override))
                self.assertIn("TAKUPOKE_OWNED_BOOT confirmed", result.stdout)

    def test_boot_frontend_window_and_readiness_errors_fail_without_another_boot(self):
        for failure, expected in (("compile", 41), ("sign", 46), ("boot", 42), ("frontend", 43), ("window", 44),
                                  ("bootstatus", 47), ("identity", 1), ("spawn", 1)):
            with self.subTest(failure=failure):
                result, calls, _ = self.bootstrap("hub", failure=failure)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertNotIn("TAKUPOKE_SIMULATOR_UI stage=ready", result.stdout)
                self.assertFalse(any(call[:3] == ["xcrun", "simctl", "list"] for call in calls))
        result, calls, _ = self.bootstrap("missing")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(call[0] == "open" or call[:3] == ["xcrun", "simctl", "bootstatus"] for call in calls))


if __name__ == "__main__":
    unittest.main()
