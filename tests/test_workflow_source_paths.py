"""Check the actual GitHub path filters for shared and nested research inputs."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def paths(name):
    source = (ROOT / ".github/workflows" / name).read_text()
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
