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

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import ui_test_manifest as manifest


@unittest.skipUnless(os.name == "posix", "macOS CI Bash runner")
class ShellRunnerTests(unittest.TestCase):
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
        self.assertIn("runs-on: ${{ matrix.ios == 26 && 'macos-26' || 'xcode-27' }}", workflow)

    def test_alternate_toolchain_preflight_requires_requested_sdk_and_same_runtime(self):
        workflow = (ROOT / ".github/workflows/application-relaunch-native-probe.yml").read_text()
        block = workflow.split("- name: Require comparison toolchain and unchanged runtime\n        run: |\n", 1)[1]
        script = textwrap.dedent(block.split("\n      - name:", 1)[0])
        with tempfile.TemporaryDirectory(prefix="takupoke-sdk-preflight-") as directory:
            root = Path(directory)
            fake = "#!" + sys.executable + "\n" + '''
import json, os, sys
if sys.argv[1:2] == ['--sdk']: print(os.environ['OBSERVED_SDK'])
elif sys.argv[1:2] == ['simctl']:
    print(json.dumps({'runtimes': [{'isAvailable': True, 'version': os.environ['OBSERVED_RUNTIME'],
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + os.environ['OBSERVED_RUNTIME'].replace('.', '-')}]}))
else: print('Synthetic Xcode version')
'''
            for name in ("xcodebuild", "xcrun"):
                path = root / name
                path.write_text(fake)
                path.chmod(0o755)
            for ios, sdk, runtime, success in ((27, "27.1", "27.0", True),
                                             (27, "27.0", "27.0", False),
                                             (27, "27.1", "27.1", False),
                                             (27, "27.1", "26.5", False),
                                             (26, "26.6", "26.5", True)):
                with self.subTest(ios=ios, sdk=sdk, runtime=runtime):
                    env = os.environ | {"PATH": directory + os.pathsep + os.environ["PATH"],
                        "TKPK_TEST_IOS": str(ios), "TKPK_UI_PROBE_SDK27": "27.1",
                        "OBSERVED_SDK": sdk, "OBSERVED_RUNTIME": runtime}
                    result = subprocess.run(["bash", "-c", script], env=env,
                                            capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def run_synthetic_runner(self, ios, shard, *, omit_result=False, fail_build=False,
                             fail_frontend=False, fail_device_window=False,
                             missing_frontend=False, probe_case=None, fail_tests=False,
                             duplicate_result=False, fail_notification=False,
                             fail_notification_boot=False):
        with tempfile.TemporaryDirectory(prefix="takupoke-shard-check-") as directory:
            repo = Path(directory)
            (repo / "tools").mkdir()
            (repo / "tests/ui").mkdir(parents=True)
            (repo / "bin").mkdir()
            (repo / "scratch").mkdir()
            for name in ("test-app-ui.sh", "resolve-xcode-packages.sh", "ui_test_manifest.py", "timed_command.py",
                         "notification_service_trace.py"):
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
        print(f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).",
              file=sys.stderr if os.environ['TKPK_TEST_IOS'] == '26' else sys.stdout)
    if 'test-without-building' in args and os.environ.get('FAIL_TESTS'): sys.exit(45)
    if os.environ.get('FAIL_NOTIFICATION') and tests == ['testNotificationControlsAndAppearance']: sys.exit(46)
elif Path(sys.argv[0]).name == 'xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif Path(sys.argv[0]).name == 'open' and os.environ.get('FAIL_FRONTEND'): sys.exit(43)
elif (Path(sys.argv[0]).name == 'open' and os.environ.get('FAIL_DEVICE_WINDOW')
      and any(arg.startswith('devices://') for arg in args)): sys.exit(44)
