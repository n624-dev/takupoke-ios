"""Dependency transport retries must not conceal failures or run any tests."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix", "Bash runner")
class PackageResolutionTests(unittest.TestCase):
    def resolve(self, statuses):
        with tempfile.TemporaryDirectory(prefix="takupoke-package-resolution-") as directory:
            root = Path(directory)
            binary = root / "xcodebuild"
            binary.write_text("#!" + sys.executable + "\n" + '''
import json, os, sys
from pathlib import Path
log=Path(os.environ['RESOLUTION_CALLS'])
calls=json.loads(log.read_text()) if log.exists() else []
calls.append(sys.argv[1:]);log.write_text(json.dumps(calls))
statuses=json.loads(os.environ['RESOLUTION_STATUSES'])
sys.exit(statuses[min(len(calls)-1,len(statuses)-1)])
''')
            binary.chmod(0o755)
            calls_file = root / "calls.json"
            # Spaces expose unsafe splitting in project/cache arguments.
            project = root / "Owned Project.xcodeproj"
            scratch = root / "Owned Scratch"
            env = os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"],
                                "RESOLUTION_CALLS": str(calls_file),
                                "RESOLUTION_STATUSES": json.dumps(statuses)}
            result = subprocess.run(["bash", str(ROOT / "tools/resolve-xcode-packages.sh"),
                                     str(project), "AppChecks", str(scratch)],
                                    env=env, capture_output=True, text=True, timeout=10)
            calls = json.loads(calls_file.read_text())
            for call in calls:
                self.assertEqual(call[0], "-resolvePackageDependencies")
                self.assertEqual(call[call.index("-project") + 1], str(project))
                for option, child in (("-derivedDataPath", "DerivedData"),
                                      ("-clonedSourcePackagesDirPath", "SourcePackages"),
                                      ("-packageCachePath", "PackageCache")):
                    self.assertEqual(call[call.index(option) + 1], str(scratch / child))
                self.assertIn("-disablePackageRepositoryCache", call)
                self.assertIn("-onlyUsePackageVersionsFromResolvedFile", call)
                self.assertNotIn("test", call)
                self.assertNotIn("build", call)
            return result, calls

    def test_transient_dependency_failure_is_bounded_and_can_recover(self):
        for statuses in ([0], [74, 0], [74, 74, 0]):
            with self.subTest(statuses=statuses):
                result, calls = self.resolve(statuses)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), len(statuses))

    def test_exhausted_resolution_preserves_failure_status(self):
        result, calls = self.resolve([74, 74, 65])
        self.assertEqual(result.returncode, 65)
        self.assertEqual(len(calls), 3)

    def test_cancellation_status_is_never_retried(self):
        for status in (130, 143):
            with self.subTest(status=status):
                result, calls = self.resolve([status, 0])
                self.assertEqual(result.returncode, status)
                self.assertEqual(len(calls), 1)


if __name__ == "__main__":
    unittest.main()
