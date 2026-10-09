"""Execute the real runner with fake Apple commands; never claim native UI success."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from ui_test_manifest import MANUAL_CASES


class ManualRunnerTests(unittest.TestCase):
    def run_runner(self, *, selected="", build_status=0, omit_result=False):
        with tempfile.TemporaryDirectory(prefix="takupoke-manual-runner-") as directory:
            root = Path(directory)
            for folder in ("tools", "bin", "scratch"):
                (root / folder).mkdir()
            for name in ("test-manual-ui.sh", "timed_command.py", "resolve-xcode-packages.sh"):
                shutil.copyfile(ROOT / "tools" / name, root / "tools" / name)
            (root / "tools/manual_ui_project.py").write_text(
                "import sys; from pathlib import Path; Path(sys.argv[1]).mkdir(parents=True)\n")
            fake = "#!" + sys.executable + "\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as output:
    output.write(json.dumps([Path(sys.argv[0]).name] + args) + '\\n')
if Path(sys.argv[0]).name == 'xcodebuild':
    if args[-1] == 'build-for-testing': sys.exit(int(os.environ['BUILD_STATUS']))
    if args[-1] == 'test-without-building':
        selected = next(arg.split(':', 1)[1] for arg in args if arg.startswith('-only-testing:'))
        names = json.loads(os.environ['CASES'])
        if selected.count('/') == 2: names = [selected.rsplit('/', 1)[1]]
        if os.environ['OMIT_RESULT'] == '1': names = names[1:]
        for name in names:
            print("Test Case '-[PickerTapChecks.ManualAssistanceChecks " + name + "]' passed (1.0 seconds).")
elif args[:2] == ['simctl', 'list']:
    print(json.dumps({'runtimes': [{'isAvailable': True, 'version': '26.5',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'}],
        'devicetypes': [{'name': 'iPhone 16', 'identifier': 'fictional-device'}]}))
elif args[:2] == ['simctl', 'create']: print('fictional-owned-simulator')
'''
            for name in ("xcrun", "xcodebuild"):
                path = root / "bin" / name
                path.write_text(fake)
                path.chmod(0o755)
            calls = root / "calls.jsonl"
            environment = os.environ | {
                "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
                "TMPDIR": str(root / "scratch"), "CALLS": str(calls),
                "TKPK_MANUAL_CASE": selected, "TKPK_MANUAL_DIAGNOSTICS": "0",
                "TKPK_TEST_IOS": "26", "BUILD_STATUS": str(build_status),
                "CASES": json.dumps(MANUAL_CASES), "OMIT_RESULT": str(int(omit_result)),
            }
            result = subprocess.run(["bash", "tools/test-manual-ui.sh"], cwd=root,
                                    env=environment, capture_output=True, text=True, timeout=20)
            recorded = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertEqual(list((root / "scratch").iterdir()), [])
            self.assertIn(["xcrun", "simctl", "delete", "fictional-owned-simulator"], recorded)
            return result, [call for call in recorded if call[0] == "xcodebuild"]

    def test_whole_suite_uses_one_successful_owned_build(self):
        result, calls = self.run_runner()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([call[-1] for call in calls[1:]],
                         ["build-for-testing", "test-without-building"])
        for option in ("-project", "-destination", "-derivedDataPath"):
            values = [call[call.index(option) + 1] for call in calls[1:]]
            self.assertEqual(values[0], values[1])
        self.assertIn("Verified three manual UI XCTest completions.", result.stdout)

    def test_selected_case_uses_the_same_build_without_retesting_others(self):
        result, calls = self.run_runner(selected=MANUAL_CASES[0])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sum(call[-1] == "build-for-testing" for call in calls), 1)
        self.assertEqual(sum(call[-1] == "test-without-building" for call in calls), 1)
        self.assertIn("Verified selected manual UI XCTest completion: " + MANUAL_CASES[0], result.stdout)

    def test_failed_build_never_starts_tests_or_becomes_success(self):
        result, calls = self.run_runner(build_status=7)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertFalse(any(call[-1] == "test-without-building" for call in calls))

    def test_missing_completion_refuses_even_after_successful_build(self):
        result, _ = self.run_runner(omit_result=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Manual UI completion mismatch", result.stderr)


if __name__ == "__main__":
    unittest.main()
