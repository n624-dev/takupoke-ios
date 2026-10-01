"""Test selection, completion checks and the shell runner without Apple tools."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import release_gate
import ui_test_manifest as manifest


def result_line(test, status="passed"):
    return f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).\n"


class ManifestTests(unittest.TestCase):
    def test_all_source_tests_are_assigned_once_and_both_os_checks_are_required(self):
        manifest.validate_source((ROOT / "tests/ui/ApplicationChecks.swift").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest.selected_tests("all")), 18)
        self.assertFalse(set(manifest.SHARDS["A"]) & set(manifest.SHARDS["B"]))
        self.assertEqual(release_gate.REQUIRED, manifest.REQUIRED_JOBS | {"Distribution tests"})
        self.assertIn(manifest.SYSTEM_SIZE_TEST, manifest.SHARDS["B"])

    def test_missing_obsolete_or_duplicate_source_tests_fail(self):
        source = (ROOT / "tests/ui/ApplicationChecks.swift").read_text(encoding="utf-8")
        for altered in (source + "\nfunc testNewCase() {}",
                        source.replace("testMergedCardsFromAllSources", "testRenamedCase"),
                        source + "\nfunc testMergedCardsFromAllSources() {}"):
            with self.subTest(source=altered[-45:]), self.assertRaises(ValueError):
                manifest.validate_source(altered)

    def test_overlapping_manifest_is_rejected(self):
        with patch.dict(manifest.SHARDS, {"B": manifest.SHARDS["B"] + manifest.SHARDS["A"][:1]}):
            with self.assertRaisesRegex(ValueError, "duplicate tests"):
                manifest.validate_source((ROOT / "tests/ui/ApplicationChecks.swift").read_text(encoding="utf-8"))

    def test_passed_results_with_only_the_declared_voiceover_exception(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                expected = manifest.selected_tests(shard)
                log = "unrelated Xcode output\n" + "".join(result_line(
                    test, "skipped" if ios == 26 and test == manifest.VOICEOVER_TEST else "passed"
                ) for test in expected)
                manifest.validate_results(log, expected, ios)

    def test_empty_missing_extra_and_duplicate_results_fail(self):
        expected = manifest.selected_tests("A")
        log = "".join(result_line(test) for test in expected)
        for altered in ("", log.replace(result_line(expected[0]), ""),
                        log + result_line("testUnexpected"), log + result_line(expected[0])):
            with self.subTest(log=altered[-80:]), self.assertRaises(ValueError):
                manifest.validate_results(altered, expected, 27)

    def test_failure_and_unexpected_skip_fail(self):
        for test, ios, status in ((manifest.SYSTEM_SIZE_TEST, 26, "skipped"),
                                   (manifest.SYSTEM_SIZE_TEST, 27, "failed"),
                                   (manifest.VOICEOVER_TEST, 27, "skipped"),
                                   (manifest.VOICEOVER_TEST, 26, "passed")):
            with self.subTest(test=test, ios=ios, status=status), self.assertRaises(ValueError):
                manifest.validate_results(result_line(test, status), (test,), ios)

    def test_workflow_matrix_matches_gate_and_publish_follows_gate(self):
        workflow = (ROOT / ".github/workflows/ios-release.yml").read_text(encoding="utf-8")
        simulator = workflow.split("  simulator:\n", 1)[1].split("  build-check:\n", 1)[0]
        entries = re.findall(r"- ios: (26|27)\n\s+shard: ([AB])", simulator)
        self.assertEqual(len(entries), 4)
        self.assertEqual({f"Application iOS {ios} UI {shard}" for ios, shard in entries},
                         manifest.REQUIRED_JOBS)
        self.assertIn("name: Application iOS ${{ matrix.ios }} UI ${{ matrix.shard }}", simulator)
        self.assertIn("TKPK_UI_SHARD: ${{ matrix.shard }}", simulator)
        release = workflow.split("  release:\n", 1)[1]
        self.assertIn("needs: checks\n", release)
        self.assertIn("actions: read", release)
        self.assertLess(release.index("tools/release_gate.py"), release.index("tools/publish.py"))

    def test_cli_selects_the_complete_shard_and_rejects_invalid_shard(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        selected = subprocess.check_output(command + ["--shard", "A", "--mode", "selectors"], text=True)
        self.assertEqual(selected.splitlines(), [
            "-only-testing:PickerTapChecks/ApplicationChecks/" + test for test in manifest.SHARDS["A"]])
        invalid = subprocess.run(command + ["--shard", "C", "--mode", "selectors"],
                                 capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)

    def test_cli_reads_japanese_source_with_non_utf8_default_encoding(self):
        environment = os.environ | {"LC_ALL": "C", "PYTHONCOERCECLOCALE": "0", "PYTHONUTF8": "0"}
        result = subprocess.run([sys.executable, "-X", "utf8=0", "-B",
            str(ROOT / "tools/ui_test_manifest.py"), "--shard", "A", "--mode", "selectors"],
            env=environment, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), len(manifest.SHARDS["A"]))


@unittest.skipUnless(os.name == "posix", "macOS CI Bash runner")
class ShellRunnerTests(unittest.TestCase):
    def run_synthetic_runner(self, ios, shard, *, omit_result=False):
        with tempfile.TemporaryDirectory(prefix="takupoke-shard-check-") as directory:
            repo = Path(directory)
            (repo / "tools").mkdir()
            (repo / "tests/ui").mkdir(parents=True)
            (repo / "bin").mkdir()
            (repo / "scratch").mkdir()
            for name in ("test-app-ui.sh", "ui_test_manifest.py", "timed_command.py"):
                shutil.copyfile(ROOT / "tools" / name, repo / "tools" / name)
            shutil.copyfile(ROOT / "tests/ui/ApplicationChecks.swift", repo / "tests/ui/ApplicationChecks.swift")
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
    tests = [arg.rsplit('/', 1)[1] for arg in args if arg.startswith('-only-testing:')]
    if os.environ.get('OMIT_RESULT'): tests = tests[1:]
    for test in tests:
        status = 'skipped' if os.environ['TKPK_TEST_IOS'] == '26' and test == 'testVoiceOverReadsTimetableCard' else 'passed'
        print(f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).",
              file=sys.stderr if os.environ['TKPK_TEST_IOS'] == '26' else sys.stdout)
elif args[:2] == ['simctl', 'list']:
    major = os.environ['TKPK_TEST_IOS']
    print(json.dumps({'runtimes': [{'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + major + '-5', 'version': major + '.5'}],
                      'devicetypes': [{'name': 'iPhone 16', 'identifier': 'synthetic-device'}]}))
elif args[:2] == ['simctl', 'create']: print('synthetic-simulator')
elif args[:2] == ['simctl', 'get_app_container']: print(os.environ['APP_CONTAINER'])
'''
            for tool in ("xcrun", "xcodebuild"):
                path = repo / "bin" / tool
                path.write_text(fake)
                path.chmod(0o755)
            calls_file = repo / "calls"
            environment = os.environ | {
                "PATH": str(repo / "bin") + os.pathsep + os.environ["PATH"],
                "TMPDIR": str(repo / "scratch"), "TKPK_TEST_IOS": str(ios),
                "TKPK_UI_SHARD": shard, "CALLS": str(calls_file),
                "APP_CONTAINER": str(repo / "container"),
            }
            if omit_result:
                environment["OMIT_RESULT"] = "1"
            result = subprocess.run(["bash", "tools/test-app-ui.sh"], cwd=repo, env=environment,
                                    capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()]
            self.assertEqual(list((repo / "scratch").iterdir()), [], "Owned scratch data must be removed")
            self.assertIn(["xcrun", "simctl", "shutdown", "synthetic-simulator"], calls)
            self.assertIn(["xcrun", "simctl", "delete", "synthetic-simulator"], calls)
            return result, calls

    def test_both_shards_on_both_os_preserve_selection_and_os_size_checks(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                with self.subTest(ios=ios, shard=shard):
                    result, calls = self.run_synthetic_runner(ios, shard)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn(["project", "1" if ios == 27 else "0"], calls)
                    builds = [call for call in calls if call[0] == "xcodebuild"]
                    self.assertEqual(len(builds), 4 if shard == "B" else 1)
                    tests = [arg.rsplit("/", 1)[1] for arg in builds[0] if arg.startswith("-only-testing:")]
                    self.assertEqual(tests, list(manifest.SHARDS[shard]))
                    self.assertEqual(builds[0][-1], "test")
                    sizes = [call[-1] for call in calls if call[:2] == ["xcrun", "simctl"]
                             and "content_size" in call]
                    self.assertEqual(sizes, ["large"] + (["extra-small", "extra-extra-extra-large",
                        "accessibility-extra-extra-extra-large"] if shard == "B" else []))
                    for build in builds[1:]:
                        self.assertEqual(build[-1], "test-without-building")
                        self.assertIn("-only-testing:PickerTapChecks/ApplicationChecks/" + manifest.SYSTEM_SIZE_TEST, build)

    def test_missing_xctest_completion_fails_shell_and_cleans_up(self):
        result, calls = self.run_synthetic_runner(27, "B", omit_result=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("XCTest completion differs", result.stderr)
        self.assertEqual(len([call for call in calls if call[0] == "xcodebuild"]), 1)
