"""Verify actual Runner proofs and reject missing, duplicated or foreign UI execution."""
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
from ui_test_manifest import validate_execution_identities

OWNED = "00000000-0000-0000-0000-000000000001"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"
PREFIX = "TAKUPOKE_UI_EXECUTION_IDENTITY "


class UIExecutionIdentityTests(unittest.TestCase):
    def record(self, name="testFictionalFirst", **changes):
        return {"case": "-[PickerTapChecks.ApplicationChecks " + name + "]", "udid": OWNED,
                "runtime": "27.0.0", "simulatorCompileTarget": True, "pid": 123} | changes

    def test_every_selected_case_requires_one_actual_owned_runner_identity(self):
        names = ["testFictionalFirst", "testFictionalSecond"]
        log = "\n".join(PREFIX + json.dumps(self.record(name)) for name in names)
        validate_execution_identities(log, names, OWNED, RUNTIME, "ApplicationChecks")
        with self.assertRaises(ValueError):
            validate_execution_identities("", [], OWNED, RUNTIME, "ApplicationChecks")
        with self.assertRaises(ValueError):
            validate_execution_identities(log, names, OWNED, RUNTIME, "ManualAssistanceChecks")
        with self.assertRaises(ValueError):
            validate_execution_identities(log, names, OWNED, RUNTIME, "MaterialPickerTapChecks")
        for suite in ("ManualAssistanceChecks", "MaterialPickerTapChecks"):
            own_log = log.replace("ApplicationChecks", suite)
            validate_execution_identities(own_log, names, OWNED, RUNTIME, suite)

    def test_missing_duplicated_foreign_host_and_malformed_proofs_fail_closed(self):
        good = self.record()
        invalid = [self.record(udid="00000000-0000-0000-0000-000000000002"), self.record(udid="invalid"),
                   self.record(runtime="26.5.0"), self.record(runtime="27.1.0"), self.record(runtime="27.0"),
                   self.record(simulatorCompileTarget=False), self.record(simulatorCompileTarget="true"),
                   *[self.record(pid=value) for value in (False, 0, -1, 2**31, "123")],
                   self.record(name="testFictionalOther"), self.record(case="PRIVATE"),
                   self.record(unexpected="PRIVATE"), {key: value for key, value in good.items() if key != "udid"},
                   [], None]
        logs = ["", PREFIX + json.dumps(good) + "\n" + PREFIX + json.dumps(good), PREFIX + "PRIVATE",
                PREFIX + "PRIVATE" * 600, PREFIX + json.dumps(good)[:-1] + ',"pid":123}']
        logs.extend(PREFIX + json.dumps(value) for value in invalid)
        for log in logs:
            with self.subTest(log=log[:100]), self.assertRaises(ValueError) as failure:
                validate_execution_identities(log, ["testFictionalFirst"], OWNED, RUNTIME, "ApplicationChecks")
            self.assertNotIn("PRIVATE", str(failure.exception))

    @unittest.skipUnless(shutil.which("swiftc"), "Requires the host Swift compiler")
    def test_real_swift_identity_cannot_certify_a_host_process_as_a_simulator(self):
        with tempfile.TemporaryDirectory(prefix="takupoke-ui-identity-host-") as directory:
            root = Path(directory)
            (root / "main.swift").write_text(
                '''import XCTest
class ApplicationChecks: XCTestCase {}
let canonical = try simulatorExecutionCaseName(
    caseName: "-[ApplicationChecks testFictionalFirst]", testClass: ApplicationChecks.self)
precondition(canonical == "-[PickerTapChecks.ApplicationChecks testFictionalFirst]")
for invalid in ["-[OtherChecks testFictionalFirst]", "-[OtherModule.ApplicationChecks testFictionalFirst]",
                "ApplicationChecks.testFictionalFirst", "-[ApplicationChecks testFictionalFirst"] {
    do {
        _ = try simulatorExecutionCaseName(caseName: invalid, testClass: ApplicationChecks.self)
        fatalError("Invalid actual class/name accepted")
    } catch {}
}
print(try simulatorExecutionIdentity(caseName: canonical))
''')
            built = subprocess.run(["swiftc", str(ROOT / "tests/Support/SimulatorIdentityTestCase.swift"),
                                    str(root / "main.swift"), "-module-name", "PickerTapChecks",
                                    "-module-cache-path", str(root / "modules"),
                                    "-o", str(root / "identity")], capture_output=True, text=True, timeout=120)
            self.assertEqual(built.returncode, 0, built.stderr)
            actual = subprocess.run([str(root / "identity")], capture_output=True, text=True, timeout=10,
                                    env=os.environ | {"SIMULATOR_UDID": OWNED})
            self.assertEqual(actual.returncode, 0, actual.stderr)
            record = json.loads(actual.stdout)
            self.assertEqual(record["case"], "-[PickerTapChecks.ApplicationChecks testFictionalFirst]")
            self.assertIs(record["simulatorCompileTarget"], False)
            self.assertGreater(record["pid"], 0)
            with self.assertRaises(ValueError):
                validate_execution_identities(PREFIX + actual.stdout, ["testFictionalFirst"], OWNED,
                                              RUNTIME, "ApplicationChecks")
