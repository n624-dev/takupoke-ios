"""Check the actual GitHub path filters for shared and nested research inputs."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github/workflows"


def paths(name):
    source = (WORKFLOWS / name).read_text()
    block = re.search(r"(?m)^    paths:\n((?:      - [^\n]+\n)+)", source)
    if not block:
        raise AssertionError("Missing push path filter: " + name)
    return [line.strip()[2:].strip("\"'") for line in block[1].splitlines()]


def selected(name, path):
    # GitHub's single * does not cross '/', while ** covers nested directories.
    for pattern in paths(name):
        tokens = re.split(r"(\*\*|\*|\?)", pattern)
        expression = "".join(".*" if part == "**" else "[^/]*" if part == "*" else "[^/]" if part == "?" else re.escape(part) for part in tokens)
        if re.fullmatch(expression, path):
            return True
    return False


class WorkflowSourcePathTests(unittest.TestCase):
    def test_new_nested_code_starts_development_catalog_checks(self):
        for path in ["tools/new-research/nested/probe.py", "tools/new-research/run.sh", "tools/root-probe.py"]:
            with self.subTest(path=path): self.assertTrue(selected("test-tools.yml", path))

    def test_original_code_recognition_tracks_its_shared_implementations(self):
        for path in ["tools/ocr-full-document-transfer/code_tail.py", "tools/ocr-windows-transfer/infer.py", "tools/ocr-windows-transfer/requirements.txt"]:
            with self.subTest(path=path): self.assertTrue(selected("ocr-code-english-screen.yml", path))

    def test_v6_parity_tracks_shared_input_preparation_and_numerical_runtime(self):
        for path in ["tools/ocr-windows-transfer/infer.py", "tools/ocr-windows-transfer/prepare.py", "tools/ocr-windows-transfer/frames.py", "tools/ocr-windows-transfer/requirements.txt"]:
            with self.subTest(path=path): self.assertTrue(selected("ocr-ios-runtime-parity.yml", path))

    def test_both_ocr_simulator_workflows_track_the_shared_failure_screenshot(self):
        for workflow in ("ocr-ios-runtime-parity.yml", "ocr-ios-ascii-runtime-parity.yml"):
            with self.subTest(workflow=workflow):
                self.assertTrue(selected(workflow, "tools/simulator_failure_screenshot.py"))
                self.assertTrue(selected(workflow, "tests/test_simulator_failure_screenshot.py"))

    def test_ocr_checks_can_run_without_a_permanent_research_branch(self):
        names = (
            "ocr-apple-native-diagnostic.yml", "ocr-code-english-screen.yml", "ocr-document-qualification.yml",
            "ocr-full-document-transfer.yml", "ocr-full-scope-source2x.yml", "ocr-ios-ascii-runtime-parity.yml",
            "ocr-ios-runtime-parity.yml", "ocr-legacy-line-screen.yml", "ocr-windows-transfer-screen.yml",
            "test-tools.yml",
        )
        for name in names:
            with self.subTest(workflow=name):
                source = (WORKFLOWS / name).read_text()
                self.assertIn("  workflow_dispatch:\n", source)
                self.assertIn("    branches: ['research/ocr/**']\n", source)
                self.assertNotIn("codex/pdf-local-recovery", source)

    def test_ordered_row_proof_is_manual_and_requires_generated_pdf_fixtures(self):
        source = (WORKFLOWS / "ordered-row-proof-native.yml").read_text()
        events = source.split("\non:\n", 1)[1].split("\npermissions:\n", 1)[0]
        self.assertEqual(events.strip(), "workflow_dispatch:")
        self.assertIn("permissions:\n  contents: read", source)
        self.assertLess(source.index("tools/ordered-row-e2e/generate.py"), source.index("bash tools/test-parsing.sh"))
        self.assertIn("TAKUPOKE_ORDERED_ROW_FIXTURES: ${{ runner.temp }}/ordered-row-e2e-owned", source)
        self.assertIn('test -s "$TAKUPOKE_ORDERED_ROW_FIXTURES/manifest.json"', source)
