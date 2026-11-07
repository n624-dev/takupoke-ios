"""Run the actual UI shell orchestration with isolated Apple command doubles."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import ui_test_manifest as manifest


@unittest.skipUnless(os.name == "posix", "macOS CI Bash runner")
class ShellRunnerTests(unittest.TestCase):
    def test_actual_shutdown_helper_only_accepts_verified_target_state_after_exit_149(self):
        source=(ROOT / "tools/test-app-ui.sh").read_text()
        helper="shutdown_simulator() {"+source.split("shutdown_simulator() {",1)[1].split("collect_launch_trace() {",1)[0]
        for status, confirmed, expected in ((0,1,0),(149,0,0),(149,1,149),(143,0,143),(7,0,7)):
            with self.subTest(status=status, confirmed=confirmed):
                script='''set -euo pipefail
simulator_id=00000000-0000-0000-0000-000000000001
runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun() { [[ "$*" == "simctl shutdown $simulator_id" ]] || exit 91; return "$SHUTDOWN_STATUS"; }
python3() { [[ "$*" == "-B tools/notification_service_trace.py --confirm-shutdown $simulator_id $runtime" ]] || exit 92; echo CONFIRM; return "$CONFIRM_STATUS"; }
'''+helper+'\nshutdown_simulator\n'
                result=subprocess.run(["bash","-c",script],capture_output=True,text=True,
                    env=os.environ | {"SHUTDOWN_STATUS":str(status),"CONFIRM_STATUS":str(confirmed)},timeout=5)
                self.assertEqual(result.returncode,expected,result.stdout+result.stderr)
                self.assertEqual(result.stdout.count("CONFIRM"),int(status==149))

    def test_diagnosis_defaults_to_27_without_adding_26_matrix_rows(self):
        workflow = (ROOT / ".github/workflows/application-relaunch-native-probe.yml").read_text()
        selection = workflow.split("      ios:\n", 1)[1].split("      sdk27:\n", 1)[0]
        self.assertIn("default: '27'", selection)
        self.assertIn("options: ['27', '26', 'both']", selection)
        matrix = workflow.split("      matrix:\n", 1)[1].split("    runs-on:", 1)[0]
        arrays = re.findall(r"'(\[[\d,]+\])'", matrix)
        self.assertEqual([json.loads(value) for value in arrays], [[27, 26], [26], [27]])
        self.assertIn("inputs.ios == 'both'", matrix)
        self.assertIn("inputs.ios == '26'", matrix)
        self.assertNotIn("include:", matrix)
        self.assertIn(
            "runs-on: ${{ matrix.ios == 26 && inputs.sdk26 == '26.6' && 'macos-26' || 'xcode-27' }}",
            workflow)
        sdk27 = workflow.split("      sdk27:\n", 1)[1].split("      sdk26:\n", 1)[0]
        self.assertIn("default: '27.1'", sdk27)
        for version in ("27.0", "27.1", "27.2"):
            self.assertIn("          - '" + version + "'", sdk27)
        sdk26 = workflow.split("      sdk26:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertIn("default: '26.6'", sdk26)
        self.assertIn("options: ['26.6', '27.0', '27.1', '27.2']", sdk26)

    def test_alternate_toolchain_preflight_requires_requested_sdk_and_same_runtime(self):
        workflow = (ROOT / ".github/workflows/application-relaunch-native-probe.yml").read_text()
        block = workflow.split("- name: Require comparison toolchain and unchanged runtime\n        run: |\n", 1)[1]
        script = textwrap.dedent(block.split("\n      - name:", 1)[0])
        self.assertIn("if: always() && matrix.ios == 26\n        run: python3 -B tools/prepare-ios26-runtime.py --cleanup-export\n", workflow)
        with tempfile.TemporaryDirectory(prefix="takupoke-sdk-preflight-") as directory:
            root = Path(directory)
            fake = "#!" + sys.executable + "\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
marker = Path(os.environ['IMPORT_MARKER'])
downloaded = marker.with_name('downloaded')
removed = marker.with_name('asset-removed')
local = marker.with_name('local-imported')
download_id = '11111111-1111-4111-8111-111111111111'
local_id = '22222222-2222-4222-8222-222222222222'
asset = '/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/' + 'a'*40 + '.asset/AssetData'
with open(os.environ['COMMAND_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if sys.argv[1:2] == ['--sdk']: print(os.environ['OBSERVED_SDK'])
elif args[:3] == ['simctl','runtime','list']:
    images = {}
    if downloaded.exists() and not removed.exists():
        images[download_id] = {'identifier':download_id,'runtimeIdentifier':'com.apple.CoreSimulator.SimRuntime.iOS-26-5',
            'platformIdentifier':'com.apple.platform.iphonesimulator','version':'26.6' if os.environ['IMPORT_MODE']=='auto-wrong-version' else '26.5',
            'build':'23F77','state':'Ready','deletable':True,'path':asset}
    if local.exists():
        images[local_id] = {'identifier':local_id,'runtimeIdentifier':'com.apple.CoreSimulator.SimRuntime.iOS-26-5',
            'platformIdentifier':'com.apple.platform.iphonesimulator','version':marker.read_text(),
            'build':'23F77','state':'Ready','deletable':True,'path':'/Library/Developer/CoreSimulator/Cryptex/Images/'+local_id}
    print(json.dumps(images))
elif args[:3] == ['simctl','list','devices']: print(json.dumps({'devices':{}}))
elif args[:3] == ['simctl','runtime','delete']:
    assert args == ['simctl','runtime','delete',download_id] and downloaded.exists() and not local.exists()
    removed.write_text('owned asset reclaimed')
elif sys.argv[1:2] == ['simctl']:
    runtime = marker.read_text() if marker.exists() else os.environ['OBSERVED_RUNTIME']
    if runtime == '27.0+27.1':
        print(json.dumps({'runtimes':[{'isAvailable':True,'version':v,'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-'+v.replace('.','-')} for v in ['27.0','27.1']]}));sys.exit()
    print(json.dumps({'runtimes': [{'isAvailable': os.environ['IMPORT_MODE'] != 'registered-unavailable', 'version': runtime,
        'buildversion':'23F73' if os.environ['IMPORT_MODE']=='wrong-build' else '23F77',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + runtime.replace('.', '-')}]}))
elif args[:1] == ['-downloadPlatform']:
    assert args[:7] == ['-downloadPlatform','iOS','-buildVersion','23F77','-architectureVariant','arm64','-exportPath']
    if os.environ['IMPORT_MODE'] == 'download-fails': sys.exit(9)
    downloaded.write_text('new owned runtime')
    exported = Path(args[args.index('-exportPath') + 1])
    if os.environ['IMPORT_MODE'] in ('auto-install', 'auto-wrong-version'):
        bundle = exported / 'fictional-runtime.exportedBundle'
        bundle.mkdir(); (bundle/'image').write_bytes(b'fictional image')
        version = '26.6' if os.environ['IMPORT_MODE'] == 'auto-wrong-version' else '26.5'
        Path(os.environ['IMPORT_MARKER']).write_text(version)
    elif os.environ['IMPORT_MODE'] != 'no-image':
        (exported / 'fictional-runtime.dmg').write_bytes(b'fictional image')
elif args[:1] == ['-importPlatform']:
    assert removed.exists() and not local.exists()
    exported = Path(args[1]); image = exported/'image' if exported.is_dir() else exported
    assert image.read_bytes() == b'fictional image'
    if os.environ['IMPORT_MODE'] == 'import-fails': sys.exit(10)
    if os.environ['IMPORT_MODE'] == 'unavailable': sys.exit(0)
    version = '26.6' if os.environ['IMPORT_MODE'] == 'wrong-version' else '26.5'
    Path(os.environ['IMPORT_MARKER']).write_text(version)
    local.write_text('one imported local runtime')
else: print('Synthetic Xcode version')
'''
            for name in ("xcodebuild", "xcrun"):
                path = root / name
                path.write_text(fake)
                path.chmod(0o755)
            cases = (
                (27, "26.6", "27.1", "27.0", "unused", True),
                (27, "26.6", "27.1", "27.0+27.1", "unused", True),
                (27, "26.6", "27.2", "27.0", "unused", False),
                (27, "26.6", "27.2", "27.0", "unused", True, "27.2"),
                (27, "26.6", "27.2", "27.0+27.1", "unused", True, "27.2"),
                (27, "26.6", "27.1", "27.0", "unused", False, "27.2"),
                (27, "26.6", "27.0", "27.0", "unused", True, "27.0"),
                (26, "27.1", "27.1", "26.5", "unused", True),
                (26, "27.2", "27.2", "26.5", "unused", True),
                (26, "27.2", "27.2", "26.5", "wrong-build", False),
                (26, "27.1", "27.0", "26.5", "unused", False),
                (26, "26.6", "26.6", "26.5", "unused", False),
                (27, "26.6", "27.0", "27.0", "unused", False),
                (27, "26.6", "27.1", "27.1", "unused", False),
                (27, "26.6", "27.1", "26.5", "unused", False),
                (26, "26.6", "26.5", "26.5", "unused", True),
                (26, "27.0", "27.0", "26.5", "unused", True),
                (26, "27.0", "26.6", "26.5", "unused", False),
                (26, "27.0", "27.0", "26.6", "unused", False),
                (26, "27.0", "27.0", "26.4", "registered-unavailable", False),
                (26, "27.0", "27.0", "27.0", "success", True),
                (26, "27.0", "27.0", "27.0", "auto-install", True),
                (26, "27.0", "27.0", "27.0", "auto-wrong-version", False),
                (26, "27.0", "27.0", "27.0", "download-fails", False),
                (26, "27.0", "27.0", "27.0", "import-fails", False),
                (26, "27.0", "27.0", "27.0", "no-image", False),
                (26, "27.0", "27.0", "27.0", "wrong-version", False),
                (26, "27.0", "27.0", "27.0", "unavailable", False),
            )
            command_log, marker = root / "commands.jsonl", root / "imported-version"
            for ios, sdk26, sdk, runtime, mode, success, *requested in cases:
                sdk27 = requested[0] if requested else "27.1"
                with self.subTest(ios=ios, sdk26=sdk26, requested=sdk27, sdk=sdk, runtime=runtime, mode=mode):
                    command_log.unlink(missing_ok=True)
                    marker.unlink(missing_ok=True)
                    for name in ('downloaded','asset-removed','local-imported'):
                        (root/name).unlink(missing_ok=True)
                    env = os.environ | {"PATH": directory + os.pathsep + os.environ["PATH"],
                        "TKPK_TEST_IOS": str(ios), "TKPK_UI_PROBE_SDK27": sdk27,
                        "TKPK_UI_PROBE_SDK26": sdk26,
                        "TKPK_EXPECTED_IOS_SDK": sdk26 if ios == 26 else sdk27,
                        "RUNNER_TEMP": directory, "IMPORT_MODE": mode,
                        "COMMAND_LOG": str(command_log), "IMPORT_MARKER": str(marker),
                        "OBSERVED_SDK": sdk, "OBSERVED_RUNTIME": runtime}
                    result = subprocess.run(["bash", "-c", script], env=env, cwd=ROOT,
                                            capture_output=True, text=True, timeout=5)
                    # Each row is a separate job: exercise its new always cleanup
                    # before reusing this test's synthetic RUNNER_TEMP.
                    cleaned = subprocess.run([sys.executable,"-B",str(ROOT/"tools/prepare-ios26-runtime.py"),"--cleanup-export"],
                        env=env,cwd=ROOT,capture_output=True,text=True,timeout=5)
                    self.assertEqual(cleaned.returncode,0,cleaned.stdout+cleaned.stderr)
                    self.assertFalse((root/"takupoke-ios26-runtime-export-owned").exists())
                    self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
                    commands = [json.loads(line) for line in command_log.read_text().splitlines()]
                    downloads = [args for args in commands if args[:1] == ["-downloadPlatform"]]
                    imports = [args for args in commands if args[:1] == ["-importPlatform"]]
                    removals = [args for args in commands if args[:3] == ['simctl','runtime','delete']]
                    if mode in ("unused", "registered-unavailable", "wrong-build"):
                        self.assertEqual(downloads, [])
                        self.assertEqual(imports, [])
                        self.assertEqual(removals, [])
                    else:
                        self.assertEqual(len(downloads), 1)
                        self.assertEqual(downloads[0][:7],
                                         ["-downloadPlatform", "iOS", "-buildVersion", "23F77", "-architectureVariant", "arm64", "-exportPath"])
                        no_import = mode in ("download-fails", "no-image", "auto-wrong-version")
                        self.assertEqual(len(imports), 0 if no_import else 1)
                        self.assertEqual(removals, [] if no_import else [['simctl','runtime','delete','11111111-1111-4111-8111-111111111111']])
                        if not no_import:
                            self.assertLess(commands.index(removals[0]), commands.index(imports[0]))
                    self.assertEqual(list(root.glob("takupoke-runtime-owned-*")), [])

    def run_synthetic_runner(self, ios, shard, *, omit_result=False, fail_build=False,
                             fail_frontend=False, fail_device_window=False,
                             missing_frontend=False, probe_case=None, fail_tests=False,
                             duplicate_result=False, fail_notification=False,
                             fail_notification_boot=False, fail_case=None, omit_identity=False):
        with tempfile.TemporaryDirectory(prefix="takupoke-shard-check-") as directory:
            repo = Path(directory)
            (repo / "tools").mkdir()
            (repo / "tests/ui").mkdir(parents=True)
            (repo / "bin").mkdir()
            (repo / "scratch").mkdir()
            for name in ("test-app-ui.sh", "resolve-xcode-packages.sh", "ui_test_manifest.py", "timed_command.py",
                         "notification_service_trace.py", "manual_ui_diagnostics.py", "watch_app_hang.py", "boot-simulator-ui.sh"):
                shutil.copyfile(ROOT / "tools" / name, repo / "tools" / name)
            for name in manifest.CHECK_SOURCES:
                shutil.copyfile(ROOT / "tests/ui" / name, repo / "tests/ui" / name)
            (repo / "tools/app_test_project.py").write_text(
                "import json, os\n"
                "with open(os.environ['CALLS'], 'a') as output:\n"
                "    output.write(json.dumps(['project', os.environ['TKPK_VOICEOVER_AUTOMATION']]) + '\\n')\n")
            fake = "#!" + sys.executable + "\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as output:
    output.write(json.dumps([Path(sys.argv[0]).name] + args) + '\\n')
if Path(sys.argv[0]).name == 'xcodebuild':
    if 'build-for-testing' in args and os.environ.get('FAIL_BUILD'): sys.exit(42)
    tests = [arg.rsplit('/', 1)[1] for arg in args if arg.startswith('-only-testing:')]
    if os.environ.get('OMIT_RESULT'): tests = tests[1:]
    if os.environ.get('DUPLICATE_RESULT') and tests: tests += tests[:1]
    for test in tests:
        status = 'skipped' if os.environ['TKPK_TEST_IOS'] == '26' and test == 'testVoiceOverReadsTimetableCard' else 'passed'
        if not os.environ.get('OMIT_IDENTITY'):
            owned=args[args.index('-destination')+1].split('id=',1)[1]
            record={'case':'-[PickerTapChecks.ApplicationChecks '+test+']','udid':owned,
                    'runtime':'26.5.0' if os.environ['TKPK_TEST_IOS']=='26' else '27.0.0',
                    'simulatorCompileTarget':True,'pid':123}
            print('TAKUPOKE_UI_EXECUTION_IDENTITY '+json.dumps(record),
                  file=sys.stderr if os.environ['TKPK_TEST_IOS']=='26' else sys.stdout)
        print(f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).",
              file=sys.stderr if os.environ['TKPK_TEST_IOS'] == '26' else sys.stdout)
    if 'test-without-building' in args and os.environ.get('FAIL_TESTS'): sys.exit(45)
    if os.environ.get('FAIL_CASE') in tests: sys.exit(49)
    if os.environ.get('FAIL_NOTIFICATION') and tests == ['testNotificationControlsAndAppearance']: sys.exit(46)
elif Path(sys.argv[0]).name == 'log': print('[]')
elif Path(sys.argv[0]).name == 'xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif Path(sys.argv[0]).name == 'defaults': print('1' if args[1] == 'com.apple.iphonesimulator' else '0')
elif Path(sys.argv[0]).name == 'open' and os.environ.get('FAIL_FRONTEND'): sys.exit(43)
elif (Path(sys.argv[0]).name == 'open' and os.environ.get('FAIL_DEVICE_WINDOW')
      and any(arg.startswith('devices://') for arg in args)): sys.exit(44)
elif args[:2] == ['simctl', 'list']:
    major = os.environ['TKPK_TEST_IOS']
    print(json.dumps({'runtimes': [{'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + major + ('-0' if major == '27' else '-5'), 'version': major + ('.0' if major == '27' else '.5')}, {'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-1', 'version': '27.1'}],
                      'devicetypes': [{'name': 'iPhone 16', 'identifier': 'synthetic-device'}],
                      'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-' + major + ('-0' if major == '27' else '-5'):
                          [{'udid': value, 'state': 'Booted'} for value in
                           ['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002']]}}))
elif args[:2] == ['simctl', 'create']:
    creates = sum(json.loads(line)[1:3] == ['simctl', 'create']
                  for line in Path(os.environ['CALLS']).read_text().splitlines())
    print('00000000-0000-0000-0000-000000000001' if creates == 1 else '00000000-0000-0000-0000-000000000002')
elif (args[:3] == ['simctl', 'bootstatus', '00000000-0000-0000-0000-000000000002']
      and os.environ.get('FAIL_NOTIFICATION_BOOT')): sys.exit(47)
elif args[:2] == ['simctl', 'get_app_container']: print(os.environ['APP_CONTAINER'])
'''
            for tool in ("xcrun", "xcodebuild", "xcode-select", "open", "defaults", "codesign", "log"):
                path = repo / "bin" / tool
                path.write_text(fake)
                path.chmod(0o755)
            developer = repo / "Xcode.app/Contents/Developer"
            developer.mkdir(parents=True)
            frontend = (developer / "Applications/Simulator.app" if ios == 26 else
                        developer.parent / "Applications/DeviceHub.app")
            if not missing_frontend:
                frontend.mkdir(parents=True)
            calls_file = repo / "calls"
            environment = os.environ | {
                "PATH": str(repo / "bin") + os.pathsep + os.environ["PATH"],
                "TMPDIR": str(repo / "scratch"), "TKPK_TEST_IOS": str(ios),
                "TKPK_UI_SHARD": shard, "CALLS": str(calls_file),
                "APP_CONTAINER": str(repo / "container"), "SYNTHETIC_DEVELOPER": str(developer), "DEVELOPER_DIR": str(developer),
            }
            if fail_case:
                environment["FAIL_CASE"] = fail_case
            if fail_notification:
                environment["FAIL_NOTIFICATION"] = "1"
            if fail_notification_boot:
                environment["FAIL_NOTIFICATION_BOOT"] = "1"
            if fail_tests:
                environment["FAIL_TESTS"] = "1"
            if duplicate_result:
                environment["DUPLICATE_RESULT"] = "1"
            if omit_result:
                environment["OMIT_RESULT"] = "1"
            if omit_identity:
                environment["OMIT_IDENTITY"] = "1"
            if fail_build:
                environment["FAIL_BUILD"] = "1"
            if fail_frontend:
                environment["FAIL_FRONTEND"] = "1"
            if fail_device_window:
                environment["FAIL_DEVICE_WINDOW"] = "1"
            if probe_case:
                environment.update(TKPK_UI_RELAUNCH_PROBE="1", TKPK_UI_PROBE_CASE=probe_case)
            result = subprocess.run(["bash", "tools/test-app-ui.sh"], cwd=repo, env=environment,
                                    capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()]
            self.assertEqual(list((repo / "scratch").iterdir()), [], "Owned scratch data must be removed")
            self.assertIn(["xcrun", "simctl", "shutdown", "00000000-0000-0000-0000-000000000001"], calls)
            self.assertIn(["xcrun", "simctl", "delete", "00000000-0000-0000-0000-000000000001"], calls)
            if len([call for call in calls if call[:3] == ["xcrun", "simctl", "create"]]) == 2:
                self.assertIn(["xcrun", "simctl", "shutdown", "00000000-0000-0000-0000-000000000002"], calls)
                self.assertIn(["xcrun", "simctl", "delete", "00000000-0000-0000-0000-000000000002"], calls)
            return result, calls

    def test_optional_hang_observer_preserves_phase_results_and_owned_cleanup(self):
        for failed in (False, True):
            with self.subTest(failed=failed), patch.dict(os.environ, {"TKPK_UI_HANG_DIAGNOSTICS": "1"}):
                result, calls = self.run_synthetic_runner(27, "all", probe_case="rows-context", fail_tests=failed)
                self.assertEqual(result.returncode, 1 if failed else 0, result.stdout + result.stderr)
                self.assertNotIn("TAKUPOKE_APP_STACK ", result.stdout)
                batches = [call for call in calls if call[0] == "xcodebuild" and "test-without-building" in call]
                self.assertEqual(len(batches), 1)
                self.assertEqual([arg.rsplit("/",1)[1] for arg in batches[0] if arg.startswith("-only-testing:")],
                                 list(manifest.PROBE_GROUPS["rows-context"]))

    def test_input_probe_runs_each_original_case_once_on_the_same_owned_device(self):
        cases = ("testSettingsAccountDataAndFileDetails", "testVoiceOverReadsTimetableCard")
        for failed in (None, *cases):
            with self.subTest(failed=failed):
                result, calls = self.run_synthetic_runner(27, "all", probe_case="input-delivery", fail_case=failed)
                self.assertEqual(result.returncode, 0 if failed is None else 1, result.stdout + result.stderr)
                builds = [call for call in calls if call[0] == "xcodebuild" and
                          "-resolvePackageDependencies" not in call]
                expected = cases[:1] if failed == cases[0] else cases
                self.assertEqual(len(builds), 1 + len(expected))
                self.assertEqual(builds[0][-1], "build-for-testing")
                for build, test in zip(builds[1:], expected, strict=True):
                    self.assertEqual(build[-1], "test-without-building")
                    self.assertEqual([arg for arg in build if arg.startswith("-only-testing:")],
                                     ["-only-testing:PickerTapChecks/ApplicationChecks/" + test])
                    self.assertIn("platform=iOS Simulator,id=00000000-0000-0000-0000-000000000001", build)
                self.assertEqual(sum(call[:3] == ["xcrun", "simctl", "create"] for call in calls), 1)

    def test_year_input_probe_keeps_preceding_case_and_reads_keyboard_settings_without_writes(self):
        cases = ("testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates",
                 "testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair")
        for failed in (None, *cases):
            with self.subTest(failed=failed):
                result, calls = self.run_synthetic_runner(27, "all", probe_case="event-cache-input", fail_case=failed)
                self.assertEqual(result.returncode, 0 if failed is None else 1, result.stdout + result.stderr)
                reads = [call for call in calls if call[0] == "defaults"]
                self.assertEqual(reads, [["defaults", "read", domain, "ConnectHardwareKeyboard"]
                                       for domain in ("com.apple.iphonesimulator", "com.apple.DeviceHub")])
                for value in ("0", "1"):
                    self.assertIn('"connected": "' + value + '"', result.stdout)
                batches = [call for call in calls if call[0] == "xcodebuild" and "test-without-building" in call]
                self.assertEqual(len(batches), 1)
                self.assertEqual([arg.rsplit("/", 1)[1] for arg in batches[0] if arg.startswith("-only-testing:")], list(cases))
                self.assertEqual(sum(call[:3] == ["xcrun", "simctl", "create"] for call in calls), 1)

    def test_successful_notification_probe_observes_os_before_deleting_simulator(self):
        for ios in (26, 27):
            with self.subTest(ios=ios):
                result, calls = self.run_synthetic_runner(ios, "all", probe_case="notifications")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                build = next(call for call in calls if call[0] == "xcodebuild" and
                             "test-without-building" in call)
                tests = [arg.rsplit("/", 1)[1] for arg in build if arg.startswith("-only-testing:")]
                self.assertEqual(tests, list(manifest.NOTIFICATION_PROBE_TESTS))
                observation = [call for call in calls if call[:6] ==
                    ["xcrun", "simctl", "spawn", "00000000-0000-0000-0000-000000000001", "log", "show"]]
                self.assertEqual(len(observation), 1)
                self.assertLess(calls.index(build), calls.index(observation[0]))
                self.assertLess(calls.index(observation[0]), calls.index(
                    ["xcrun", "simctl", "shutdown", "00000000-0000-0000-0000-000000000001"]))
                self.assertIn("TAKUPOKE_NOTIFICATION_SERVICES ", result.stdout)

    def test_headless_runner_keeps_all_selected_ui_cases_and_actual_size_commands(self):
        for ios in (26, 27):
            with self.subTest(ios=ios), patch.dict(os.environ, {"TKPK_SIMULATOR_FRONTEND": "headless"}):
                result, calls = self.run_synthetic_runner(ios, "A")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(any(call[0] in ("open", "xcode-select") for call in calls))
                selected = [arg.rsplit("/", 1)[1] for call in calls if call[0] == "xcodebuild"
                            and call[-1] == "test-without-building" for arg in call if arg.startswith("-only-testing:")]
                self.assertCountEqual(selected, manifest.SHARDS["A"])
                self.assertIn(["xcrun", "simctl", "ui", "00000000-0000-0000-0000-000000000001",
                               "content_size", "large"], calls)

    def test_passing_ui_completions_without_native_case_identities_fail_closed(self):
        for ios in (26, 27):
            with self.subTest(ios=ios):
                result, _ = self.run_synthetic_runner(ios, "A", omit_identity=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("exactly one native identity", result.stdout + result.stderr)

    def test_both_shards_on_both_os_preserve_selection_and_os_size_checks(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                with self.subTest(ios=ios, shard=shard):
                    result, calls = self.run_synthetic_runner(ios, shard)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn("TAKUPOKE_AX_SERVICES ", result.stdout)
                    self.assertIn(["project", "1" if ios == 27 else "0"], calls)
                    resolutions = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" in call]
                    self.assertEqual(len(resolutions), 1)
                    builds = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" not in call]
                    phase_count = 5 if shard == "B" else 2
                    self.assertEqual(len(builds), 1 + phase_count + (3 if shard == "B" else 0))
                    self.assertEqual(builds[0][-1], "build-for-testing")
                    self.assertFalse(any(arg.startswith("-only-testing:") for arg in builds[0]))
                    boot = ["xcrun", "simctl", "boot", "00000000-0000-0000-0000-000000000001"]
                    self.assertLess(calls.index(builds[0]), calls.index(boot))
                    frontends = [call for call in calls if call[0] == "open"]
                    self.assertEqual(len(frontends), 2)
                    frontend = frontends[0]
                    self.assertEqual(Path(frontend[2]).name, "Simulator.app" if ios == 26 else "DeviceHub.app")
                    self.assertEqual(frontend[3:], ["--args", "-CurrentDeviceUDID", "00000000-0000-0000-0000-000000000001"]
                                     if ios == 26 else [])
                    self.assertLess(calls.index(boot), calls.index(frontend))
                    self.assertLess(calls.index(frontend), calls.index(builds[1]))
                    if ios == 27:
                        window = frontends[1]
                        self.assertEqual(window[1:3], frontend[1:3])
                        self.assertEqual(window[3:], ["devices://device/open?id=00000000-0000-0000-0000-000000000001"])
                        ready = ["xcrun", "simctl", "bootstatus", "00000000-0000-0000-0000-000000000001", "-b"]
                        self.assertLess(calls.index(ready), calls.index(window))
                        self.assertLess(calls.index(window), calls.index(builds[1]))
                    self.assertTrue(all(build[-1] == "test-without-building" for build in builds[1:]))
                    batches = builds[1:1 + phase_count]
                    phases = (("before-settings", "settings", "after-settings", "voiceover", "notifications")
                              if shard == "B" else ("remaining", "notifications"))
                    selected = []
                    for phase, batch in zip(phases, batches, strict=True):
                        tests = [arg.rsplit("/", 1)[1] for arg in batch if arg.startswith("-only-testing:")]
                        self.assertEqual(tests, list(manifest.phase_tests(manifest.SHARDS[shard], phase)))
                        selected.extend(tests)
                    self.assertEqual(len(selected), len(manifest.SHARDS[shard]))
                    self.assertEqual(sorted(selected), sorted(manifest.SHARDS[shard]))
                    notification = batches[-1]
                    if ios == 26:
                        retired = ["xcrun", "simctl", "delete", "00000000-0000-0000-0000-000000000001"]
                        ready = ["xcrun", "simctl", "bootstatus", "00000000-0000-0000-0000-000000000002", "-b"]
                        self.assertLess(calls.index(batches[-2]), calls.index(retired))
                        self.assertLess(calls.index(retired), calls.index(ready))
                        self.assertLess(calls.index(ready), calls.index(notification))
                        self.assertTrue(all("platform=iOS Simulator,id=00000000-0000-0000-0000-000000000001" in batch
                                            for batch in batches[:-1]))
                        self.assertTrue(all("platform=iOS Simulator,id=00000000-0000-0000-0000-000000000002"
                                            in build for build in builds[phase_count:]))
                        self.assertEqual(frontends[1][3:],
                                         ["--args", "-CurrentDeviceUDID", "00000000-0000-0000-0000-000000000002"])
                    else:
                        self.assertEqual(sum(call[:3] == ["xcrun", "simctl", "create"] for call in calls), 1)
                        self.assertTrue(all("platform=iOS Simulator,id=00000000-0000-0000-0000-000000000001" in build
                                            for build in builds))
                    sizes = [call[-1] for call in calls if call[:2] == ["xcrun", "simctl"]
                             and "content_size" in call]
                    self.assertEqual(sizes, ["large"] * (2 if ios == 26 else 1) + (["extra-small", "extra-extra-extra-large",
                        "accessibility-extra-extra-extra-large"] if shard == "B" else []))
                    for build in builds[1 + phase_count:]:
                        self.assertEqual(build[-1], "test-without-building")
                        self.assertIn("-only-testing:PickerTapChecks/ApplicationChecks/" + manifest.SYSTEM_SIZE_TEST, build)

    def test_missing_xctest_completion_fails_shell_and_cleans_up(self):
        result, calls = self.run_synthetic_runner(27, "B", omit_result=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("XCTest completion differs", result.stderr)
        self.assertEqual(len([call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" not in call]), 2)

    def test_failed_ui_build_does_not_boot_or_run_tests_and_still_cleans_up(self):
        result, calls = self.run_synthetic_runner(27, "A", fail_build=True)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertNotIn(["xcrun", "simctl", "boot", "00000000-0000-0000-0000-000000000001"], calls)
        builds = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" not in call]
        self.assertEqual(len(builds), 1)
        self.assertEqual(builds[0][-1], "build-for-testing")

    def test_failed_frontend_launch_does_not_run_ui_and_cleans_owned_device(self):
        result, calls = self.run_synthetic_runner(27, "A", fail_frontend=True)
        self.assertEqual(result.returncode, 43, result.stdout + result.stderr)
        self.assertFalse(any("test-without-building" in call for call in calls))
        self.assertTrue(any(call[0] == "open" for call in calls))

    def test_missing_selected_xcode_frontend_fails_without_running_ui(self):
        result, calls = self.run_synthetic_runner(27, "A", missing_frontend=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("No supported simulator frontend", result.stderr)
        self.assertFalse(any("test-without-building" in call for call in calls))
        self.assertFalse(any(call[0] == "open" for call in calls))

    def test_failed_owned_device_window_does_not_run_ui_and_cleans_up(self):
        result, calls = self.run_synthetic_runner(27, "A", fail_device_window=True)
        self.assertEqual(result.returncode, 44, result.stdout + result.stderr)
        self.assertFalse(any("test-without-building" in call for call in calls))
        self.assertTrue(any("devices://device/open?id=00000000-0000-0000-0000-000000000001" in call for call in calls))

    def test_failed_or_duplicate_first_batch_stops_without_retry_or_size_checks(self):
        for flags, message in (({"fail_tests": True}, None),
                               ({"duplicate_result": True}, "XCTest completion differs")):
            with self.subTest(flags=flags):
                result, calls = self.run_synthetic_runner(26, "B", **flags)
                self.assertNotEqual(result.returncode, 0)
                if message:
                    self.assertIn(message, result.stderr)
                self.assertIn("TAKUPOKE_AX_SERVICES ", result.stdout)
                observations = [i for i, call in enumerate(calls) if call[-2:] == ["launchctl", "list"]]
                deletion = calls.index(["xcrun", "simctl", "delete", "00000000-0000-0000-0000-000000000001"])
                self.assertTrue(observations and all(i < deletion for i in observations))
                attempts = [call for call in calls if "test-without-building" in call]
                self.assertEqual(len(attempts), 1)
                selected = [arg.rsplit("/", 1)[1] for arg in attempts[0]
                            if arg.startswith("-only-testing:")]
                self.assertEqual(selected, list(manifest.phase_tests(manifest.SHARDS["B"], "before-settings")))
                sizes = [call[-1] for call in calls if "content_size" in call]
                self.assertEqual(sizes, ["large"])

    def test_failed_final_notification_batch_is_not_rescued_by_passed_scenarios(self):
        for ios in (26, 27):
            with self.subTest(ios=ios):
                result, calls = self.run_synthetic_runner(ios, "B", fail_notification=True)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout.count('TAKUPOKE_HOST_BOOT_FAILURE '), 1)
                host = next(i for i, call in enumerate(calls) if call[:2] == ["log", "show"])
                guest = next(i for i, call in enumerate(calls) if call[:3] == ["xcrun", "simctl", "spawn"])
                self.assertLess(host, guest)
                attempts = [call for call in calls if "test-without-building" in call]
                self.assertEqual(len(attempts), 5)
                selected = [arg.rsplit("/", 1)[1] for arg in attempts[-1]
                            if arg.startswith("-only-testing:")]
                self.assertEqual(selected, ["testNotificationControlsAndAppearance"])
                self.assertEqual([call[-1] for call in calls if "content_size" in call],
                                 ["large"] * (2 if ios == 26 else 1))

    def test_failed_fresh_notification_device_boot_stops_and_cleans_both_devices(self):
        result, calls = self.run_synthetic_runner(26, "B", fail_notification_boot=True)
        self.assertEqual(result.returncode, 47, result.stdout + result.stderr)
        attempts = [call for call in calls if "test-without-building" in call]
        self.assertEqual(len(attempts), 4, "Do not start or retry notifications after failed boot")
        self.assertEqual([call[-1] for call in calls if "content_size" in call], ["large"])
