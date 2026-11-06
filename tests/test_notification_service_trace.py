"""Bounded, read-only Simulator observations without publishing raw OS messages."""
import io
import json
import os
import shutil
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


def spooled_responses(*responses):
    remaining = iter(responses)

    def run(command, **kwargs):
        response = next(remaining)
        if isinstance(response, Exception):
            raise response
        if "stdout" not in kwargs:
            return response
        kwargs["stdout"].write((response.stdout or "").encode())
        kwargs["stderr"].write((response.stderr or "").encode())
        return subprocess.CompletedProcess(command, response.returncode)
    return run


class NotificationServiceTraceTests(unittest.TestCase):
    def test_shutdown_confirmation_requires_exact_owned_runtime_and_one_stopped_device(self):
        owned = "00000000-0000-0000-0000-000000000001"
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
        def payload(devices): return json.dumps({"devices": {runtime: devices}})
        stopped = {"udid": owned, "state": "Shutdown", "name": "PRIVATE"}
        cases = [(payload([stopped]), 0, True), (payload([stopped, stopped]), 0, False),
                 (payload([{**stopped, "state": "Booted"}]), 0, False),
                 (payload([{**stopped, "udid": "other"}]), 0, False),
                 (json.dumps({"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-0": [stopped]}}), 0, False),
                 (payload([]), 0, False), (payload([stopped]), 1, False),
                 ('{"devices":null}', 0, False), ('PRIVATE', 0, False), ('x' * 1048577, 0, False)]
        for output, code, expected in cases:
            with self.subTest(code=code, expected=expected), patch.object(notification_service_trace.subprocess,
                    "run", side_effect=spooled_responses(subprocess.CompletedProcess([], code, output, "PRIVATE"))) as run:
                self.assertEqual(notification_service_trace.confirmed_shutdown(owned, runtime), expected)
                self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "list", "devices", "-j"])
                self.assertEqual(run.call_args.kwargs["timeout"], 10)
        with patch.object(notification_service_trace.subprocess, "run", side_effect=spooled_responses(
                subprocess.TimeoutExpired([], 10))):
            self.assertFalse(notification_service_trace.confirmed_shutdown(owned, runtime))
        with patch.object(notification_service_trace.subprocess, "run") as run:
            self.assertFalse(notification_service_trace.confirmed_shutdown("other", runtime))
            self.assertFalse(notification_service_trace.confirmed_shutdown(owned, "wrong-runtime"))
            run.assert_not_called()

    def test_runtime_health_filters_owned_device_and_bounds_failed_observations(self):
        owned = "00000000-0000-0000-0000-000000000001"
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
        data = {"runtimes": [{"identifier": runtime, "isAvailable": True, "bundlePath": "PRIVATE"}],
                "devices": {runtime: [{"udid": owned, "state": "Booted", "name": "PRIVATE"},
                                      {"udid": "other", "state": "Shutdown"}]}}
        cases = [(json.dumps(data), 0, "available", "Booted"),
                 (json.dumps({"runtimes": [], "devices": {}}), 0, "missing-or-ambiguous", "missing-or-ambiguous"),
                 ("PRIVATE" * 400000, 0, "unknown", "unknown"),
                 ("PRIVATE", 1, "unknown", "unknown"),
                 ("invalid PRIVATE", 0, "invalid-format", "invalid-format")]
        for output, code, expected_runtime, expected_device in cases:
            with self.subTest(code=code, expected_runtime=expected_runtime):
                stream = io.StringIO()
                with patch.object(notification_service_trace.subprocess, "run", side_effect=spooled_responses(
                        subprocess.CompletedProcess([], code, output, "PRIVATE"))) as run, redirect_stdout(stream):
                    notification_service_trace.collect_runtime(owned, runtime)
                self.assertNotIn("PRIVATE", stream.getvalue())
                result = json.loads(stream.getvalue().split(" ", 1)[1])
                self.assertEqual(result["runtime"], expected_runtime)
                self.assertEqual(result["device"], expected_device)
                self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "list", "-j"])
                self.assertEqual(run.call_args.kwargs["timeout"], 10)
        with self.assertRaises(ValueError):
            notification_service_trace.collect_runtime("other", runtime)

    def test_boot_readiness_requires_one_actual_owned_native_identity_with_the_original_deadline(self):
        owned = "00000000-0000-0000-0000-000000000001"
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
        identity = {"udid": owned, "runtime": "26.5.0", "simulatorCompileTarget": True, "pid": 123}
        for latency, expected in ((0, True), (45, True), (46, False)):
            with self.subTest(latency=latency), patch.object(notification_service_trace, "observe_command",
                    return_value=subprocess.CompletedProcess([], 0, json.dumps(identity), "PRIVATE")) as observed, \
                 patch.object(notification_service_trace.time, "monotonic", side_effect=[0, latency]), \
                 redirect_stdout(io.StringIO()) as output:
                self.assertEqual(notification_service_trace.require_booted(owned, runtime, "/owned/identity"), expected)
                observed.assert_called_once_with(["xcrun", "simctl", "spawn", owned, "/owned/identity"], 45, max_bytes=4096)
                self.assertNotIn("PRIVATE", output.getvalue())
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(report["deadlineExceeded"], latency > 45)

    def test_boot_readiness_rejects_host_wrong_identity_bad_responses_and_failed_spawn_without_retry(self):
        owned = "00000000-0000-0000-0000-000000000001"
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
        valid = {"udid": owned, "runtime": "26.5.0", "simulatorCompileTarget": True, "pid": 123}
        invalid = [{**valid, "udid": "other"}, {**valid, "runtime": "27.0.0"},
                   {**valid, "runtime": "26.6.0"}, {**valid, "runtime": "26.5"},
                   {**valid, "simulatorCompileTarget": False}, {**valid, "simulatorCompileTarget": "true"},
                   *[{**valid, "pid": value} for value in (False, 0, -1, 2**31, "123")],
                   {key: value for key, value in valid.items() if key != "udid"},
                   {**valid, "unexpected": "PRIVATE"}, [], None]
        cases = [(json.dumps(value), 0) for value in invalid] + [
            ("invalid PRIVATE", 0), ("PRIVATE" * 600, 0),
            (json.dumps(valid) + json.dumps(valid), 0), (json.dumps(valid), 149), ("", -1)]
        for payload, code in cases:
            with self.subTest(payload=payload[:100], code=code), patch.object(notification_service_trace, "observe_command",
                    return_value=subprocess.CompletedProcess([], code, payload, "PRIVATE")) as observed, \
                 redirect_stdout(io.StringIO()) as output:
                self.assertFalse(notification_service_trace.require_booted(owned, runtime, "/owned/identity"))
                observed.assert_called_once()
                self.assertNotIn("PRIVATE", output.getvalue())
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(report["exit"], code)
        for target, version in (("other", runtime), (owned, "wrong-runtime")):
            with patch.object(notification_service_trace, "observe_command") as observed, self.assertRaises(ValueError):
                notification_service_trace.require_booted(target, version, "/owned/identity")
            observed.assert_not_called()

    @unittest.skipUnless(shutil.which("swiftc"), "Requires the host Swift compiler")
    def test_real_identity_program_cannot_prove_a_host_process_is_a_simulator(self):
        with tempfile.TemporaryDirectory(prefix="takupoke-identity-host-") as directory:
            executable = str(Path(directory) / "identity")
            built = subprocess.run(["swiftc", str(ROOT / "tools/simulator-ui-identity.swift"), "-o", executable],
                                   capture_output=True, text=True, timeout=120)
            self.assertEqual(built.returncode, 0, built.stderr)
            actual = subprocess.run([executable], env=os.environ | {"SIMULATOR_UDID":
                "00000000-0000-0000-0000-000000000001"}, capture_output=True, text=True, timeout=10)
            self.assertEqual(actual.returncode, 0, actual.stderr)
            record = json.loads(actual.stdout)
            self.assertIs(record["simulatorCompileTarget"], False)
            self.assertGreater(record["pid"], 0)
            with patch.object(notification_service_trace, "observe_command", return_value=actual):
                self.assertFalse(notification_service_trace.require_booted(record["udid"],
                    "com.apple.CoreSimulator.SimRuntime.iOS-26-5", executable))

    def test_boot_failure_observation_is_bounded_read_only_and_excludes_other_devices_and_private_fields(self):
        owned = "00000000-0000-0000-0000-000000000001"
        event = {"processImagePath": "/PRIVATE/CoreSimulatorService", "eventMessage": owned +
            ' boot failed PRIVATE Error Domain=com.apple.CoreSimulator.SimError Code=405'}
        entries = [event] * 45 + [{**event, "eventMessage": "other-device boot failed PRIVATE"},
                                 {**event, "processImagePath": "/PRIVATE/unknown-process"}]
        for payload, code, expected_events in ((json.dumps(entries), 0, 40),
                ('{"PRIVATE":true}', 0, 0), ("PRIVATE" * 400000, 0, 0), ("PRIVATE", -1, 0)):
            with self.subTest(code=code), patch.object(notification_service_trace, "observe_command",
                    return_value=subprocess.CompletedProcess([], code, payload, "PRIVATE timeout")) as observed, \
                 redirect_stdout(io.StringIO()) as output:
                notification_service_trace.collect_boot_failure(owned)
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(len(report["events"]), expected_events)
                if expected_events:
                    self.assertEqual(report["events"][0]["launchErrors"],
                                     [{"domain": "com.apple.CoreSimulator.SimError", "code": 405}])
                for private in ("PRIVATE", "other-device", "unknown-process", owned):
                    self.assertNotIn(private, output.getvalue())
                command = observed.call_args.args[0]
                self.assertEqual(command[:2], ["log", "show"])
                self.assertIn(owned, command[-1])
                self.assertEqual(observed.call_args.kwargs, {"max_bytes": 2097152})
                self.assertEqual(observed.call_args.args[1], 10)
        with patch.object(notification_service_trace, "observe_command") as observed, self.assertRaises(ValueError):
            notification_service_trace.collect_boot_failure("invalid")
        observed.assert_not_called()

    def test_launch_observation_keeps_nested_codes_without_private_error_details(self):
        bundle = notification_service_trace.BUNDLE
        message = (bundle + ' Error Domain=FBSOpenApplicationServiceErrorDomain Code=1 '
                   'UserInfo={private-token="架空の非公開文字列", '
                   'NSUnderlyingError={Error Domain=FBProcessExit Code=64 '
                   'NSUnderlyingError={Error Domain=RBSRequestErrorDomain Code=5 '
                   'NSUnderlyingError={Error Domain=NSPOSIXErrorDomain Code=153}}}}')
        result = notification_service_trace.observations([
            {"processImagePath": "/system/runningboardd", "eventMessage": message},
            {"processImagePath": "/system/launchd", "eventMessage": message},
            {"processImagePath": "/system/unknown", "eventMessage": message},
            {"processImagePath": "/system/launchd", "eventMessage":
             message.replace(bundle, "unknown-bundle")},
        ])
        self.assertEqual([row["process"] for row in result], ["runningboardd", "launchd"])
        self.assertEqual(result[0]["launchErrors"], [
            {"domain": "FBSOpenApplicationServiceErrorDomain", "code": 1},
            {"domain": "FBProcessExit", "code": 64},
            {"domain": "RBSRequestErrorDomain", "code": 5},
            {"domain": "NSPOSIXErrorDomain", "code": 153},
        ])
        for private in (bundle, "private-token", "架空の非公開文字列", "NSUnderlyingError", "UserInfo"):
            self.assertNotIn(private, json.dumps(result, ensure_ascii=False))

    def test_launch_error_codes_are_bounded_and_reject_unknown_domains_and_large_values(self):
        self.assertEqual(notification_service_trace.launch_error_codes(
            "Error Domain=PrivateDomain Code=1 Error Domain=NSPOSIXErrorDomain Code=2147483648 "
            "Error Domain=NSPOSIXErrorDomain Code=-2147483649 "
            "Error Domain=NSPOSIXErrorDomain Code=1234567890123"), [])
        result = notification_service_trace.launch_error_codes(
            "Error Domain=NSPOSIXErrorDomain Code=-1 " * 30)
        self.assertEqual(result, [{"domain": "NSPOSIXErrorDomain", "code": -1}] * 8)

    def test_accessibility_observation_has_only_known_services_and_fixed_words_in_order(self):
        messages = [
            {"processImagePath": "/system/VoiceOverTouch", "eventMessage":
             "speech service not ready private-opaque-123 架空の非公開文字列"},
            {"processImagePath": "/system/SpringBoard", "eventMessage": "unrelated private-detail"},
            {"processImagePath": "/system/unknown", "eventMessage": "VoiceOver failed"},
            {"processImagePath": "/system/backboardd", "eventMessage": "HID port failed private-token"},
        ]
        with patch.object(notification_service_trace.subprocess, "run") as run:
            run.side_effect = spooled_responses(subprocess.CompletedProcess([], 0,
                               "12 0 com.apple.VoiceOverTouch\n- -2 com.apple.accessibilityd\n"
                               "13 0 com.apple.VoiceOverTouch\n"
                               "- 2147483648 com.apple.voiceservicesd\n"
                               "- " + "9" * 5000 + " com.apple.AXUIServer\n"
                               "4 0 private-unknown-service\n"),
                               subprocess.CompletedProcess([], 0, json.dumps(messages)))
            with redirect_stdout(io.StringIO()) as output:
                notification_service_trace.collect_accessibility("owned-simulator")
            report = json.loads(output.getvalue().split(" ", 1)[1])
            self.assertEqual(report["services"], [
                {"service": "VoiceOverTouch", "running": True, "exit": 0},
                {"service": "accessibilityd", "running": False, "exit": -2}])
            self.assertEqual(report["events"], [
                {"process": "VoiceOverTouch", "words": ["speech", "service", "not", "ready"]},
                {"process": "backboardd", "words": ["HID", "port", "failed"]}])
            for private in ("private", "opaque", "token", "架空の非公開文字列"):
                self.assertNotIn(private, output.getvalue())
            self.assertEqual([call.kwargs["timeout"] for call in run.call_args_list], [5, 10])
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(commands[0][-2:], ["launchctl", "list"])
            self.assertEqual(commands[1][:6],
                             ["xcrun", "simctl", "spawn", "owned-simulator", "log", "show"])
            self.assertIn("--info", commands[1])

    def test_accessibility_failure_limits_do_not_emit_raw_text_or_mutate_os_state(self):
        entries = [{"processImagePath": "/system/VoiceOverTouch", "eventMessage":
                    "speech " * 40 + "private-payload"}] * 100
        timeout = subprocess.TimeoutExpired("private-command-detail", 5)
        for response, expected in (
            (subprocess.CompletedProcess([], 0, json.dumps(entries)), "bounded"),
            (subprocess.CompletedProcess([], 7, "private-output", "error private-token"), "failed"),
            (subprocess.CompletedProcess([], 0, "x" * (4 * 1024 * 1024 + 1)), "limited"),
            (subprocess.CompletedProcess([], 0, "{}"), "invalid-format"),
            (timeout, "failed"),
        ):
            with self.subTest(expected=expected), \
                 patch.object(notification_service_trace.subprocess, "run") as run:
                run.side_effect = spooled_responses(timeout, response)
                with redirect_stdout(io.StringIO()) as output:
                    notification_service_trace.collect_accessibility("owned-simulator")
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(report["healthExit"], -1)
                if expected == "bounded":
                    self.assertEqual(len(report["events"]), 80)
                    self.assertTrue(all(len(row["words"]) == 24 for row in report["events"]))
                else:
                    self.assertEqual(report["events"], expected)
                self.assertNotIn("private", output.getvalue())
                self.assertEqual(run.call_count, 2)

    def test_accessibility_service_report_rejects_oversized_health_output(self):
        health = "12 0 com.apple.VoiceOverTouch\n" * 3000
        with patch.object(notification_service_trace.subprocess, "run",
                          side_effect=spooled_responses(
                              subprocess.CompletedProcess([], 0, health),
                              subprocess.CompletedProcess([], 0, "[]"))):
            with redirect_stdout(io.StringIO()) as output:
                notification_service_trace.collect_accessibility("owned-simulator")
        report = json.loads(output.getvalue().split(" ", 1)[1])
        self.assertTrue(report["healthLimited"])
        self.assertEqual(report["services"], [])
        self.assertEqual(report["events"], [])

    def test_spooled_observation_bounds_real_stdout_stderr_and_keeps_exit_status(self):
        command = [sys.executable, "-c", "import sys; "
                   "sys.stdout.write('x' * 10000); sys.stderr.write('y' * 70000); sys.exit(7)"]
        result = notification_service_trace.observe_command(command, 5, max_bytes=1024)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, "x" * 1025)
        self.assertEqual(result.stderr, "y" * 65536)

    def test_notification_log_collection_bounds_memory_before_reporting_limit(self):
        original = notification_service_trace.observe_command
        captured = []
        def observe(command, timeout, *, max_bytes=None):
            if "log" not in command:
                return subprocess.CompletedProcess(command, 0, "", "")
            result = original([sys.executable, "-c", "import sys;sys.stdout.write('x'*(6*1024*1024))"],
                              timeout, max_bytes=max_bytes)
            captured.append(result.stdout)
            return result
        with patch.object(notification_service_trace, "observe_command", side_effect=observe):
            with redirect_stdout(io.StringIO()) as output:
                notification_service_trace.collect("owned-simulator", trace="")
        report = json.loads(output.getvalue().split(" ", 1)[1])
        self.assertEqual(report["events"], "limited")
        self.assertLessEqual(len(captured[0]), 4 * 1024 * 1024 + 1)
        self.assertEqual(report["logBytes"], len(captured[0].encode()))

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
                run.side_effect = spooled_responses(timeout if phase == "health" else health,
                                   timeout if phase == "log" else logs)
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
            run.side_effect = spooled_responses(subprocess.CompletedProcess([], 0, ""),
                               subprocess.CompletedProcess([], 0, "[]"))
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
            run.side_effect = spooled_responses(subprocess.CompletedProcess([], 0, "12 0 com.apple.usernotificationsd\n"),
                               subprocess.CompletedProcess([], 0, json.dumps(messages)))
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
                run.side_effect = spooled_responses(subprocess.CompletedProcess([], 0, ""), result)
                with redirect_stdout(io.StringIO()) as output:
                    notification_service_trace.collect("owned-simulator", trace="")
                report = json.loads(output.getvalue().split(" ", 1)[1])
                self.assertEqual(report["events"], expected)
                self.assertEqual(report["logExit"], result.returncode)
                self.assertEqual(report["logBytes"], len(result.stdout.encode()))
                self.assertNotIn("private-token", output.getvalue())
