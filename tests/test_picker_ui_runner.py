"""Exercise the actual picker orchestration with isolated Apple command doubles."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix", "Bash runner")
class PickerRunnerTests(unittest.TestCase):
    def test_preparation_order_exact_completions_failures_and_owned_cleanup(self):
        fake = "#!" + sys.executable + "\n" + r'''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['COMMAND_LOG'], 'a') as log:
    log.write(json.dumps([Path(sys.argv[0]).name] + args) + '\n')
mode = os.environ['PICKER_TEST_MODE']
if Path(sys.argv[0]).name == 'xcodebuild':
    if args[-1] == 'build-for-testing':
        sys.exit(9 if mode == 'build-fails' else 0)
    assert args[-1] == 'test-without-building'
    if mode == 'test-fails': sys.exit(65)
    names = ['testInstructionSurroundMatchesFilesBackground',
        'testReselectionWithMissingAppearanceReturn', 'testReselectionThroughActualButtons']
    if mode == 'missing': names.pop()
    if mode == 'duplicate': names.append(names[0])
    for name in names:
        status = 'skipped' if mode == 'skipped' else 'passed'
        print("Test Case '-[PickerTapChecks.MaterialPickerTapChecks " + name + "]' " + status + " (1.000 seconds).")
elif args[:2] == ['simctl', 'list']:
    print(json.dumps({'runtimes': [{'isAvailable': True, 'version': '27.0',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'}],
        'devicetypes': [{'name': 'iPhone 16', 'identifier': 'fictional-device'}]}))
elif args[:2] == ['simctl', 'create']: print('fictional-owned-simulator')
elif args[:2] == ['simctl', 'boot'] and mode == 'boot-fails': sys.exit(8)
elif args[:2] == ['simctl', 'get_app_container']: print(os.environ['APP_DATA'])
elif args[:2] == ['simctl', 'launch']:
    (Path(os.environ['APP_DATA']) / 'Documents/result.txt').write_text(
        'FAIL: fictional transition failure' if mode == 'transition-fails' else 'PASS: fictional transitions')
'''
        for mode in ("success", "build-fails", "boot-fails", "test-fails",
                     "missing", "duplicate", "skipped", "transition-fails"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="takupoke-picker-runner-") as directory:
                root = Path(directory)
                scratch = root / "scratch"
                scratch.mkdir()
                app_data = root / "app-data"
                (app_data / "Documents").mkdir(parents=True)
                for name in ("xcrun", "xcodebuild"):
                    path = root / name
                    path.write_text(fake)
                    path.chmod(0o755)
                log = root / "commands.jsonl"
                env = os.environ | {"PATH": directory + os.pathsep + os.environ["PATH"],
                    "TMPDIR": str(scratch), "APP_DATA": str(app_data),
                    "COMMAND_LOG": str(log), "PICKER_TEST_MODE": mode,
                    "PYTHONDONTWRITEBYTECODE": "1"}
                result = subprocess.run(["bash", "tools/test-picker-ui.sh"], cwd=ROOT,
                    env=env, capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode == 0, mode == "success", result.stdout + result.stderr)
                commands = [json.loads(line) for line in log.read_text().splitlines()]
                builds = [row for row in commands if row[0] == "xcodebuild"]
                self.assertEqual(builds[0][-1], "build-for-testing")
                boots = [row for row in commands if row[:3] == ["xcrun", "simctl", "boot"]]
                self.assertEqual(len(boots), 0 if mode == "build-fails" else 1)
                if boots:
                    self.assertLess(commands.index(builds[0]), commands.index(boots[0]))
                if mode in ("build-fails", "boot-fails"):
                    self.assertEqual(len(builds), 1)
                else:
                    self.assertEqual(len(builds), 2)
                    self.assertEqual(builds[1][-1], "test-without-building")
                    self.assertEqual(builds[0][:-1], builds[1][:-1])
                    self.assertIn("-collect-test-diagnostics", builds[1])
                    self.assertIn("never", builds[1])
                launches = [row for row in commands if row[:3] == ["xcrun", "simctl", "launch"]]
                self.assertEqual(len(launches), int(mode in ("success", "transition-fails")))
                self.assertIn(["xcrun", "simctl", "delete", "fictional-owned-simulator"], commands)
                self.assertEqual(list(scratch.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
