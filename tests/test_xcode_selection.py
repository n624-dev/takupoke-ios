"""Exercise the real CI selector without mutating this machine's Xcode state."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "tools/select-ci-xcode.py"


class XcodeSelectionTests(unittest.TestCase):
    def select(self, *, mode="normal", alias=False, overrides=None):
        with tempfile.TemporaryDirectory(prefix="takupoke-xcode-selection-") as directory:
            root = Path(directory)
            old = root / "Xcode_27.1.app/Contents/Developer"
            old.mkdir(parents=True)
            installed = root / ("Xcode_27.2_Release_Candidate.app" if alias else "Xcode_27.2.app")
            (installed / "Contents/Developer").mkdir(parents=True)
            if alias:
                (root / "Xcode_27.2.app").symlink_to(installed, target_is_directory=True)
            selected = root / "Xcode_27.2.app/Contents/Developer"
            state = root / "system-selection"
            state.write_text(str(old))
            calls = root / "calls"
            fake = "#!" + sys.executable + "\n" + r'''
import json,os,sys
from pathlib import Path
args=sys.argv[1:]; name=Path(sys.argv[0]).name
with open(os.environ['CALLS'],'a') as output:
    output.write(json.dumps({'tool':name,'args':args,'overridePresent':'DEVELOPER_DIR' in os.environ})+'\n')
if name=='sudo':
    assert args[:2]==['-n','xcode-select']
    executable=str(Path(sys.argv[0]).parent/'xcode-select')
    os.execv(executable,[executable]+args[2:])
state=Path(os.environ['SYSTEM_SELECTION']); mode=os.environ['MODE']
if args==['--print-path']:
    if mode=='query-error': sys.exit(19)
    print(os.environ.get('DEVELOPER_DIR',state.read_text()))
elif len(args)==2 and args[0]=='--switch':
    if mode=='switch-error': sys.exit(17)
    state.write_text(os.environ['OLD_SELECTION'] if mode=='mismatch' else str(Path(args[1]).resolve()))
else: sys.exit(99)
'''
            for name in ("sudo", "xcode-select"):
                path = root / name
                path.write_text(fake)
                path.chmod(0o700)
            env = os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"],
                "GITHUB_ACTIONS": "true", "RUNNER_OS": "macOS", "DEVELOPER_DIR": str(selected),
                "CALLS": str(calls), "SYSTEM_SELECTION": str(state), "OLD_SELECTION": str(old), "MODE": mode}
            env.update(overrides or {})
            result = subprocess.run([sys.executable, "-B", str(HELPER)], env=env,
                                    capture_output=True, text=True, timeout=10)
            observed = [json.loads(row) for row in calls.read_text().splitlines()] if calls.exists() else []
            return result, observed, state.read_text(), str(selected.resolve()), str(old)

    def test_actual_system_selection_is_verified_without_the_environment_override(self):
        for alias in (False, True):
            with self.subTest(alias=alias):
                result, calls, actual, expected, _ = self.select(alias=alias)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(actual, expected)
                self.assertEqual(sum(c["tool"] == "sudo" for c in calls), 1)
                queries = [c for c in calls if c["args"] == ["--print-path"]]
                self.assertEqual(len(queries), 2)
                self.assertTrue(all(not c["overridePresent"] for c in queries))
                self.assertIn("confirmed=true", result.stdout)
                self.assertIn("previous=Xcode_27.1.app", result.stdout)

    def test_untrusted_context_or_missing_selection_is_rejected_before_mutation(self):
        for values in ({"GITHUB_ACTIONS": "false"}, {"RUNNER_OS": "Linux"},
                       {"DEVELOPER_DIR": "relative/Contents/Developer"}, {"DEVELOPER_DIR": ""},
                       {"DEVELOPER_DIR": "/missing/Xcode_27.2.app/Contents/Developer"}):
            with self.subTest(values=values):
                result, calls, actual, _, old = self.select(overrides=values)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])
                self.assertEqual(actual, old)

    def test_switch_errors_query_errors_and_a_mismatched_system_path_fail_without_retry(self):
        for mode in ("switch-error", "query-error", "mismatch"):
            with self.subTest(mode=mode):
                result, calls, _, _, _ = self.select(mode=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(sum(c["tool"] == "sudo" for c in calls), 1)
                self.assertEqual(sum(c["args"][:1] == ["--switch"] for c in calls), 1)
                self.assertNotIn("confirmed=true", result.stdout)

    def test_every_shipping_ui_and_probe_selects_before_preparing_apple_resources(self):
        def jobs(file):
            return dict(re.findall(r"^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)",
                (ROOT / ".github/workflows" / file).read_text(), re.M | re.S))
        shipping = jobs("ios-release.yml")
        keys = ["simulator-27-a", "simulator-27-b", "simulator-26-a", "simulator-26-b",
                "manual-27", "manual-26", "build-check", "development-build", "release"]
        blocks = [shipping[key] for key in keys]
        blocks += [jobs(file)["focus"] for file in (
            "manual-input-native-probe.yml", "application-relaunch-native-probe.yml")]
        blocks += [jobs("test-tools.yml")["picker"]]
        for block in blocks:
            selector = "python3 -B tools/select-ci-xcode.py"
            self.assertEqual(block.count(selector), 1)
            apple = re.search(r"\bxcodebuild\b|\bxcrun\b|tools/prepare-ios\d+-runtime\.py", block)
            self.assertIsNotNone(apple)
            self.assertLess(block.index(selector), apple.start())
        self.assertNotIn("tools/select-ci-xcode.py", shipping["checks"])
        self.assertNotIn("tools/select-ci-xcode.py", shipping["native-parsing"])


if __name__ == "__main__":
    unittest.main()
