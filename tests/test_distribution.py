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
        self.notes = Path(self.scratch.name) / "notes.txt"
        self.notes.write_text("・架空の変更内容A\n・架空の変更内容B\n", encoding="utf-8")
        notes_patch = patch.object(release, "NOTES", self.notes)
        notes_patch.start()
        self.addCleanup(notes_patch.stop)
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

    def write_ipa(self, extra=None, executable=b"SYNTHETIC", policies=True):
        with zipfile.ZipFile(self.output / "takupoke.ipa", "w") as archive:
            root = "Payload/Takupoke.app/"
            archive.writestr(root + "Info.plist", plistlib.dumps(self.info, fmt=plistlib.FMT_BINARY))
            # Deliberately synthetic; this fixture is never released or installed.
            archive.writestr(root + "Takupoke", b"\xcf\xfa\xed\xfe" + executable)
            archive.writestr(root + "Assets.car", b"SYNTHETIC")
            if policies:
                for policy in ("terms", "privacy"):
                    archive.writestr(root + f"LegalDocuments/{policy}.txt", "Synthetic policy")
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
        self.assertEqual(version["localizedDescription"], self.notes.read_text().strip())
        self.assertEqual(release.validate(self.output)["commit"], COMMIT)

    def test_notes_are_snapshotted_and_must_match_source(self):
        self.generate()
        self.notes.write_text("・次の版の更新内容", encoding="utf-8")
        self.assertEqual(release.validate(self.output)["releaseNotes"], "・架空の変更内容A\n・架空の変更内容B")
        path = self.output / "release.json"
        metadata = json.loads(path.read_text())
        metadata["releaseNotes"] = "・別の更新内容"
        release.write_json(path, metadata)
        with self.assertRaisesRegex(ValueError, "Source does not match"):
            release.validate(self.output)

    def test_missing_or_empty_notes_stop_generation(self):
        self.write_ipa()
        self.notes.write_text(" \n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Release notes"):
            release.generate(self.output / "takupoke.ipa", self.output, "0.1.12", "12.1", COMMIT)
        self.assertFalse((self.output / "altstore-source.json").exists())
        self.notes.unlink()
        with self.assertRaises(FileNotFoundError):
            release.generate(self.output / "takupoke.ipa", self.output, "0.1.12", "12.1", COMMIT)

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

    def test_public_release_excludes_diagnostics_and_requires_bundled_policies(self):
        for marker in (b"TAKUPOKE-PDF-FULL-ZIP-1", b"TAKUPOKE-PDF-FULL-JSON-1"):
            self.write_ipa(executable=marker)
            with self.assertRaisesRegex(ValueError, "Internal diagnostics"):
                release.inspect_ipa(self.output / "takupoke.ipa", self.config, "0.1.12", "12.1", COMMIT)
        self.write_ipa(policies=False)
        with self.assertRaisesRegex(ValueError, "legal documents"):
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
        self.created_draft = False
        self.draft_available = True
        self.draft_published = False
        self.draft_commit = COMMIT
        self.missing_uploaded_asset = False
        self.wrong_uploaded_size = False
        self.fail_download = False
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

    def fake_gh(self, *args, output=None):
        self.calls.append(args)
        if args[0] == "api":
            endpoint = args[-1]
            method = args[args.index("--method") + 1] if "--method" in args else "GET"
            if endpoint.endswith("/commits/main"):
                return json.dumps({"sha": self.main_commit})
            if "/releases?" in endpoint:
                # Reproduce CI: newly created drafts never appear in the listing.
                items = []
                if self.existing_draft:
                    items.append({"id": 42, "tag_name": self.metadata["tag"], "draft": True,
                                  "prerelease": False, "target_commitish": COMMIT})
                if self.previous_metadata:
                    items.append({"tag_name": "previous", "draft": False, "prerelease": False})
                return json.dumps([items])
            if endpoint.endswith("/releases/latest"):
                return json.dumps({"tag_name": "previous"})
            if "/releases/tags/" in endpoint:
                raise AssertionError("Drafts must not be located by tag")
            if endpoint.endswith("/releases") and method == "POST":
                request = json.loads(Path(args[args.index("--input") + 1]).read_text())
                self.assertIs(request["draft"], True)
                self.assertEqual(request["target_commitish"], COMMIT)
                self.assertEqual(request["tag_name"], self.metadata["tag"])
                self.assertIn("\n\n", request["body"])
                self.assertIn(self.metadata["releaseNotes"], request["body"])
                self.created_draft = True
                self.remote_files = {}
                return json.dumps({"id": 42})
            if endpoint.endswith("/releases/42"):
                if method == "PATCH":
                    self.assertIn("draft=false", args)
                    self.assertIn("make_latest=true", args)
                    body = next(arg.removeprefix("body=") for arg in args if arg.startswith("body="))
                    self.assertIn(self.metadata["releaseNotes"], body)
                    return json.dumps({"id": 42, "draft": False,
                                       "tag_name": self.metadata["tag"], "target_commitish": COMMIT})
                if not self.draft_available:
                    raise subprocess.CalledProcessError(1, "gh", stderr="HTTP 404")
                assets = [
                    {"id": release.ASSETS.index(name) + 100, "name": name, "state": "uploaded",
                     "size": len(data) + int(self.wrong_uploaded_size)}
                    for name, data in self.remote_files.items()
                ]
                if self.missing_uploaded_asset and assets:
                    assets.pop()
                return json.dumps({"id": 42, "tag_name": self.metadata["tag"],
                                   "target_commitish": self.draft_commit,
                                   "draft": not self.draft_published, "assets": assets})
            if "/releases/42/assets?name=" in endpoint and method == "POST":
                if self.fail_upload:
                    raise subprocess.CalledProcessError(1, "gh")
                name = endpoint.split("?name=")[1]
                self.remote_files[name] = Path(args[args.index("--input") + 1]).read_bytes()
                if self.change_main_after_upload:
                    self.main_commit = "b" * 40
                return json.dumps({"id": 100 + release.ASSETS.index(name)})
            if "/releases/assets/" in endpoint:
                index = int(endpoint.rsplit("/", 1)[1]) - 100
                name = release.ASSETS[index]
                if method == "DELETE":
                    del self.remote_files[name]
                    return ""
                if self.fail_download:
                    raise subprocess.CalledProcessError(1, "gh")
                self.assertIn("Accept: application/octet-stream", args)
                self.assertIsNotNone(output)
                output.write_bytes(self.remote_files[name] + (b"corrupt" if self.corrupt_download else b""))
                return ""
        if args[:2] == ("release", "download") and args[2] == "previous":
            target = Path(args[args.index("--dir") + 1])
            if self.fail_previous_download:
                raise subprocess.CalledProcessError(1, "gh")
            release.write_json(target / "release.json", self.previous_metadata)
            return ""
        raise AssertionError(f"Unexpected command: {args}")

    def published(self):
        return any("PATCH" in call for call in self.calls)

    def test_publish_only_after_uploaded_bytes_match(self):
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.published())
        self.assertIn("PATCH", self.calls[-1])

    def test_unpublished_draft_is_verified_by_id_not_tag(self):
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.published())
        self.assertTrue(any(call[0] == "api" and call[-1].endswith("/releases/42") for call in self.calls))
        self.assertFalse(any(call[0] == "api" and "/releases/tags/" in call[-1] for call in self.calls))

    def test_new_draft_is_not_rediscovered_through_stale_listing(self):
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.created_draft)
        self.assertTrue(self.published())
        self.assertEqual(sum("/releases?" in call[-1] for call in self.calls), 1)

    def test_missing_draft_stops_before_publication(self):
        self.draft_available = False
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            with self.assertRaises(subprocess.CalledProcessError):
                publish.publish(self.output)
        self.assertFalse(self.published())

    def test_unexpected_draft_is_not_modified(self):
        for published, commit in ((True, COMMIT), (False, "b" * 40)):
            with self.subTest(published=published, commit=commit):
                self.draft_published, self.draft_commit = published, commit
                with patch.object(publish, "gh", side_effect=self.fake_gh):
                    with self.assertRaisesRegex(ValueError, "unexpected"):
                        publish.publish(self.output)
                self.assertFalse(self.published())
                self.assertEqual(self.remote_files, {})

    def test_incomplete_assets_stop_publication(self):
        for attribute in ("missing_uploaded_asset", "wrong_uploaded_size"):
            with self.subTest(attribute=attribute):
                setattr(self, attribute, True)
                with patch.object(publish, "gh", side_effect=self.fake_gh):
                    with self.assertRaisesRegex(ValueError, "asset mismatch|Incomplete"):
                        publish.publish(self.output)
                self.assertFalse(self.published())
                setattr(self, attribute, False)

    def test_asset_download_failure_stops_publication(self):
        self.fail_download = True
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            with self.assertRaises(subprocess.CalledProcessError):
                publish.publish(self.output)
        self.assertFalse(self.published())

    def test_binary_download_preserves_bytes(self):
        expected = b"\x00\xff\xfe\r\n"
        destination = Path(self.scratch.name) / "download.bin"
        def respond(command, *, stdout, check):
            self.assertTrue(check)
            stdout.write(expected)
        with patch.object(publish.subprocess, "run", side_effect=respond):
            publish.gh("api", "synthetic", output=destination)
        self.assertEqual(destination.read_bytes(), expected)

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
        self.assertEqual(len(self.calls), 1)

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
        self.remote_files = {name: b"old synthetic upload" for name in release.ASSETS}
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertTrue(self.published())
        self.assertTrue(any("/assets?name=" in call[-1] for call in self.calls))
        self.assertFalse(self.created_draft)
        self.assertEqual(sum("DELETE" in call for call in self.calls), len(release.ASSETS))

    def test_older_retry_does_not_overwrite_latest(self):
        self.previous_metadata = {"version": "0.1.13", "build": "13.1"}
        with patch.object(publish, "gh", side_effect=self.fake_gh):
            publish.publish(self.output)
        self.assertFalse(self.published())
        self.assertFalse(self.created_draft)

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