elif args[:2] == ['simctl', 'list']:
    major = os.environ['TKPK_TEST_IOS']
    print(json.dumps({'runtimes': [{'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + major + '-5', 'version': major + '.5'}],
                      'devicetypes': [{'name': 'iPhone 16', 'identifier': 'synthetic-device'}]}))
elif args[:2] == ['simctl', 'create']:
    creates = sum(json.loads(line)[1:3] == ['simctl', 'create']
                  for line in Path(os.environ['CALLS']).read_text().splitlines())
    print('synthetic-simulator' if creates == 1 else 'synthetic-simulator-notifications')
elif (args[:3] == ['simctl', 'bootstatus', 'synthetic-simulator-notifications']
      and os.environ.get('FAIL_NOTIFICATION_BOOT')): sys.exit(47)
elif args[:2] == ['simctl', 'get_app_container']: print(os.environ['APP_CONTAINER'])
'''
            for tool in ("xcrun", "xcodebuild", "xcode-select", "open"):
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
                "APP_CONTAINER": str(repo / "container"), "SYNTHETIC_DEVELOPER": str(developer),
            }
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
            self.assertIn(["xcrun", "simctl", "shutdown", "synthetic-simulator"], calls)
            self.assertIn(["xcrun", "simctl", "delete", "synthetic-simulator"], calls)
            if len([call for call in calls if call[:3] == ["xcrun", "simctl", "create"]]) == 2:
                self.assertIn(["xcrun", "simctl", "shutdown", "synthetic-simulator-notifications"], calls)
                self.assertIn(["xcrun", "simctl", "delete", "synthetic-simulator-notifications"], calls)
            return result, calls

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
                    ["xcrun", "simctl", "spawn", "synthetic-simulator", "log", "show"]]
                self.assertEqual(len(observation), 1)
                self.assertLess(calls.index(build), calls.index(observation[0]))
                self.assertLess(calls.index(observation[0]), calls.index(
                    ["xcrun", "simctl", "shutdown", "synthetic-simulator"]))
                self.assertIn("TAKUPOKE_NOTIFICATION_SERVICES ", result.stdout)

    def test_both_shards_on_both_os_preserve_selection_and_os_size_checks(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                with self.subTest(ios=ios, shard=shard):
                    result, calls = self.run_synthetic_runner(ios, shard)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn(["project", "1" if ios == 27 else "0"], calls)
                    resolutions = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" in call]
                    self.assertEqual(len(resolutions), 1)
                    builds = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" not in call]
                    self.assertEqual(len(builds), 6 if shard == "B" else 3)
                    self.assertEqual(builds[0][-1], "build-for-testing")
                    self.assertFalse(any(arg.startswith("-only-testing:") for arg in builds[0]))
                    boot = ["xcrun", "simctl", "boot", "synthetic-simulator"]
                    self.assertLess(calls.index(builds[0]), calls.index(boot))
                    frontends = [call for call in calls if call[0] == "open"]
                    self.assertEqual(len(frontends), 2)
                    frontend = frontends[0]
                    self.assertEqual(Path(frontend[2]).name, "Simulator.app" if ios == 26 else "DeviceHub.app")
                    self.assertEqual(frontend[3:], ["--args", "-CurrentDeviceUDID", "synthetic-simulator"]
                                     if ios == 26 else [])
                    self.assertLess(calls.index(boot), calls.index(frontend))
                    self.assertLess(calls.index(frontend), calls.index(builds[1]))
                    if ios == 27:
                        window = frontends[1]
                        self.assertEqual(window[1:3], frontend[1:3])
                        self.assertEqual(window[3:], ["devices://device/open?id=synthetic-simulator"])
                        ready = ["xcrun", "simctl", "bootstatus", "synthetic-simulator", "-b"]
                        self.assertLess(calls.index(ready), calls.index(window))
                        self.assertLess(calls.index(window), calls.index(builds[1]))
                    self.assertTrue(all(build[-1] == "test-without-building" for build in builds[1:]))
                    remaining = [arg.rsplit("/", 1)[1] for arg in builds[1]
                                 if arg.startswith("-only-testing:")]
                    self.assertEqual(remaining, [test for test in manifest.SHARDS[shard]
                                                if test not in manifest.NOTIFICATION_PROBE_TESTS])
                    tests = [arg.rsplit("/", 1)[1] for arg in builds[2] if arg.startswith("-only-testing:")]
                    self.assertEqual(tests, [test for test in manifest.SHARDS[shard]
                                             if test in manifest.NOTIFICATION_PROBE_TESTS])
                    self.assertEqual(set(tests) & set(remaining), set())
                    self.assertEqual(len(tests + remaining), len(manifest.SHARDS[shard]))
                    self.assertEqual(sorted(tests + remaining), sorted(manifest.SHARDS[shard]))
                    if ios == 26:
                        retired = ["xcrun", "simctl", "delete", "synthetic-simulator"]
                        ready = ["xcrun", "simctl", "bootstatus", "synthetic-simulator-notifications", "-b"]
                        self.assertLess(calls.index(builds[1]), calls.index(retired))
                        self.assertLess(calls.index(retired), calls.index(ready))
                        self.assertLess(calls.index(ready), calls.index(builds[2]))
                        self.assertIn("platform=iOS Simulator,id=synthetic-simulator", builds[1])
                        self.assertTrue(all("platform=iOS Simulator,id=synthetic-simulator-notifications"
                                            in build for build in builds[2:]))
                        self.assertEqual(frontends[1][3:],
                                         ["--args", "-CurrentDeviceUDID", "synthetic-simulator-notifications"])
                    else:
                        self.assertEqual(sum(call[:3] == ["xcrun", "simctl", "create"] for call in calls), 1)
                        self.assertTrue(all("platform=iOS Simulator,id=synthetic-simulator" in build
                                            for build in builds))
                    sizes = [call[-1] for call in calls if call[:2] == ["xcrun", "simctl"]
                             and "content_size" in call]
                    self.assertEqual(sizes, ["large"] * (2 if ios == 26 else 1) + (["extra-small", "extra-extra-extra-large",
                        "accessibility-extra-extra-extra-large"] if shard == "B" else []))
                    for build in builds[3:]:
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
        self.assertNotIn(["xcrun", "simctl", "boot", "synthetic-simulator"], calls)
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
        self.assertTrue(any("devices://device/open?id=synthetic-simulator" in call for call in calls))

    def test_failed_or_duplicate_first_batch_stops_without_retry_or_size_checks(self):
        for flags, message in (({"fail_tests": True}, None),
                               ({"duplicate_result": True}, "XCTest completion differs")):
            with self.subTest(flags=flags):
                result, calls = self.run_synthetic_runner(26, "B", **flags)
                self.assertNotEqual(result.returncode, 0)
                if message:
                    self.assertIn(message, result.stderr)
                attempts = [call for call in calls if "test-without-building" in call]
                self.assertEqual(len(attempts), 1)
                selected = [arg.rsplit("/", 1)[1] for arg in attempts[0]
                            if arg.startswith("-only-testing:")]
                self.assertEqual(selected, [test for test in manifest.SHARDS["B"]
                                            if test not in manifest.NOTIFICATION_PROBE_TESTS])
                sizes = [call[-1] for call in calls if "content_size" in call]
                self.assertEqual(sizes, ["large"])

    def test_failed_final_notification_batch_is_not_rescued_by_passed_scenarios(self):
        for ios in (26, 27):
            with self.subTest(ios=ios):
                result, calls = self.run_synthetic_runner(ios, "B", fail_notification=True)
                self.assertNotEqual(result.returncode, 0)
                attempts = [call for call in calls if "test-without-building" in call]
                self.assertEqual(len(attempts), 2)
                selected = [arg.rsplit("/", 1)[1] for arg in attempts[-1]
                            if arg.startswith("-only-testing:")]
                self.assertEqual(selected, ["testNotificationControlsAndAppearance"])
                self.assertEqual([call[-1] for call in calls if "content_size" in call],
                                 ["large"] * (2 if ios == 26 else 1))

    def test_failed_fresh_notification_device_boot_stops_and_cleans_both_devices(self):
        result, calls = self.run_synthetic_runner(26, "B", fail_notification_boot=True)
        self.assertEqual(result.returncode, 47, result.stdout + result.stderr)
        attempts = [call for call in calls if "test-without-building" in call]
        self.assertEqual(len(attempts), 1, "Do not start or retry notifications after failed boot")
        self.assertEqual([call[-1] for call in calls if "content_size" in call], ["large"])
