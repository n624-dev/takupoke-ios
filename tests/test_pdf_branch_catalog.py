"""Keep every Strict rejection code and its public lookup registered."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("pdf_branch_catalog", ROOT / "tools/pdf_branch_catalog.py")
CATALOG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CATALOG)


class PDFBranchCatalogTests(unittest.TestCase):
    def test_document_matches_every_fixed_source_branch(self):
        self.assertEqual((ROOT / "docs/strict-pdf-branch-catalog.md").read_text(), CATALOG.document())

    def test_missing_reused_and_undeclared_branches_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="takupoke-branch-catalog-") as owned:
            root = Path(owned)
            (root / "Takupoke").mkdir()
            names = set(CATALOG.SOURCES) | {"PDFParseError.swift"}
            for name in names:
                (root / "Takupoke" / name).write_text((ROOT / "Takupoke" / name).read_text())
            source = root / "Takupoke/PDFAnalysis.swift"
            original = source.read_text()
            for replacement in ["", ", branch:.b002", ", branch:.b999"]:
                source.write_text(original.replace(", branch:.b001", replacement, 1))
                with self.assertRaises(ValueError):
                    CATALOG.document(root)
            source.write_text(original)
            self.assertEqual(CATALOG.document(root), CATALOG.document())


if __name__ == "__main__":
    unittest.main()
