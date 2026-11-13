"""Execute the real runner with fake Apple commands; never claim native UI success."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import re
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from ui_test_manifest import MANUAL_CASES


class ManualRunnerTests(unittest.TestCase):
    def test_workflow_budget_includes_runtime_preparation_and_stops_before_ui_on_failure(self):
        for filename,job,ios,sdk26 in (('ios-release.yml','manual-26',26,'27.2'),
                                       ('ios-release.yml','manual-27',27,'27.2'),
                                       ('manual-input-native-probe.yml','focus',26,'27.2'),
                                       ('manual-input-native-probe.yml','focus',27,'27.2'),
                                       ('manual-input-native-probe.yml','focus',26,'26.6')):
            workflow=(ROOT/'.github/workflows'/filename).read_text()
            block=re.search(r'^  '+job+r':\n(.*?)(?=^  [\w-]+:\n|\Z)',workflow,re.M|re.S).group(1)
            step=block.split('      - name: Exercise ',1)[1].split('\n      - ',1)[0]
            command=textwrap.dedent(step.split('        run: |\n',1)[1])
            # Execute the actual workflow command with a short external budget.
            # Only the test's wall time/grace are scaled; setup and UI stay in
            # their real shell/process-group relationship.
            self.assertIn('--cleanup-grace 120',command)
            command=command.replace('--cleanup-grace 120','--cleanup-grace 0.2')
            if filename=='ios-release.yml':
                self.assertEqual(command.count('--timeout 2400'),1)
                command=command.replace('--timeout 2400','--timeout 1')
            prepared=filename=='ios-release.yml' or ios==27 or sdk26!='26.6'
            for mode in ('ready','failed-preparation','blocked-preparation') if prepared else ('ready',):
                with self.subTest(workflow=filename,job=job,ios=ios,sdk26=sdk26,mode=mode),tempfile.TemporaryDirectory() as directory:
                    root=Path(directory);tools=root/'tools';tools.mkdir();calls=root/'calls'
                    shutil.copy(ROOT/'tools/timed_command.py',tools/'timed_command.py')
                    (tools/'select-ci-xcode.py').write_text("import os\nfrom pathlib import Path\nwith Path(os.environ['CALLS']).open('a') as f:f.write('select\\n')\n")
                    preparation=("import os,time\nfrom pathlib import Path\n"
                        "with Path(os.environ['CALLS']).open('a') as f:f.write('prepare\\n')\n"
                        "if os.environ['PREPARATION_MODE']=='failed-preparation':raise SystemExit(9)\n"
                        "if os.environ['PREPARATION_MODE']=='blocked-preparation':time.sleep(30)\n")
                    for major in (26,27):(tools/f'prepare-ios{major}-runtime.py').write_text(preparation)
                    (tools/'test-manual-ui.sh').write_text('printf "ui\\n" >> "$CALLS"\n')
                    env=os.environ|{'CALLS':str(calls),'PREPARATION_MODE':mode,
                        'TKPK_TEST_IOS':str(ios),'TKPK_FOCUS_SDK26':sdk26,'TKPK_MANUAL_RUNNER_SECONDS':'1'}
                    result=subprocess.run(['bash','-euo','pipefail','-c',command],cwd=root,env=env,
                        capture_output=True,text=True,timeout=10)
                    self.assertEqual(result.returncode,{'ready':0,'failed-preparation':9,'blocked-preparation':124}[mode],result.stdout+result.stderr)
                    self.assertEqual(calls.read_text().splitlines(),['select']+(['prepare'] if prepared else [])+(['ui'] if mode=='ready' else []))
                    if mode=='blocked-preparation':self.assertIn('TIMING timeout:',result.stdout)

    def run_runner(self, *, selected="", build_status=0, omit_result=False, ios=26, record_all=False, omit_identity=False):
        with tempfile.TemporaryDirectory(prefix="takupoke-manual-runner-") as directory:
            root = Path(directory)
            for folder in ("tools", "bin", "scratch"):
                (root / folder).mkdir()
            for name in ("test-manual-ui.sh", "timed_command.py", "resolve-xcode-packages.sh", "boot-simulator-ui.sh", "notification_service_trace.py", "ui_test_manifest.py"):
                shutil.copyfile(ROOT / "tools" / name, root / "tools" / name)
            (root / "tools/manual_ui_project.py").write_text(
                "import sys; from pathlib import Path; Path(sys.argv[1]).mkdir(parents=True)\n")
            fake = "#!" + sys.executable + "\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as output:
    output.write(json.dumps([Path(sys.argv[0]).name] + args) + '\\n')
if Path(sys.argv[0]).name == 'xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif Path(sys.argv[0]).name == 'xcodebuild':
    if args[-1] == 'build-for-testing': sys.exit(int(os.environ['BUILD_STATUS']))
    if args[-1] == 'test-without-building':
        selected = next(arg.split(':', 1)[1] for arg in args if arg.startswith('-only-testing:'))
        names = json.loads(os.environ['CASES'])
        if selected.count('/') == 2: names = [selected.rsplit('/', 1)[1]]
        if os.environ['OMIT_RESULT'] == '1': names = names[1:]
        for name in names:
            if os.environ['OMIT_IDENTITY']!='1':
                print('TAKUPOKE_UI_EXECUTION_IDENTITY '+json.dumps({'case':'-[PickerTapChecks.ManualAssistanceChecks '+name+']',
                    'udid':'00000000-0000-0000-0000-000000000001','runtime':'27.0.0' if os.environ['TKPK_TEST_IOS']=='27' else '26.5.0',
                    'simulatorCompileTarget':True,'pid':123}))
            print("Test Case '-[PickerTapChecks.ManualAssistanceChecks " + name + "]' passed (1.0 seconds).")
elif args[:2] == ['simctl', 'list']:
    print(json.dumps({'runtimes': [{'isAvailable': True, 'version': '26.5',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'}, {'isAvailable': True, 'version': '27.0', 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'}, {'isAvailable': True, 'version': '27.1', 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-1'}],
        'devicetypes': [{'name': 'iPhone 16', 'identifier': 'fictional-device'}],
        'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-' + ('27-0' if os.environ['TKPK_TEST_IOS'] == '27' else '26-5'):
            [{'udid': '00000000-0000-0000-0000-000000000001', 'state': 'Booted'}]}}))
elif args[:2] == ['simctl', 'create']: print('00000000-0000-0000-0000-000000000001')
'''
            for name in ("xcrun", "xcodebuild", "xcode-select", "open", "codesign"):
                path = root / "bin" / name
                path.write_text(fake)
                path.chmod(0o755)
            calls = root / "calls.jsonl"
            developer = root / 'Xcode.app/Contents/Developer'
            (developer / 'Applications/Simulator.app').mkdir(parents=True)
            environment = os.environ | {
                "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
                "TMPDIR": str(root / "scratch"), "CALLS": str(calls),
                "TKPK_MANUAL_CASE": selected, "TKPK_MANUAL_DIAGNOSTICS": "0",
                "TKPK_TEST_IOS": str(ios), "BUILD_STATUS": str(build_status),
                "CASES": json.dumps(MANUAL_CASES), "OMIT_RESULT": str(int(omit_result)),
                "OMIT_IDENTITY": str(int(omit_identity)),
                "SYNTHETIC_DEVELOPER": str(developer), "DEVELOPER_DIR": str(developer),
            }
            result = subprocess.run(["bash", "tools/test-manual-ui.sh"], cwd=root,
                                    env=environment, capture_output=True, text=True, timeout=20)
            recorded = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertEqual(list((root / "scratch").iterdir()), [])
            self.assertIn(["xcrun", "simctl", "delete", "00000000-0000-0000-0000-000000000001"], recorded)
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

    def test_passing_completions_without_native_identities_are_rejected(self):
        result, _ = self.run_runner(omit_identity=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one native identity", result.stderr)


if __name__ == "__main__":
    unittest.main()
