"""Synthetic IPA fixtures only. All temporary files are cleaned automatically."""

import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import publish
import release


COMMIT = "a" * 40


class IPAFixture(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="takupoke-test-")
        self.addCleanup(self.scratch.cleanup)
        self.output = Path(self.scratch.name) / "output"
        self.output.mkdir()
        self.config = release.read_config()
        self.info = {
            "CFBundleIdentifier": self.config["bundleIdentifier"],
            "CFBundleShortVersionString": "0.1.12",
            "CFBundleVersion": "12.1",
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "Takupoke",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "MinimumOSVersion": "16.0",
            "TakupokeCommit": COMMIT,
        }

    def write_ipa(self, extra=None):
        with zipfile.ZipFile(self.output / "takupoke.ipa", "w") as archive:
            root = "Payload/Takupoke.app/"
            archive.writestr(root + "Info.plist", plistlib.dumps(self.info, fmt=plistlib.FMT_BINARY))
            # Deliberately synthetic; this fixture is never released or installed.
            archive.writestr(root + "Takupoke", b"\xcf\xfa\xed\xfe" + b"SYNTHETIC")
            archive.writestr(root + "Assets.car", b"SYNTHETIC")
            archive.writestr(root + "PrivacyInfo.xcprivacy", plistlib.dumps({"NSPrivacyTracking": False}))
            for name, content in (extra or {}).items():
                archive.writestr(name, content)

    def generate(self):
        self.write_ipa()
        return release.generate(self.output / "takupoke.ipa", self.output, "0.1.12", "12.1", COMMIT)


class DistributionTests(IPAFixture):
    def test_source_matches_ipa_and_immutable_download(self):
        self.generate()
        source = json.loads((self.output / "altstore-source.json").read_text())
        version = source["apps"][0]["versions"][0]
        self.assertEqual(version["size"], (self.output / "takupoke.ipa").stat().st_size)
        self.assertEqual(version["version"], self.info["CFBundleShortVersionString"])
        self.assertEqual(version["buildVersion"], self.info["CFBundleVersion"])
        self.assertIn("/v0.1.12-build.12.1/takupoke.ipa", version["downloadURL"])
        self.assertEqual(release.validate(self.output)["commit"], COMMIT)

    def test_metadata_mismatches_fail_before_source_generation(self):
        for key, value in (
            ("CFBundleIdentifier", "invalid.bundle"),
            ("CFBundleShortVersionString", "0.1.11"),
            ("CFBundleVersion", "11.1"),
            ("MinimumOSVersion", "17.0"),
            ("TakupokeCommit", "b" * 40),
            ("CFBundleSupportedPlatforms", ["iPhoneSimulator"]),
        ):
            with self.subTest(key=key):
                original = self.info[key]
                self.info[key] = value
                self.write_ipa()
                with self.assertRaises(ValueError):
                    release.generate(self.output / "takupoke.ipa", self.output, "0.1.12", "12.1", COMMIT)
                self.assertFalse((self.output / "altstore-source.json").exists())
                self.info[key] = original

    def test_undeclared_permissions_and_profiles_fail(self):
        self.info["NSCameraUsageDescription"] = "Synthetic"
        self.write_ipa()
        with self.assertRaisesRegex(ValueError, "privacy permissions"):
            release.inspect_ipa(self.output / "takupoke.ipa", self.config, "0.1.12", "12.1", COMMIT)
        del self.info["NSCameraUsageDescription"]
        self.write_ipa({"Payload/Takupoke.app/embedded.mobileprovision": b"SYNTHETIC"})
        with self.assertRaisesRegex(ValueError, "permission policy"):
            release.inspect_ipa(self.output / "takupoke.ipa", self.config, "0.1.12", "12.1", COMMIT)

    def test_modified_ipa_and_source_fail_validation(self):
        self.generate()
        with (self.output / "takupoke.ipa").open("ab") as stream:
            stream.write(b"changed")
        with self.assertRaisesRegex(ValueError, "checksum"):
            release.validate(self.output)
        self.generate()
        path = self.output / "altstore-source.json"
        source = json.loads(path.read_text())
        source["apps"][0]["versions"][0]["downloadURL"] = "https://example.invalid/app.ipa"
        release.write_json(path, source)
        metadata_path = self.output / "release.json"
        metadata = json.loads(metadata_path.read_text())
        metadata["sha256"][path.name] = release.sha256(path)
        release.write_json(metadata_path, metadata)
        with self.assertRaisesRegex(ValueError, "Source does not match"):
            release.validate(self.output)

    def test_unexpected_release_files_are_rejected(self):
        self.generate()
        (self.output / "private.txt").write_text("SYNTHETIC")
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            release.validate(self.output)

    def test_versions_increment_on_push_and_retry(self):
        self.assertEqual(release.versions(self.config, 12, 1), ("0.1.12", "12.1"))
        self.assertEqual(release.versions(self.config, 12, 2), ("0.1.12", "12.2"))
        self.assertEqual(release.versions(self.config, 13, 1), ("0.1.13", "13.1"))
        for run, attempt in ((0, 1), (10000, 1), (1, 0), (1, 100)):
            with self.assertRaises(ValueError):
                release.versions(self.config, run, attempt)

    def test_previous_versions_cannot_replace_newer_release(self):
        current = {"version": "0.1.12", "build": "12.2"}
        for candidate in (current, {"version": "0.1.11", "build": "11.9"}, {"version": "0.1.12", "build": "12.1"}):
            self.assertFalse(publish.release_is_newer(candidate, current))
        self.assertTrue(publish.release_is_newer({"version": "0.1.12", "build": "12.3"}, current))


