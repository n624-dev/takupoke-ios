import base64
from contextlib import redirect_stdout
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from test_manual_input_lifecycle import block

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import simulator_failure_screenshot as screenshot

DEVICE = "00000000-0000-0000-0000-000000000001"
IMAGE = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFh0AAAAASUVORK5CYII=")


class SimulatorFailureScreenshotTests(unittest.TestCase):
    def test_xctest_warning_does_not_consume_the_single_failure_capture(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the shared screenshot hook")
        source = (ROOT / "tests/Support/SimulatorIdentityTestCase.swift").read_text(encoding="utf-8")
        # Supply the native severity and screenshot boundaries. The real
        # XCTest override decides whether to attempt a capture and still
        # reports every issue to its superclass.
        program = '''import Foundation
struct XCTIssue { let isFailure: Bool }
class Base {
    var received: [Bool] = []
    func record(_ issue: XCTIssue) { received.append(issue.isFailure) }
}
final class Hook: Base {
    private static var captured = 0
    private static var attempted = false
    @MainActor private static func recordFailureScreenshot() {
        if !attempted { captured += 1; attempted = true }
    }
    @MainActor static func run() {
        let probe = Hook()
        probe.record(XCTIssue(isFailure: false))
        precondition(captured == 0)
        probe.record(XCTIssue(isFailure: true))
        probe.record(XCTIssue(isFailure: false))
        probe.record(XCTIssue(isFailure: true))
        precondition(captured == 1)
        precondition(probe.received == [false, true, false, true])
    }
HOOK
}
@main struct Probe {
    @MainActor static func main() { Hook.run() }
}
'''.replace("HOOK", block(source, "override func record(_ issue: XCTIssue)"))
        with tempfile.TemporaryDirectory(prefix="takupoke-screenshot-issue-") as scratch:
            root = Path(scratch)
            swift = root / "hook.swift"
            swift.write_text(program, encoding="utf-8")
            binary = root / "hook"
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library", str(swift), "-o", str(binary)],
                           check=True, timeout=30)
            subprocess.run([str(binary)], check=True, timeout=10)

    def test_fallback_skips_a_complete_native_capture_and_keeps_once_limit(self):
        script = r'''
source tools/simulator-ci-trace.sh
python3() {
    if [[ "$3" == --verify-log ]]; then command python3 "$@"; else printf 'fallback\n'; fi
}
capture_failed_simulator_screen 1 "$1" "$2" "$2/native.log"
capture_failed_simulator_screen 1 "$1" "$2"
'''
        with tempfile.TemporaryDirectory() as scratch:
            begin = f"BEGIN simulator-failure {hashlib.sha256(IMAGE).hexdigest()} {len(IMAGE)}"
            data = "DATA simulator-failure 0 " + base64.b64encode(IMAGE).decode("ascii")
            end = "END simulator-failure 1"
            for frames, expected in (((begin, data, end), ""), ((end,), "fallback\n"),
                                     ((begin, end), "fallback\n"), ((begin, data[:-1], end), "fallback\n")):
                with self.subTest(frames=len(frames), expected=expected):
                    (Path(scratch) / "native.log").write_text("".join("TAKUPOKE_UI_IMAGE " + row + "\n" for row in frames))
                    result = subprocess.run(["bash", "-euc", script, "bash", DEVICE, scratch],
                                            cwd=ROOT, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, expected)

    def test_signal_exit_does_not_wait_for_screenshot_before_cleanup(self):
        script = r'''
source tools/simulator-ci-trace.sh
python3() { printf 'Unexpected capture\n'; }
capture_failed_simulator_screen 130 "$1" "$2"
capture_failed_simulator_screen 143 "$1" "$2"
'''
        with tempfile.TemporaryDirectory() as scratch:
            result = subprocess.run(["bash", "-euc", script, "bash", DEVICE, scratch],
                                    cwd=ROOT, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_capture_exact_device_once_with_checksummed_image_and_owned_cleanup(self):
        def run(args, **kwargs):
            self.assertEqual(args[:-1], ["xcrun", "simctl", "io", DEVICE, "screenshot"])
            self.assertEqual(kwargs["timeout"], 15)
            Path(args[-1]).write_bytes(IMAGE)
            return subprocess.CompletedProcess(args, 0)

        with tempfile.TemporaryDirectory() as scratch, patch.object(screenshot.subprocess, "run", side_effect=run) as command:
            output = io.StringIO()
            with redirect_stdout(output):
                screenshot.capture(DEVICE, scratch)
            command.assert_called_once()
            self.assertEqual(list(Path(scratch).iterdir()), [])
        begin, data, end = output.getvalue().splitlines()
        self.assertEqual(begin, f"TAKUPOKE_UI_IMAGE BEGIN simulator-failure {hashlib.sha256(IMAGE).hexdigest()} {len(IMAGE)}")
        self.assertEqual(base64.b64decode(data.split()[-1], validate=True), IMAGE)
        self.assertEqual(end, "TAKUPOKE_UI_IMAGE END simulator-failure 1")

    def test_rejects_device_alias_command_failure_and_invalid_image(self):
        def run(args, **_):
            if args[0] == "sips":
                return subprocess.CompletedProcess(args, 1)
            if self.mode == "timeout":
                raise subprocess.TimeoutExpired(args, 15)
            image = IMAGE[:-1] if self.mode == "truncated" else b"x" * (screenshot.MAX_IMAGE_BYTES + 1)
            Path(args[-1]).write_bytes(image)
            return subprocess.CompletedProcess(args, 1 if self.mode == "error" else 0)

        with tempfile.TemporaryDirectory() as scratch, patch.object(screenshot.subprocess, "run", side_effect=run) as command:
            screenshot.capture("booted", scratch)
            screenshot.capture("", scratch)
            command.assert_not_called()
            for self.mode in ("timeout", "error", "truncated", "large"):
                with self.subTest(mode=self.mode):
                    output = io.StringIO()
                    with redirect_stdout(output):
                        screenshot.capture(DEVICE, scratch)
                    reason = {"timeout": "timeout", "error": "unavailable exit=1",
                              "truncated": "invalid-or-too-large", "large": "invalid-or-too-large"}[self.mode]
                    self.assertEqual(output.getvalue().splitlines()[-1], "TAKUPOKE_SIMULATOR_FAILURE_SCREEN " + reason)
                    self.assertNotIn("TAKUPOKE_UI_IMAGE", output.getvalue())
                    self.assertEqual(list(Path(scratch).iterdir()), [])

    def test_normalizes_unusable_native_output_to_a_bounded_png(self):
        def run(args, **kwargs):
            if args[0] == "xcrun":
                Path(args[-1]).write_bytes(b"foreign image format")
            else:
                self.assertEqual(args[:6], ["sips", "-s", "format", "png", "-Z", "1024"])
                self.assertEqual(kwargs["timeout"], 5)
                self.assertEqual(Path(args[6]).read_bytes(), b"foreign image format")
                Path(args[-1]).write_bytes(IMAGE)
            return subprocess.CompletedProcess(args, 0)

        with tempfile.TemporaryDirectory() as scratch, patch.object(screenshot.subprocess, "run", side_effect=run) as command:
            output = io.StringIO()
            with redirect_stdout(output):
                screenshot.capture(DEVICE, scratch)
            self.assertEqual(command.call_count, 2)
            self.assertEqual(list(Path(scratch).iterdir()), [])
        lines = output.getvalue().splitlines()
        self.assertEqual(lines[0], "TAKUPOKE_SIMULATOR_FAILURE_SCREEN normalize reason=invalid-png")
        self.assertEqual(base64.b64decode(lines[2].split()[-1], validate=True), IMAGE)
