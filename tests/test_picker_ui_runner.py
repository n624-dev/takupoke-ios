"""Exercise the actual picker orchestration with isolated Apple command doubles."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix", "Bash runner")
class PickerRunnerTests(unittest.TestCase):
    def test_picker_viewport_uses_one_complete_current_snapshot(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to exercise the picker viewport selector")
        swift = (ROOT / "tests/ui/MaterialPickerTapChecks.swift").read_text()
        body = swift.split("        func viewport() -> CGRect? {", 1)[1].split("        var undisturbedViewport", 1)[0]
        support = """import Foundation
enum Kind { case navigationBar, tabBar, collectionView, other }
struct Node {
    let elementType: Kind
    let identifier: String
    var label = ""
    let frame: CGRect
}
final class App {
    let nodes: [Node]
    var queryCount = 0
    init(_ nodes: [Node]) { self.nodes = nodes }
    func snapshot() throws -> [Node] { queryCount += 1; return nodes }
}
func snapshotNodes(in roots: [Node]) -> [Node]? { roots }
func capture(_ nodes: [Node]) -> CGRect? {
    let app = App(nodes)
    func viewport() -> CGRect? {
VIEWPORT
    let result = viewport()
    precondition(app.queryCount == 1)
    return result
}
let bar = Node(elementType: .navigationBar, identifier: "", label: "ファイル選択",
               frame: CGRect(x: 0, y: 24, width: 393, height: 93))
let tabs = Node(elementType: .tabBar, identifier: "", frame: CGRect(x: 90, y: 769, width: 213, height: 51))
let list = Node(elementType: .collectionView, identifier: "picker-file-list",
                frame: CGRect(x: 0, y: 50, width: 393, height: 802))
let unrelated = Node(elementType: .collectionView, identifier: "home", frame: list.frame)
let placeholder = Node(elementType: .other, identifier: list.identifier, frame: list.frame)
let clipped = Node(elementType: .collectionView, identifier: list.identifier,
                   frame: CGRect(x: 0, y: 810, width: 393, height: 40))
precondition(capture([bar, tabs, list, unrelated]) == CGRect(x: 0, y: 121, width: 393, height: 644))
for nodes in [[bar, tabs, unrelated], [bar, tabs, placeholder], [bar, tabs, clipped],
              [bar, bar, tabs, list], [bar, tabs, tabs, list], [bar, tabs, list, list]] {
    precondition(capture(nodes) == nil)
}
"""
        with tempfile.TemporaryDirectory(prefix="takupoke-picker-viewport-") as directory:
            root = Path(directory)
            source = root / "main.swift"
            source.write_text(support.replace("VIEWPORT", body))
            subprocess.run([compiler, "-module-cache-path", str(root / "modules"), str(source),
                            "-o", str(root / "test")], check=True, timeout=60)
            subprocess.run([str(root / "test")], check=True, timeout=15)

    def test_picker_lease_typechecks_with_only_picker_dependencies(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to type-check the production picker lease")
        with tempfile.TemporaryDirectory(prefix="takupoke-picker-lease-") as directory:
            stubs = Path(directory) / "PickerDependencies.swift"
            stubs.write_text("""import Foundation
enum MaterialError: Error { case accessExpired }
#if !canImport(Darwin)
extension URL {
    func startAccessingSecurityScopedResource() -> Bool { true }
    func stopAccessingSecurityScopedResource() {}
}
#endif
""")
            subprocess.run(
                [compiler, "-typecheck", str(stubs), str(ROOT / "Takupoke/ScopedMaterialSelection.swift")],
                check=True, timeout=30)

    def test_preparation_order_exact_completions_failures_and_owned_cleanup(self):
        fake = "#!" + sys.executable + "\n" + r'''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['COMMAND_LOG'], 'a') as log:
    log.write(json.dumps([Path(sys.argv[0]).name] + args) + '\n')
mode = os.environ['PICKER_TEST_MODE']
if Path(sys.argv[0]).name == 'xcode-select': print(os.environ['SYNTHETIC_DEVELOPER'])
elif Path(sys.argv[0]).name == 'xcodebuild':
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
        if mode!='identity-missing':
            print('TAKUPOKE_UI_EXECUTION_IDENTITY '+json.dumps({'case':'-[PickerTapChecks.MaterialPickerTapChecks '+name+']',
                'udid':'00000000-0000-0000-0000-000000000001','runtime':'27.0.0','simulatorCompileTarget':True,'pid':123}))
        print("Test Case '-[PickerTapChecks.MaterialPickerTapChecks " + name + "]' " + status + " (1.000 seconds).")
elif args[:2] == ['simctl', 'list']:
    print(json.dumps({'runtimes': [{'isAvailable': True, 'version': '27.0',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'}, {'isAvailable': True, 'version': '27.1', 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-1'}],
        'devicetypes': [{'name': 'iPhone 16', 'identifier': 'fictional-device'}],
        'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0':
            [{'udid': '00000000-0000-0000-0000-000000000001', 'state': 'Booted'}]}}))
elif args[:2] == ['simctl', 'create']: print('00000000-0000-0000-0000-000000000001')
elif args[:2] == ['simctl', 'boot'] and mode == 'boot-fails': sys.exit(8)
elif args[:2] == ['simctl', 'get_app_container']: print(os.environ['APP_DATA'])
elif args[:2] == ['simctl', 'launch']:
    (Path(os.environ['APP_DATA']) / 'Documents/result.txt').write_text(
        'FAIL: fictional transition failure' if mode == 'transition-fails' else 'PASS: fictional transitions')
'''
        for mode in ("success", "build-fails", "boot-fails", "test-fails",
                     "missing", "duplicate", "skipped", "transition-fails", "identity-missing"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="takupoke-picker-runner-") as directory:
                root = Path(directory)
                scratch = root / "scratch"
                scratch.mkdir()
                app_data = root / "app-data"
                (app_data / "Documents").mkdir(parents=True)
                developer = root / 'Xcode.app/Contents/Developer'
                developer.mkdir(parents=True)
                (developer.parent / 'Applications/DeviceHub.app').mkdir(parents=True)
                for name in ("xcrun", "xcodebuild", "xcode-select", "open", "codesign"):
                    path = root / name
                    path.write_text(fake)
                    path.chmod(0o755)
                log = root / "commands.jsonl"
                env = os.environ | {"PATH": directory + os.pathsep + os.environ["PATH"],
                    "TMPDIR": str(scratch), "APP_DATA": str(app_data),
                    "COMMAND_LOG": str(log), "PICKER_TEST_MODE": mode,
                    "SYNTHETIC_DEVELOPER": str(developer), "DEVELOPER_DIR": str(developer),
                    "PYTHONDONTWRITEBYTECODE": "1"}
                result = subprocess.run(["bash", "tools/test-picker-ui.sh"], cwd=ROOT,
                    env=env, capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode == 0, mode == "success", result.stdout + result.stderr)
                commands = [json.loads(line) for line in log.read_text().splitlines()]
                creates = [row for row in commands if row[:3] == ["xcrun", "simctl", "create"]]
                self.assertEqual(len(creates), 1)
                self.assertEqual(creates[0][-1], "com.apple.CoreSimulator.SimRuntime.iOS-27-0")
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
                screenshots = [row for row in commands if row[:3] == ["xcrun", "simctl", "io"] and row[4] == "screenshot"]
                self.assertEqual(len(screenshots), int(mode != "success"), result.stdout + result.stderr)
                if screenshots:
                    deletion = ["xcrun", "simctl", "delete", screenshots[0][3]]
                    self.assertLess(commands.index(screenshots[0]), commands.index(deletion))
                self.assertIn(["xcrun", "simctl", "delete", "00000000-0000-0000-0000-000000000001"], commands)
                self.assertEqual(list(scratch.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
