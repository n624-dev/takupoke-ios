"""Publication checks use synthetic Actions responses, never real requests."""
import copy
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import release_gate as gate


class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.context = dict(run_id=123, attempt=2, commit="a" * 40)
        self.run = dict(id=123, run_attempt=2, head_sha="a" * 40, head_branch="main",
                        event="push", repository=dict(full_name=gate.REPOSITORY))
        self.jobs = [dict(name=name, run_id=123, run_attempt=2, head_sha="a" * 40,
                          status="completed", conclusion="success") for name in sorted(gate.REQUIRED)]

    def snapshot(self):
        return gate.check_snapshot(self.run, self.jobs, **self.context)

    def test_all_required_jobs_succeed_while_release_itself_is_running(self):
        self.jobs.append(dict(name="Build and publish AltStore release", status="in_progress"))
        self.assertEqual(self.snapshot(), [])

    def test_missing_and_running_jobs_wait(self):
        missing = self.jobs.pop()["name"]
        self.jobs[0].update(status="in_progress", conclusion=None)
        self.assertEqual(self.snapshot(), sorted([missing, self.jobs[0]["name"]]))

    def test_each_required_job_is_individually_required(self):
        for index, job in enumerate(self.jobs):
            with self.subTest(name=job["name"]):
                remaining = self.jobs[:index] + self.jobs[index + 1:]
                self.assertEqual(gate.check_snapshot(self.run, remaining, **self.context), [job["name"]])
                failed = copy.deepcopy(self.jobs)
                failed[index]["conclusion"] = "failure"
                with self.assertRaisesRegex(ValueError, "did not succeed"):
                    gate.check_snapshot(self.run, failed, **self.context)

    def test_unsuccessful_completion_is_never_accepted(self):
        for conclusion in ["failure", "cancelled", "timed_out", "skipped", "neutral", None]:
            with self.subTest(conclusion=conclusion):
                self.jobs[0]["conclusion"] = conclusion
                with self.assertRaisesRegex(ValueError, "did not succeed"):
                    self.snapshot()

    def test_run_commit_attempt_branch_repository_and_event_are_checked(self):
        for key, value in [("id", 999), ("run_attempt", 3), ("head_sha", "b" * 40),
                           ("head_branch", "feature"), ("event", "pull_request"),
                           ("repository", {"full_name": "fictional/other"})]:
            with self.subTest(key=key):
                altered = self.run | {key: value}
                with self.assertRaisesRegex(ValueError, "unexpected run"):
                    gate.check_snapshot(altered, self.jobs, **self.context)

    def test_job_metadata_must_match_the_same_attempt_and_commit(self):
        for key, value in [("run_id", 999), ("run_attempt", 1), ("head_sha", "b" * 40)]:
            jobs = copy.deepcopy(self.jobs)
            jobs[0][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "another run"):
                gate.check_snapshot(self.run, jobs, **self.context)

    def test_duplicate_job_is_rejected(self):
        self.jobs.append(self.jobs[0].copy())
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.snapshot()

    def test_manual_main_run_is_allowed(self):
        self.run["event"] = "workflow_dispatch"
        self.assertEqual(self.snapshot(), [])

    def test_polling_uses_attempt_jobs_and_all_pages_until_success(self):
        now = [0]
        calls = []
        sleeps = []
        def read(path, *, pages=False):
            calls.append((path, pages))
            if not pages:
                return self.run
            jobs = copy.deepcopy(self.jobs)
            if now[0] == 0:
                jobs[0].update(status="in_progress", conclusion=None)
            return [{"jobs": jobs[:1]}, {"jobs": jobs[1:]}]
        def sleep(seconds):
            sleeps.append(seconds)
            now[0] += seconds
        gate.wait_for_checks(123, 2, "a" * 40, read=read, clock=lambda: now[0], sleep=sleep)
        self.assertEqual(sleeps, [60])
        self.assertEqual([p for p, paged in calls if paged],
                         [f"repos/{gate.REPOSITORY}/actions/runs/123/attempts/2/jobs?per_page=100"] * 2)

    def test_missing_job_times_out_with_bounded_wait(self):
        now = [0]
        def read(path, *, pages=False):
            return [{"jobs": []}] if pages else self.run
        def sleep(seconds): now[0] += seconds
        with self.assertRaises(TimeoutError):
            gate.wait_for_checks(123, 2, "a" * 40, timeout=70, read=read,
                                 clock=lambda: now[0], sleep=sleep)
        self.assertEqual(now[0], 70)

    def test_api_failure_aborts_instead_of_allowing_publication(self):
        def read(*args, **kwargs):
            raise subprocess.CalledProcessError(1, ["gh", "api"])
        with self.assertRaises(subprocess.CalledProcessError):
            gate.wait_for_checks(123, 2, "a" * 40, read=read)

    def test_cli_rejects_untrusted_context_without_api_calls(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(gate, "wait_for_checks") as wait:
            with patch.object(sys, "argv", ["release_gate.py"]):
                with self.assertRaisesRegex(ValueError, "trusted main"):
                    gate.main()
            wait.assert_not_called()
