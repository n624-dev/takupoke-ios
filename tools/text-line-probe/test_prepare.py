import copy
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('line_prepare', HERE/'prepare.py')
prepare = importlib.util.module_from_spec(spec); spec.loader.exec_module(prepare)

class LineROISelectionTests(unittest.TestCase):
    def records(self):
        return [json.loads(line) for line in (prepare.PRIOR/'native-raw.jsonl').read_bytes().splitlines()]

    def test_all_captured_low_confidence_lines_have_bounded_integer_rois(self):
        _, rois = prepare.derive(self.records())
        self.assertEqual([(r['id'],r['x'],r['y'],r['width'],r['height']) for r in rois],
            [('left-0000',0,3,120,27),('left-0001',0,105,45,31),
             ('left-0003',95,63,17,23),('left-0007',207,3,59,27),
             ('left-0008',205,63,19,23),('left-0010',427,63,19,23),
             ('right-0001',651,63,17,21),('right-0002',763,63,17,19),
             ('right-0003',875,65,17,19)])

    def test_text_changes_cannot_change_selection_or_roi_geometry(self):
        records = self.records(); _, original = prepare.derive(records)
        for region in records:
            for line in region.get('lines', []):
                line['rawText'] = 'unrelated fictional text'
                line['characters'] = []
        self.assertEqual(prepare.derive(records)[1], original)

    def test_guard_boundary_removes_only_that_line(self):
        records = self.records(); records[1]['lines'][0]['confidence'] = .85
        _, rois = prepare.derive(records)
        self.assertEqual(len(rois), 8)
        self.assertNotIn('left-0000', [r['id'] for r in rois])

    def test_bad_geometry_or_confidence_cannot_enter_manifest(self):
        for value in ['confidence', 'geometry', 'outside', 'offset']:
            with self.subTest(value=value):
                records = self.records(); line = records[1]['lines'][0]
                if value == 'confidence': line['confidence'] = float('nan')
                elif value == 'geometry': line['observationBox']['originalPixelTopLeft']['width'] = -1
                elif value == 'outside':
                    line['observationBox']['originalPixelTopLeft']['x'] = 2000
                    line['observationBox']['cropPixelTopLeft']['x'] = 2000
                else: line['observationBox']['originalPixelTopLeft']['x'] += 1
                with self.assertRaises(AssertionError): prepare.derive(records)

    def test_request_limit_rejects_unbounded_expansion(self):
        records = self.records(); template = records[1]['lines'][0]
        for i in range(17):
            line = copy.deepcopy(template); line['nativeOrder'] = 100+i
            records[1]['lines'].append(line)
        with self.assertRaises(AssertionError): prepare.derive(records)

    def test_captured_lossless_png_decodes_to_pinned_pixels(self):
        png = (prepare.PRIOR/'native-render/original.png').read_bytes()
        width,height,pixels = prepare.rgba_png(png)
        self.assertEqual((width,height),(984,197))
        self.assertEqual(prepare.sha(pixels), 'ea88aabe36bfd799029b644f42467a47c9cf9e32f0691807b2b156ea1daf58b9')
        corrupted = bytearray(png); corrupted[30] ^= 1
        with self.assertRaises(AssertionError): prepare.rgba_png(corrupted)

if __name__ == '__main__': unittest.main()
