#!/usr/bin/env python3
"""Bounded native readback; the fixed Japanese literal oracle is used here only."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

FIXTURES = ("independent-rectangular", "independent-merged", "independent-japanese-rectangular")
PROFILES = ("default", "ja-en-auto")
OLD_PIXELS = ("c06f5e31c6be79ecdaea90ca83d6432e9413596925f515599ca645f0b71b6400",
              "dfa5a94614f87a1274bf4115c500a199ad89b440584d10f8bd80d36df6c25edb")
JAPANESE_EXPECTED = ("独立架空の日本語表", "架空理論甲", "架空担当乙", "架空室Q9",
                     "架空理論丙", "架空担当丁", "架空室R8", "架空理論戊", "架空担当己", "架空室S7")


def readback(report, source, run_id):
    if (not re.fullmatch(r"[0-9a-f]{40}", source) or not re.fullmatch(r"[1-9][0-9]*", run_id)
            or report.get("sourceSHA") != source or report.get("runID") != run_id
            or report.get("runAttempt") != "1" or report.get("maximumNativeCalls") != 6
            or type(report.get("nativeCallsAttempted")) is not int
            or not 0 <= report["nativeCallsAttempted"] <= 6 or report.get("retries") != 0):
        raise ValueError("native identity or call bound mismatch")
    cases = report.get("cases")
    if not isinstance(cases, list) or len(cases) != 6:
        raise ValueError("all six outcome records required")
    indexed = {}
    for case in cases:
        key = (case.get("case"), case.get("languageProfile"))
        if key[0] not in FIXTURES or key[1] not in PROFILES or key in indexed:
            raise ValueError("foreign or duplicate fixture/profile")
        indexed[key] = case
    for i, fixture in enumerate(FIXTURES):
        pair = [indexed[fixture, profile] for profile in PROFILES]
        hashes = [case.get("pixelSHA256") for case in pair]
        if any(not isinstance(h, str) or not re.fullmatch(r"[0-9a-f]{64}", h) for h in hashes) or hashes[0] != hashes[1]:
            raise ValueError("matched input pixels missing or different")
        if i < 2 and hashes[0] != OLD_PIXELS[i]:
            raise ValueError("old independent fixture pixels changed")
    japanese = []
    for profile in PROFILES:
        case = indexed[FIXTURES[2], profile]
        item = {"profile": profile, "operationalFailure": case.get("operationalFailure"),
                "rawLiteralAssessment": "UNASSESSED", "expectedLiteralCount": len(JAPANESE_EXPECTED),
                "fullAcquisitionDisposition": case.get("fullAcquisitionDisposition"),
                "fullMappingAssessmentPassed": case.get("fullMappingAssessmentPassed"),
                "strictParserAcquisitionDisposition": case.get("strictParserAcquisitionDisposition"),
                "lowConfidenceNativeCount": case.get("lowConfidenceNativeCount"),
                "characterMappingCounts": case.get("top1CharacterMapping", {}).get("counts"),
                "wholeLineCapture": case.get("wholeLineCapture"),
                "legacyEveryCharacterRangeGatePassed": case.get("legacyEveryCharacterRangeGatePassed")}
        if not item["operationalFailure"]:
            raw = case.get("actualRawTop1Lines", {})
            samples = raw.get("firstLines")
            if (not isinstance(samples, list) or len(samples) > 16 or raw.get("omittedLines") != 0
                    or len(samples) != case.get("correspondence", {}).get("flatLines")):
                raise ValueError("complete Japanese raw line inventory required")
            strings = []
            for order, sample in enumerate(samples):
                values = sample.get("top1UTF8")
                if (sample.get("lineOrder") != order or sample.get("omittedTop1Bytes") != 0
                        or not isinstance(values, list) or len(values) > 128
                        or any(type(value) is not int or not 0 <= value <= 255 for value in values)):
                    raise ValueError("Japanese raw line bytes incomplete or invalid")
                strings.append(bytes(values).decode("utf-8", errors="strict"))
            expected, actual = Counter(JAPANESE_EXPECTED), Counter(strings)
            exact = sum((expected & actual).values())
            item.update(rawLiteralAssessment="COMPLETE_FIXED_LITERAL_COMPARISON",
                        returnedRawLiteralCount=len(strings), exactLiteralCount=exact,
                        missingLiterals=list((expected - actual).elements()),
                        unexpectedRawLiterals=list((actual - expected).elements()),
                        allFixedLiteralsExact=actual == expected)
        japanese.append(item)
    return {"sourceSHA": source, "runID": run_id, "nativeCallsAttempted": report["nativeCallsAttempted"],
            "japanese": japanese, "nativeHierarchyCorrespondencePassed": report.get("nativeHierarchyCorrespondencePassed"),
            "nativeFullAcquisitionControlsPassed": report.get("nativeFullAcquisitionControlsPassed"),
            "wholeDocumentQuality": "UNASSESSED", "modelQualification": "UNASSESSED",
            "productionLanguageHintAdopted": False}


def main():
    parser = argparse.ArgumentParser(); parser.add_argument("report", type=Path)
    parser.add_argument("--source", required=True); parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    with args.report.open("rb") as stream:
        raw = stream.read(65_537)
    if len(raw) > 65_536:
        raise ValueError("native report exceeds declared 65KiB bound")
    print(json.dumps(readback(json.loads(raw), args.source, args.run_id), ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
