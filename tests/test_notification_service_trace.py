"""Bounded, read-only Simulator observations without publishing raw OS messages."""
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import notification_service_trace


class NotificationServiceTraceTests(unittest.TestCase):
    def test_notification_evidence_survives_later_accessibility_noise_in_original_order(self):
        def entry(message):
            return {"processImagePath": "/system/SpringBoard", "eventMessage":
                    notification_service_trace.BUNDLE + " " + message + " private-payload"}
        messages = ([entry("authorization not granted")] + [entry("client connected")] * 120 +
                    [entry("permission prompt queued")])
        report = notification_service_trace.observations(messages)
        self.assertEqual(len(report), 80)
        self.assertEqual(report[0]["words"], ["authorization", "not", "granted"])
        self.assertEqual(report[-1]["words"], ["permission", "prompt", "queued"])
        self.assertTrue(all(row["words"] == ["client", "connected"] for row in report[1:-1]))
        crowded = [entry("authorization not granted")] * 90
        self.assertEqual(len(notification_service_trace.observations(crowded)), 80)
        self.assertNotIn("private-payload", json.dumps(report))
        self.assertEqual(notification_service_trace.fixed_words(
            "SBNotificationAuthorizationPrompt privateOpaqueIdentifier"),
            ["Notification", "Authorization", "Prompt"])

    def test_notification_observation_failures_preserve_the_other_readonly_phases(self):
        trace = "TAKUPOKE_LIFECYCLE pid=12 time=1000 stage=notification-auth-request\n"
        timeout = subprocess.TimeoutExpired("private-command-detail", 5)
        health = subprocess.CompletedProcess([], 0, "12 0 com.apple.usernotificationsd\n", "")
        logs = subprocess.CompletedProcess([], 0, "[]", "")
        for phase in ("health", "trace", "log"):
            with self.subTest(phase=phase), patch.object(notification_service_trace.subprocess, "run") as run, \
                 patch.object(notification_service_trace, "owned_trace") as owned:
                run.side_effect = [timeout if phase == "health" else health,
                                   timeout if phase == "log" else logs]
                owned.side_effect = timeout if phase == "trace" else None
                owned.return_value = trace
                with redirect_stdout(io.StringIO()) as output:
                    notification_service_trace.collect("owned-simulator", now=2800)
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(run.call_count, 2)
                self.assertEqual([call.kwargs["timeout"] for call in run.call_args_list], [5, 10])
                self.assertEqual(report["healthExit"], -1 if phase == "health" else 0)
                self.assertEqual(report["logExit"], -1 if phase == "log" else 0)
                self.assertEqual(report["events"], "failed" if phase == "log" else [])
                self.assertEqual(report["traceError"], "timeout" if phase == "trace" else None)
                self.assertEqual(report["window"] is None, phase == "trace")
                if phase != "health":
                    self.assertEqual(report["services"][0]["service"], "usernotificationsd")
                self.assertNotIn("private-command-detail", output.getvalue())

    def test_notification_window_uses_unanswered_request_even_when_failure_finishes_later(self):
        def row(pid, stamp, stage):
            return f"TAKUPOKE_LIFECYCLE pid={pid} time={stamp} stage=notification-auth-{stage}\n"
        trace = (row(1, 1000, "request") + row(1, 1001, "returned")
                 + row(2, 1200, "request") + row(2, 1201, "callback")
                 + row(2, 1202, "returned"))
        self.assertEqual(notification_service_trace.request_window(trace, 2800), {
            "time": 1000.0, "returned": True, "callback": False, "start": 995.0, "end": 1075.0})
        finished = notification_service_trace.request_window(trace + row(1, 1002, "callback"), 2800)
        self.assertEqual(finished["time"], 1200.0)
        self.assertTrue(finished["returned"] and finished["callback"])
        for invalid in ("private-payload", row(1, 10001, "request"), row(1, 1, "request")):
            self.assertIsNone(notification_service_trace.request_window(invalid, 10000))

    def test_notification_window_collects_only_bounded_owned_trace_and_request_interval(self):
        trace = "TAKUPOKE_LIFECYCLE pid=12 time=1000 stage=notification-auth-request\n"
        with tempfile.TemporaryDirectory(prefix="takupoke-request-window-owned-") as directory:
            root = Path(directory)
            owned = root / "tmp/takupoke-fictional-launch-owned.log"
            owned.parent.mkdir()
            owned.write_text(trace)
            response = subprocess.CompletedProcess([], 0, str(root) + "\n")
            with patch.object(notification_service_trace.subprocess, "run", return_value=response):
                self.assertEqual(notification_service_trace.owned_trace("owned-simulator"), trace)
                owned.write_bytes(b"x" * 65537)
                self.assertEqual(notification_service_trace.owned_trace("owned-simulator"), "")
                owned.unlink()
                other = root / "other-owned.txt"
                other.write_text(trace)
                owned.symlink_to(other)
                self.assertEqual(notification_service_trace.owned_trace("owned-simulator"), "")
        with patch.object(notification_service_trace.subprocess, "run") as run:
            run.side_effect = [subprocess.CompletedProcess([], 0, ""),
                               subprocess.CompletedProcess([], 0, "[]")]
            with redirect_stdout(io.StringIO()) as output:
                notification_service_trace.collect("owned-simulator", trace=trace, now=2800)
            command = run.call_args_list[1].args[0]
            self.assertNotIn("--last", command)
            self.assertEqual(command[command.index("--start") + 1], "1970-01-01 00:16:35+0000")
            self.assertEqual(command[command.index("--end") + 1], "1970-01-01 00:17:55+0000")
            report = json.loads(output.getvalue().split(" ", 1)[1])
            self.assertEqual(report["window"]["end"] - report["window"]["start"], 80)
            self.assertNotIn("pid", output.getvalue())

    def test_notification_service_trace_keeps_only_known_processes_and_fixed_words(self):
        messages = [
            {"processImagePath": "/system/usernotificationsd", "eventMessage":
             "authorization request " + notification_service_trace.BUNDLE + " secret-payload-123"},
            {"processImagePath": "/system/SpringBoard", "eventMessage": "unrelated authorization"},
            {"processImagePath": "/system/unknown", "eventMessage": notification_service_trace.BUNDLE},
            {"processImagePath": "/system/usernotificationsd", "eventMessage": "connection invalidated"},
            {"processImagePath": "/system/SpringBoard", "eventMessage":
             notification_service_trace.BUNDLE + " permission prompt queued visible false private-detail"},
        ]
        self.assertEqual(notification_service_trace.observations(messages), [
            {"process": "usernotificationsd", "words": ["authorization", "request"]},
            {"process": "usernotificationsd", "words": ["connection", "invalidated"]},
            {"process": "SpringBoard", "words": ["permission", "prompt", "queued", "visible", "false"]},
        ])
        self.assertEqual(notification_service_trace.observations([None, 123]), [])
        for malformed in ("text", {}, None):
            with self.assertRaises(ValueError):
                notification_service_trace.observations(malformed)

    def test_notification_service_trace_is_bounded_without_permission_mutation(self):
        messages = [{"processImagePath": "/system/usernotificationsd", "eventMessage":
                     "authorization " + "request " * 40}] * 100
        result = notification_service_trace.observations(messages)
        self.assertEqual(len(result), 80)
        self.assertTrue(all(len(entry["words"]) == 24 for entry in result))
        with patch.object(notification_service_trace.subprocess, "run") as run:
            run.side_effect = [subprocess.CompletedProcess([], 0, "12 0 com.apple.usernotificationsd\n"),
                               subprocess.CompletedProcess([], 0, json.dumps(messages))]
            with redirect_stdout(io.StringIO()) as output:
                notification_service_trace.collect("owned-simulator", trace="")
            self.assertIn('"running": true', output.getvalue())
            self.assertEqual(run.call_count, 2)
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(commands[0], ["xcrun", "simctl", "spawn", "owned-simulator", "launchctl", "list"])
            self.assertEqual(commands[1][:6], ["xcrun", "simctl", "spawn", "owned-simulator", "log", "show"])
            self.assertIn("--info", commands[1])
            self.assertEqual(commands[1][-2:], ["--predicate", notification_service_trace.LOG_PREDICATE])
            self.assertEqual([call.kwargs["timeout"] for call in run.call_args_list], [5, 10])
            for result, expected in (
                (subprocess.CompletedProcess([], 7, "", "unknown option private-token"), "failed"),
                (subprocess.CompletedProcess([], 0, "x" * (4 * 1024 * 1024 + 1)), "limited"),
                (subprocess.CompletedProcess([], 0, "not-json"), "invalid-format"),
            ):
                run.side_effect = [subprocess.CompletedProcess([], 0, ""), result]
                with redirect_stdout(io.StringIO()) as output:
                    notification_service_trace.collect("owned-simulator", trace="")
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(report["events"], expected)
                self.assertEqual(report["logExit"], result.returncode)
                self.assertEqual(report["logBytes"], len(result.stdout.encode()))
                self.assertNotIn("private-token", output.getvalue())

