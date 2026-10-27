"""Execute the real runner with fake Apple commands; never claim native UI success."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from ui_test_manifest import MANUAL_CASES


class ManualRunnerTests(unittest.TestCase):
    def test_shipping_comparison_refuses_a_missing_unavailable_or_newer_selected_runtime(self):
        workflow = (ROOT / ".github/workflows/manual-input-native-probe.yml").read_text()
        program = workflow.split("xcrun simctl list runtimes -j | python3 -c '\n", 1)[1].split("'\n", 1)[0]
        program = textwrap.dedent(program)
        def runtime(version, available=True):
            return {"version": version, "isAvailable": available,
                    "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-" + version.replace(".", "-")}
        for items, success in (([runtime("26.5")], True), ([runtime("26.5"), runtime("27.0")], True),
                               ([], False), ([runtime("26.5", False)], False),
                               ([runtime("26.5"), runtime("26.6")], False)):
            with self.subTest(runtimes=items):
                result = subprocess.run([sys.executable, "-c", program], input=json.dumps({"runtimes": items}),
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_focused_comparison_checks_both_sdks_without_changing_the_legacy_defaults(self):
        workflow = (ROOT / ".github/workflows/manual-input-native-probe.yml").read_text()
        self.assertIn("default: both", workflow)
        self.assertIn("default: '26.6'", workflow)
        self.assertIn("ios: ${{ fromJSON(inputs.ios == '26' && '[26]'", workflow)
        block = workflow.split("      - name: Require comparison SDK\n        run: |\n", 1)[1]
        script = textwrap.dedent(block.split("\n      - name:", 1)[0])
        with tempfile.TemporaryDirectory() as directory:
            command = Path(directory) / "xcrun"
            command.write_text("#!" + sys.executable + "\nimport os,sys\nprint(os.environ['TASK_SIM_SDK' if sys.argv[2] == 'iphonesimulator' else 'TASK_DEVICE_SDK'])\n")
            command.chmod(0o755)
            for expected, sim, device, success in (("27.1", "27.1", "27.1", True),
                    ("27.1", "26.5", "27.1", False), ("27.1", "27.1", "26.5", False),
                    ("26.5", "26.5", "26.5", True)):
                with self.subTest(expected=expected, simulator=sim, device=device):
                    env = os.environ | {"PATH": directory + os.pathsep + os.environ["PATH"],
                        "TKPK_EXPECTED_IOS_SDK": expected, "TASK_SIM_SDK": sim, "TASK_DEVICE_SDK": device}
                    result = subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def run_runner(self, *, selected="", build_status=0, omit_result=False, ios=26, record_all=False):
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
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'}, {'isAvailable': True, 'version': '27.0', 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'}, {'isAvailable': True, 'version': '27.1', 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-1'}],
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
                "TKPK_TEST_IOS": str(ios), "BUILD_STATUS": str(build_status),
                "CASES": json.dumps(MANUAL_CASES), "OMIT_RESULT": str(int(omit_result)),
            }
            result = subprocess.run(["bash", "tools/test-manual-ui.sh"], cwd=root,
                                    env=environment, capture_output=True, text=True, timeout=20)
            recorded = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertEqual(list((root / "scratch").iterdir()), [])
            self.assertIn(["xcrun", "simctl", "delete", "fictional-owned-simulator"], recorded)
            build = next(i for i, call in enumerate(recorded)
                         if call[0] == "xcodebuild" and call[-1] == "build-for-testing")
            boots = [i for i, call in enumerate(recorded) if call[:3] == ["xcrun", "simctl", "boot"]]
            if build_status:
                self.assertEqual(boots, [])
            else:
                self.assertEqual(len(boots), 1)
                run = next(i for i, call in enumerate(recorded)
                           if call[0] == "xcodebuild" and call[-1] == "test-without-building")
                self.assertLess(build, boots[0])
                self.assertLess(boots[0], run)
            return result, recorded if record_all else [call for call in recorded if call[0] == "xcodebuild"]

    def test_whole_suite_uses_one_successful_owned_build(self):
        result, calls = self.run_runner()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([call[-1] for call in calls[1:]],
                         ["build-for-testing", "test-without-building"])
        for option in ("-project", "-destination", "-derivedDataPath"):
            values = [call[call.index(option) + 1] for call in calls[1:]]
            self.assertEqual(values[0], values[1])
        self.assertIn("Verified four manual UI XCTest completions.", result.stdout)

    def test_selected_case_uses_the_same_build_without_retesting_others(self):
        for name in MANUAL_CASES:
            with self.subTest(case=name):
                result, calls = self.run_runner(selected=name)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(sum(call[-1] == "build-for-testing" for call in calls), 1)
                self.assertEqual(sum(call[-1] == "test-without-building" for call in calls), 1)
                self.assertIn("Verified selected manual UI XCTest completion: " + name, result.stdout)

    def test_shipping_27_uses_exact_27_0_when_newer_minor_is_available(self):
        result, calls = self.run_runner(ios=27, record_all=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        creates = [call for call in calls if call[:3] == ["xcrun", "simctl", "create"]]
        self.assertEqual(len(creates), 1)
        self.assertEqual(creates[0][-1], "com.apple.CoreSimulator.SimRuntime.iOS-27-0")

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
