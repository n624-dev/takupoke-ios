"""Synthetic readback controls; no recognition request or SDK substitute."""
import copy
import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import read_native_document_hierarchy_research as reader


class NativeReadbackTests(unittest.TestCase):
    def report(self):
        cases = []
        for i, fixture in enumerate(reader.FIXTURES):
            for profile in reader.PROFILES:
                strings = reader.JAPANESE_EXPECTED if i == 2 else ("Independent fictional control",)
                cases.append({"case": fixture, "languageProfile": profile,
                    "pixelSHA256": reader.OLD_PIXELS[i] if i < 2 else "c" * 64,
                    "actualRawTop1Lines": {"omittedLines": 0, "firstLines": [
                        {"lineOrder": n, "top1UTF8": list(value.encode()), "omittedTop1Bytes": 0}
                        for n, value in enumerate(strings)]}, "correspondence": {"flatLines": len(strings)}})
        return {"sourceSHA": "a" * 40, "runID": "123", "runAttempt": "1", "maximumNativeCalls": 6,
                "nativeCallsAttempted": 6, "retries": 0, "cases": cases}

    def read(self, report):
        return reader.readback(report, "a" * 40, "123")

    def test_complete_fixed_literals_are_counted_without_quality_or_model_credit(self):
        result = self.read(self.report())
        self.assertTrue(all(c["allFixedLiteralsExact"] for c in result["japanese"]))
        self.assertEqual(result["wholeDocumentQuality"], "UNASSESSED")
        self.assertFalse(result["productionLanguageHintAdopted"])

    def test_one_wrong_raw_literal_is_a_measured_negative(self):
        report = self.report(); report["cases"][-1]["actualRawTop1Lines"]["firstLines"][0]["top1UTF8"] = list("架空の誤読".encode())
        result = self.read(report)["japanese"][-1]
        self.assertFalse(result["allFixedLiteralsExact"]); self.assertEqual(result["exactLiteralCount"], 9)

    def test_identity_duplicate_or_retry_cannot_gain_comparison_credit(self):
        for change in (lambda r: r.update(sourceSHA="b" * 40), lambda r: r.update(retries=1),
                       lambda r: r["cases"].__setitem__(0, copy.deepcopy(r["cases"][1]))):
            report = self.report(); change(report)
            with self.assertRaises(ValueError): self.read(report)

    def test_missing_line_truncated_or_invalid_bytes_cannot_claim_exact_literals(self):
        for change in (lambda s: s.update(omittedTop1Bytes=1), lambda s: s.update(top1UTF8=[256]),
                       lambda s: s.update(top1UTF8=[255])):
            report = self.report(); change(report["cases"][-1]["actualRawTop1Lines"]["firstLines"][0])
            with self.assertRaises(ValueError): self.read(report)
        report = self.report(); report["cases"][-1]["actualRawTop1Lines"]["omittedLines"] = 1
        with self.assertRaises(ValueError): self.read(report)

    def test_changed_old_or_mismatched_japanese_pixels_refuse(self):
        for index in (0, -1):
            report = self.report(); report["cases"][index]["pixelSHA256"] = "d" * 64
            with self.assertRaises(ValueError): self.read(report)

    def test_operational_refusal_keeps_literal_assessment_unassessed(self):
        report = self.report(); report["nativeCallsAttempted"] = 5
        report["cases"][-1]["operationalFailure"] = "Synthetic unsupported language"
        report["cases"][-1].pop("actualRawTop1Lines")
        result = self.read(report)["japanese"][-1]
        self.assertEqual(result["rawLiteralAssessment"], "UNASSESSED")
        self.assertNotIn("allFixedLiteralsExact", result)


if __name__ == "__main__": unittest.main()
