#!/usr/bin/env python3
"""Source/oracle checks. These do not replace either native PDF reader."""
import hashlib
import json
from pathlib import Path
import unittest

import generate

ROOT = Path(__file__).resolve().parents[2]


class IndependentDesignTests(unittest.TestCase):
    def setUp(self):
        self.classes, _ = generate.canonical_classes(ROOT)
        self.cells = generate.design(self.classes)
        self.oracle = generate.expected(self.classes, self.cells)

    def test_all_680_slots_are_unique_and_merged_values_repeat_without_new_lessons(self):
        self.assertEqual(len(self.classes), 17)
        self.assertEqual(len(self.oracle["slots"]), 680)
        by_key = {(slot["className"], slot["weekday"], slot["period"]): slot for slot in self.oracle["slots"]}
        self.assertEqual(len(by_key), 680)
        for cell in self.cells:
            for period in range(cell["firstPeriod"], cell["firstPeriod"]+cell["periodCount"]):
                self.assertEqual(by_key[cell["className"], cell["weekday"], period]["lessons"], cell["lessons"])

    def test_frozen_independent_oracle_matches_design_and_contains_only_fake_values(self):
        frozen = Path(__file__).with_name("expected.json").read_bytes()
        self.assertEqual(json.loads(frozen), self.oracle)
        self.assertEqual(hashlib.sha256(frozen).hexdigest(), "efdcb749420be6b000bf172f41102fd6c98b4e6b600dd22d07b41168788ce191")
        for slot in self.oracle["slots"]:
            for lesson in slot["lessons"]:
                self.assertTrue(lesson["subject"].startswith("架空科目"))
                self.assertTrue(not lesson["teacher"] or lesson["teacher"].startswith("架空教員"))
                self.assertTrue(not lesson["room"] or lesson["room"].startswith("架空室"))

    def test_design_includes_distinct_merges_parallel_and_blank_semantics(self):
        self.assertEqual(len(self.cells), 509)
        self.assertEqual(sum(cell["periodCount"] > 1 for cell in self.cells), 111)
        self.assertEqual(sum(len(cell["lessons"]) == 2 for cell in self.cells), 33)
        self.assertEqual(sum(not cell["lessons"] for cell in self.cells), 76)
        self.assertTrue(any(lesson["teacher"] == "" and lesson["room"] for cell in self.cells for lesson in cell["lessons"]))
        self.assertTrue(any(lesson["room"] == "" and lesson["teacher"] for cell in self.cells for lesson in cell["lessons"]))
        self.assertEqual(generate.design(self.classes), self.cells)

    def test_public_class_contract_snapshot_matches_real_ios_source_definition(self):
        self.assertEqual(generate.canonical_classes(ROOT), generate.canonical_classes(ROOT,
            Path(__file__).with_name("canonical-class-source.txt")))


if __name__ == "__main__":
    unittest.main()
