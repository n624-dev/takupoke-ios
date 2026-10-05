"""Hosted publication uses a prior qualified run and synthetic assets only."""
from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import development_publish_dispatch as hosted
import development_release as development
import test_development_release as fixtures
from test_distribution import IPAFixture, COMMIT


class HostedDevelopmentPublishTests(IPAFixture):
    context = fixtures.DevelopmentReleaseTests.context
    build = fixtures.DevelopmentReleaseTests.build
    fake = fixtures.DevelopmentReleaseTests.fake
    stage = fixtures.DevelopmentReleaseTests.stage

    def dispatch(self):
        return {"GITHUB_REPOSITORY": development.REPO,
                "GITHUB_REF": "refs/heads/" + development.BRANCH,
                "GITHUB_EVENT_NAME": "workflow_dispatch",
                "GITHUB_JOB": "development-publish", "GITHUB_RUN_ID": "999",
                "GITHUB_SHA": "b" * 40,
                "GITHUB_WORKFLOW_REF": development.REPO
                    + "/.github/workflows/ios-release.yml@refs/heads/" + development.BRANCH,
                "TKPK_DEVELOPMENT_MODE": "development-publish",
                "TKPK_DEVELOPMENT_RUN_ID": "123", "TKPK_DEVELOPMENT_SOURCE": COMMIT}

    def test_trusted_checkout_uses_prior_source_without_current_run_credit(self):
        self.assertEqual(hosted.check_context(self.dispatch(), "b" * 40), (123, COMMIT))

    def test_foreign_context_injected_inputs_and_current_run_are_refused(self):
        changes = (("GITHUB_REPOSITORY", "someone/other"), ("GITHUB_REF", "refs/heads/main"),
                   ("GITHUB_EVENT_NAME", "push"), ("GITHUB_JOB", "development-build"),
                   ("GITHUB_SHA", "b" * 7), ("GITHUB_WORKFLOW_REF", "other.yml"),
                   ("TKPK_DEVELOPMENT_MODE", "build"), ("TKPK_DEVELOPMENT_SOURCE", "a" * 7),
                   ("TKPK_DEVELOPMENT_SOURCE", COMMIT + "\nignored"),
                   ("TKPK_DEVELOPMENT_RUN_ID", "123; ignored"),
                   ("TKPK_DEVELOPMENT_RUN_ID", "0123"), ("TKPK_DEVELOPMENT_RUN_ID", "0"),
                   ("TKPK_DEVELOPMENT_RUN_ID", "999"), ("GITHUB_RUN_ID", ""))
        for key, value in changes:
            with self.subTest(key=key), self.assertRaises(ValueError):
                hosted.check_context(self.dispatch() | {key: value}, "b" * 40)
        with self.assertRaises(ValueError):
            hosted.check_context(self.dispatch(), COMMIT)

    def release_snapshot(self, path):
        return {"id": 42} if path.endswith("/releases/latest") else {"sha": "c" * 40}

    def test_prior_owned_stage_publishes_exact_three_and_records_cleanup_identity(self):
        self.build()
        with self.fake() as github, patch.object(hosted, "api", side_effect=self.release_snapshot), redirect_stdout(io.StringIO()):
            self.stage(github)
            github.run.update(status="completed", conclusion="success")
            output = Path(self.scratch.name) / "hosted-package"
            ownership = Path(self.scratch.name) / "hosted-output"
            hosted.publish_prior(123, COMMIT, output, ownership)
            self.assertEqual(ownership.read_text(), f"draft_id=789\nqualified_run_id=123\nqualified_source={COMMIT}\n")
            self.assertEqual(len(github.creations), 1)  # Prior staging only.
            self.assertEqual({a["name"] for a in github.drafts[789]["assets"]}, set(development.ASSETS))
            self.assertFalse(github.drafts[789]["draft"])
            self.assertTrue(github.drafts[789]["prerelease"])
            self.assertEqual(len(github.downloads), 12)
            self.assertIn("make_latest=false", github.finalizations[0])

    def test_prior_failure_cannot_claim_current_success_or_record_ownership(self):
        self.build()
        with self.fake() as github, patch.object(hosted, "api") as snapshots, redirect_stdout(io.StringIO()):
            self.stage(github)
            github.run.update(status="completed", conclusion="failure")
            ownership = Path(self.scratch.name) / "refused-output"
            before = len(github.downloads)
            with self.assertRaises(ValueError):
                hosted.publish_prior(123, COMMIT, Path(self.scratch.name) / "refused", ownership)
            self.assertFalse(ownership.exists())
            self.assertEqual(len(github.downloads), before)
            self.assertEqual(github.finalizations, [])
            snapshots.assert_not_called()

    def test_owned_id_change_refuses_upload_and_preserves_replacement(self):
        self.build()
        with self.fake() as github, redirect_stdout(io.StringIO()):
            self.stage(github)
            github.run.update(status="completed", conclusion="success")
            output = Path(self.scratch.name) / "prepared"
            metadata, attempt = development.prepare(123, COMMIT, output)
            before = list(github.uploaded)
            with self.assertRaisesRegex(ValueError, "draft changed"):
                development.publish(output, metadata, 123, attempt, COMMIT, expected_draft_id=888)
            self.assertEqual(github.uploaded, before)
            self.assertEqual(github.deleted_releases, [])
            self.assertEqual(github.finalizations, [])

    def test_changed_latest_or_main_is_reported_without_deleting_public_release(self):
        for changed in ("latest", "main"):
            with self.subTest(changed=changed):
                self.build()
                with self.fake() as github, redirect_stdout(io.StringIO()):
                    self.stage(github)
                    github.run.update(status="completed", conclusion="success")
                    replies = [{"id": 42}, {"sha": "c" * 40},
                               {"id": 43 if changed == "latest" else 42}, {"sha": "d" * 40}]
                    with patch.object(hosted, "api", side_effect=replies), self.assertRaisesRegex(ValueError, "Formal latest or main"):
                        hosted.publish_prior(123, COMMIT, Path(self.scratch.name) / changed,
                                             Path(self.scratch.name) / (changed + "-output"))
                    self.assertFalse(github.drafts[789]["draft"])
                    self.assertEqual(github.deleted_releases, [])

    def test_upload_failure_records_prior_owned_id_and_preserves_other_draft(self):
        self.build()
        with self.fake() as github, patch.object(hosted, "api", side_effect=self.release_snapshot), redirect_stdout(io.StringIO()):
            self.stage(github)
            github.run.update(status="completed", conclusion="success")
            github.drafts[777] = {"id": 777, "draft": True, "tag_name": "unrelated"}
            github.fail_upload = True
            ownership = Path(self.scratch.name) / "failed-output"
            with self.assertRaises(RuntimeError):
                hosted.publish_prior(123, COMMIT, Path(self.scratch.name) / "failed", ownership)
            self.assertIn("draft_id=789\n", ownership.read_text())
            self.assertEqual(github.deleted_releases, [789])
            self.assertIn(777, github.drafts)

    def test_workflow_publisher_is_independent_feature_only_without_build_or_artifact(self):
        workflow = (Path(__file__).resolve().parents[1] / ".github/workflows/ios-release.yml").read_text()
        publish = workflow.split("  development-publish:\n", 1)[1]
        self.assertNotIn("needs:", publish)
        self.assertIn("github.ref == 'refs/heads/codex/pdf-local-recovery'", publish)
        self.assertIn("inputs.mode == 'development-publish'", publish)
        self.assertIn("ref: ${{ github.sha }}", publish)
        self.assertIn("contents: write", publish)
        self.assertIn("actions: read", publish)
        self.assertNotIn("build-ios", publish)
        self.assertNotIn("upload-artifact", workflow)
        self.assertNotIn("actions/cache", workflow)
        self.assertIn('--run-id "$TKPK_QUALIFIED_RUN_ID"', publish)
        self.assertIn('--cleanup-draft "$TKPK_OWNED_DRAFT_ID"', publish)


if __name__ == "__main__":
    unittest.main()
