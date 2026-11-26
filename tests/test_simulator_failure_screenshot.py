import base64
from contextlib import redirect_stdout
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import simulator_failure_screenshot as screenshot

DEVICE = "00000000-0000-0000-0000-000000000001"
IMAGE = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFh0AAAAASUVORK5CYII=")


class SimulatorFailureScreenshotTests(unittest.TestCase):
    def test_fallback_skips_a_complete_native_capture_and_keeps_once_limit(self):
        script = r'''
source tools/simulator-ci-trace.sh
python3() { printf 'fallback\n'; }
capture_failed_simulator_screen 1 "$1" "$2" "$2/native.log"
capture_failed_simulator_screen 1 "$1" "$2"
'''
        with tempfile.TemporaryDirectory() as scratch:
            for suffix, expected in (("END simulator-failure 1", ""),
                                     ("BEGIN simulator-failure abc 1", "fallback\n")):
                with self.subTest(suffix=suffix):
                    (Path(scratch) / "native.log").write_text("TAKUPOKE_UI_IMAGE " + suffix + "\n")
                    result = subprocess.run(["bash", "-euc", script, "bash", DEVICE, scratch],
                                            cwd=ROOT, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, expected)

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
