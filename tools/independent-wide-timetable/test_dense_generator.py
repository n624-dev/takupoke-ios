#!/usr/bin/env python3
"""Compact fixture design checks, not application Reader or OCR proof."""
import json
from pathlib import Path
import unittest

import generate
import generate_dense as dense

ROOT = Path(__file__).resolve().parents[2]


class DenseDesignTests(unittest.TestCase):
    def test_same_invented_literal_oracle_without_changing_frozen_main(self):
        classes, _ = generate.canonical_classes(ROOT)
        data = (json.dumps(generate.expected(classes, generate.design(classes)), ensure_ascii=False, indent=2)+"\n").encode()
        frozen = Path(__file__).with_name("expected.json").read_bytes()
        self.assertEqual(data, frozen)
        self.assertEqual(generate.digest(frozen), "efdcb749420be6b000bf172f41102fd6c98b4e6b600dd22d07b41168788ce191")
        self.assertEqual((generate.W, generate.H, generate.COL_W), (3052, 990, 72))

    def test_new_closed_grid_fits_compact_page_with_whole_17_class_coverage(self):
        classes, _ = generate.canonical_classes(ROOT)
        self.assertTrue(1.4 <= dense.W/dense.H <= 1.6)
        self.assertLess(dense.BODY_X+40*dense.COL_W, dense.W)
        self.assertLess(dense.BODY_Y+17*dense.ROW_H+35, dense.H)
        self.assertEqual(len(classes), 17)
        self.assertNotEqual(dense.COL_W, generate.COL_W)
        self.assertNotEqual(dense.BODY_Y, generate.BODY_Y)


if __name__ == "__main__":
    unittest.main()
