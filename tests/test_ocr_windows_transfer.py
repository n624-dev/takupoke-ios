"""Research data integrity and conservative native-output comparison contracts."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
STUDY = ROOT / 'tools/ocr-windows-transfer'


def module(name):
    spec = importlib.util.spec_from_file_location('ocr_transfer_' + name, STUDY / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


prepare, compare = module('prepare'), module('compare')


class OCRWindowsTransferTests(unittest.TestCase):
    def test_native_top_one_cannot_be_replaced_by_correct_high_score_alternate(self):
        line = dict(box=[10, 10, 20, 10], candidates=[dict(text='Fiction O', confidence=.3),
                                                     dict(text='Fiction 0', confidence=1)])
        self.assertEqual(compare.vision_value([line], [0, 0, 100, 100]), ('Fiction O', .3, 'single-contained'))

    def test_missing_split_and_outside_remain_unassigned_without_joining_or_clamping(self):
        a = dict(box=[5, 5, 10, 5], candidates=[dict(text='架空', confidence=1)])
        b = dict(box=[20, 5, 10, 5], candidates=[dict(text='科目', confidence=1)])
        for lines, box, status in [([], [0, 0, 100, 100], 'missing'),
                                   ([a, b], [0, 0, 100, 100], 'split-or-conflict'),
                                   ([a], [10, 0, 100, 100], 'outside-physical-region')]:
            self.assertEqual(compare.vision_value(lines, box), (None, None, status))

    def test_raw_unicode_spaces_and_confusable_codes_stay_different(self):
        for a, b in [('FxO0', 'Fx00'), ('架 空', '架空'), ('髙', '高'), ('Ａ', 'A'), ('か\u3099', 'が')]:
            self.assertGreater(compare.distance(a, b), 0)
        self.assertEqual(compare.distance('架空甲', '架空甲'), 0)
        self.assertEqual(compare.distance('AB12', ''), 4)

    def test_pinned_artifact_mismatch_cannot_create_output(self):
        pin = dict(file='fictional-model.bin', bytes=3, sha256='0'*64, url='https://example.invalid/model')
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(prepare.urllib.request, 'urlopen') as opened:
                opened.return_value.__enter__.return_value.read.return_value = b'bad'
                with self.assertRaisesRegex(ValueError, 'Pinned download mismatch'):
                    prepare.fetch(pin, Path(temporary))
            self.assertFalse((Path(temporary) / pin['file']).exists())

    def test_existing_wrong_artifact_is_rejected_without_network_or_repair(self):
        pin = dict(file='fictional-model.bin', bytes=3, sha256='0'*64, url='https://example.invalid/model')
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / pin['file']
            path.write_bytes(b'bad')
            with patch.object(prepare.urllib.request, 'urlopen') as opened:
                with self.assertRaisesRegex(ValueError, 'Pinned local artifact mismatch'):
                    prepare.fetch(pin, Path(temporary))
                opened.assert_not_called()
            self.assertEqual(path.read_bytes(), b'bad')

    def test_independent_design_cannot_substitute_an_unsupported_glyph(self):
        protocol = json.loads((STUDY / 'protocol.json').read_text())
        with self.assertRaisesRegex(ValueError, 'No native variant glyphs'):
            prepare.design(protocol, 0, set(range(128)))

    def test_transform_keeps_b_g_r_and_normalized_zero_padding(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest('Numerical research dependencies run in dedicated owned environment')
        infer = module('infer')
        # A uniform red original remains red after any legal interpolation;
        # post-normalization padding is zero, not white +1 or black -1.
        image = np.zeros((48, 48, 3), dtype=np.uint8)
        image[:, :, 0] = 255
        tensor, valid, width = infer.transform(image)
        self.assertEqual((valid, width), (48, 320))
        np.testing.assert_array_equal(tensor[0, 0, :, :48], -1)
        np.testing.assert_array_equal(tensor[0, 1, :, :48], -1)
        np.testing.assert_array_equal(tensor[0, 2, :, :48], 1)
        np.testing.assert_array_equal(tensor[:, :, :, 48:], 0)

    def test_c_t_c_blank_separates_repeated_tokens_and_all_scores_are_validated(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest('Numerical research dependencies run in dedicated owned environment')
        infer = module('infer')
        p = np.array([[[.1, .9, 0], [.2, .8, 0], [.9, .1, 0], [.1, .8, .1], [.1, .1, .8]]], dtype=np.float32)
        pieces = infer.decode(p, ['', 'A', ' '])
        self.assertEqual(''.join(v['text'] for v in pieces), 'AA ')
        self.assertEqual([(v['start'], v['end']) for v in pieces], [(0, 2), (3, 4), (4, 5)])
        self.assertAlmostEqual(pieces[0]['confidence'], .9)
        p[0, 0, 2] = float('nan')  # a losing token must still fail
        with self.assertRaisesRegex(ValueError, 'Invalid native CTC'):
            infer.decode(p, ['', 'A', ' '])

    def test_ink_frame_uses_all_observed_ink_even_when_it_is_distant_from_main_text(self):
        try:
            from PIL import Image
            import numpy  # noqa: F401
        except ImportError:
            self.skipTest('Image research dependencies run in dedicated owned environment')
        frames = module('frames')
        image = Image.new('RGB', (100, 50), 'white')
        image.putpixel((20, 20), (0, 0, 0))
        image.putpixel((90, 40), (0, 0, 0))
        self.assertEqual(frames.ink_box(image), (18, 18, 93, 43))
        self.assertIsNone(frames.ink_box(Image.new('RGB', (100, 50), 'white')))


if __name__ == '__main__':
    unittest.main()
