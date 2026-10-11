"""Run the actual UI shell orchestration with isolated Apple command doubles."""
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
import ui_test_manifest as manifest


@unittest.skipUnless(os.name == "posix", "macOS CI Bash runner")
class ShellRunnerTests(unittest.TestCase):
    def run_synthetic_runner(self, ios, shard, *, omit_result=False, fail_build=False,
                             fail_frontend=False, missing_frontend=False, probe_case=None):
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
    for test in tests:
        status = 'skipped' if os.environ['TKPK_TEST_IOS'] == '26' and test == 'testVoiceOverReadsTimetableCard' else 'passed'
        print(f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).",
              file=sys.stderr if os.environ['TKPK_TEST_IOS'] == '26' else sys.stdout)
elif Path(sys.argv[0]).name == 'xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif Path(sys.argv[0]).name == 'open' and os.environ.get('FAIL_FRONTEND'): sys.exit(43)
elif args[:2] == ['simctl', 'list']:
    major = os.environ['TKPK_TEST_IOS']
    print(json.dumps({'runtimes': [{'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + major + '-5', 'version': major + '.5'}],
                      'devicetypes': [{'name': 'iPhone 16', 'identifier': 'synthetic-device'}]}))
elif args[:2] == ['simctl', 'create']: print('synthetic-simulator')
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
            if omit_result:
                environment["OMIT_RESULT"] = "1"
            if fail_build:
                environment["FAIL_BUILD"] = "1"
            if fail_frontend:
                environment["FAIL_FRONTEND"] = "1"
            if probe_case:
                environment.update(TKPK_UI_RELAUNCH_PROBE="1", TKPK_UI_PROBE_CASE=probe_case)
            result = subprocess.run(["bash", "tools/test-app-ui.sh"], cwd=repo, env=environment,
                                    capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()]
            self.assertEqual(list((repo / "scratch").iterdir()), [], "Owned scratch data must be removed")
            self.assertIn(["xcrun", "simctl", "shutdown", "synthetic-simulator"], calls)
            self.assertIn(["xcrun", "simctl", "delete", "synthetic-simulator"], calls)
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
                    self.assertEqual(len(builds), 5 if shard == "B" else 2)
                    self.assertEqual(builds[0][-1], "build-for-testing")
                    self.assertFalse(any(arg.startswith("-only-testing:") for arg in builds[0]))
                    boot = ["xcrun", "simctl", "boot", "synthetic-simulator"]
                    self.assertLess(calls.index(builds[0]), calls.index(boot))
                    frontends = [call for call in calls if call[0] == "open"]
                    self.assertEqual(len(frontends), 1)
                    frontend = frontends[0]
                    self.assertEqual(Path(frontend[2]).name, "Simulator.app" if ios == 26 else "DeviceHub.app")
                    self.assertEqual(frontend[3:], ["--args", "-CurrentDeviceUDID", "synthetic-simulator"]
                                     if ios == 26 else [])
                    self.assertLess(calls.index(boot), calls.index(frontend))
                    self.assertLess(calls.index(frontend), calls.index(builds[1]))
                    self.assertTrue(all(build[-1] == "test-without-building" for build in builds[1:]))
                    tests = [arg.rsplit("/", 1)[1] for arg in builds[1] if arg.startswith("-only-testing:")]
                    self.assertEqual(tests, list(manifest.SHARDS[shard]))
                    sizes = [call[-1] for call in calls if call[:2] == ["xcrun", "simctl"]
                             and "content_size" in call]
                    self.assertEqual(sizes, ["large"] + (["extra-small", "extra-extra-extra-large",
                        "accessibility-extra-extra-extra-large"] if shard == "B" else []))
                    for build in builds[2:]:
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