class PublicationTests(IPAFixture):
    def setUp(self):
        super().setUp()
        self.metadata = self.generate()
        self.calls = []
        self.remote_files = {}
        self.main_commit = COMMIT
        self.fail_upload = False
        self.corrupt_download = False
        self.change_main_after_upload = False
        self.existing_draft = False
        self.previous_metadata = None
        self.fail_previous_download = False
        self.patch_env = patch.dict(os.environ, {
            "GITHUB_REPOSITORY": self.config["repository"],
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_SHA": COMMIT,
            "GITHUB_EVENT_NAME": "push",
        })
        self.patch_env.start()
        self.addCleanup(self.patch_env.stop)

    def fake_gh(self, *args):
        self.calls.append(args)
        if args[0] == "api":
            if args[-1].endswith("/commits/main"):
                return json.dumps({"sha": self.main_commit})
            if "/releases?" in args[-1]:
                if self.existing_draft:
                    return json.dumps([[{"tag_name": self.metadata["tag"], "draft": True,
                                         "prerelease": False, "target_commitish": COMMIT}]])
                if self.previous_metadata:
                    return json.dumps([[{"tag_name": "previous", "draft": False, "prerelease": False}]])
                return "[[]]"
            if args[-1].endswith("/releases/latest"):
                return json.dumps({"tag_name": "previous"})
            if "/releases/tags/" in args[-1]:
                return json.dumps({"draft": True, "assets": [
                    {"name": name, "state": "uploaded", "size": len(data)}
                    for name, data in self.remote_files.items()
                ]})
        if args[:2] in (("release", "create"), ("release", "upload")):
            if self.fail_upload:
                raise subprocess.CalledProcessError(1, "gh")
            self.remote_files = {name: (self.output / name).read_bytes() for name in release.ASSETS}
            if self.change_main_after_upload:
                self.main_commit = "b" * 40
            return ""
        if args[:2] == ("release", "download"):
            target = Path(args[args.index("--dir") + 1])
            if args[2] == "previous":
                if self.fail_previous_download:
                    raise subprocess.CalledProcessError(1, "gh")
                release.write_json(target / "release.json", self.previous_metadata)
                return ""
            for name, data in self.remote_files.items():
                (target / name).write_bytes(data + (b"corrupt" if self.corrupt_download else b""))
            return ""
        if args[:2] == ("release", "edit"):
            self.assertIn("--draft=false", args)
            self.assertIn("--latest", args)
            return ""
        raise AssertionError(f"Unexpected command: {args}")

    def published(self):
        return any(call[:2] == ("release", "edit") for call in self.calls)

    def test_publish_only_after_uploaded_bytes_match(self):
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.published())
        self.assertEqual(self.calls[-1][:2], ("release", "edit"))

    def test_upload_failure_does_not_publish(self):
        self.fail_upload = True
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            with self.assertRaises(subprocess.CalledProcessError):
                publish.publish(self.output)
        self.assertFalse(self.published())

    def test_corrupt_uploaded_asset_does_not_publish(self):
        self.corrupt_download = True
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            with self.assertRaisesRegex(ValueError, "checksum"):
                publish.publish(self.output)
        self.assertFalse(self.published())

    def test_stale_main_does_not_create_release(self):
        self.main_commit = "b" * 40
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertFalse(any(call[0] == "release" for call in self.calls))

    def test_main_changing_during_upload_leaves_draft(self):
        self.change_main_after_upload = True
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertFalse(self.published())

    def test_pull_requests_cannot_publish(self):
        with patch.dict(os.environ, {"GITHUB_EVENT_NAME": "pull_request"}):
            with patch.object(publish, "gh", side_effect=self.fake_gh):
                with self.assertRaisesRegex(ValueError, "restricted"):
                    publish.publish(self.output)
        self.assertEqual(self.calls, [])

    def test_existing_draft_can_be_retried_without_replacing_public_release(self):
        self.existing_draft = True
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.published())
        self.assertTrue(any(call[:2] == ("release", "upload") for call in self.calls))
        self.assertFalse(any(call[:2] == ("release", "create") for call in self.calls))

    def test_older_retry_does_not_overwrite_latest(self):
        self.previous_metadata = {"version": "0.1.13", "build": "13.1"}
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertFalse(self.published())
        self.assertFalse(any(call[:2] == ("release", "create") for call in self.calls))

    def test_cannot_read_previous_release_fails_closed(self):
        self.previous_metadata = {"version": "0.1.11", "build": "11.1"}
        self.fail_previous_download = True
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            with self.assertRaises(subprocess.CalledProcessError):
                publish.publish(self.output)
        self.assertFalse(self.published())

    def test_new_version_can_follow_previous_release(self):
        self.previous_metadata = {"version": "0.1.11", "build": "11.1"}
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.published())


if __name__ == "__main__":
    unittest.main()
