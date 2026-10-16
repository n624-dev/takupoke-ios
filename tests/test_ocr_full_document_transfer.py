"""Whole-source design checks; no model or school data enters this module."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import random
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STUDY = ROOT / 'tools/ocr-full-document-transfer'
spec = importlib.util.spec_from_file_location('whole_source_generator', STUDY / 'generate.py')
generate = importlib.util.module_from_spec(spec); spec.loader.exec_module(generate)


def module(name):
    spec = importlib.util.spec_from_file_location('full_source_' + name, STUDY / (name + '.py'))
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result


reader, compare = module('read'), module('compare')


class FullDocumentSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        value = os.environ.get('TAKUPOKE_OCR_FULL_FONTS')
        if not value:
            raise unittest.SkipTest('Pinned-font generation executes in the owned full-source study environment')
        try:
            import fitz
            import PIL
            import reportlab
            import fontTools
        except ImportError:
            raise unittest.SkipTest('Dedicated source-generation dependencies are unavailable')
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.fonts = Path(value)
        cls.corpus = cls.root / 'cohort'
        generate.generate(cls.corpus, cls.fonts)
        cls.inputs = json.loads((cls.corpus / 'inputs.json').read_text())['documents']
        cls.oracle = json.loads((cls.corpus / 'oracle.json').read_text())['documents']

    def test_reader_manifest_never_contains_answers_or_region_coordinates(self):
        self.assertEqual(len(self.inputs), 6)
        self.assertEqual({r['kind'] for r in self.inputs}, {'timetable', 'exam', 'return'})
        for entry in self.inputs:
            self.assertEqual(set(entry), {'id', 'kind', 'pdf', 'pdfSHA256', 'pageCount'})
            self.assertEqual(entry['pageCount'], 1)
            self.assertEqual(hashlib.sha256((self.corpus / entry['pdf']).read_bytes()).hexdigest(), entry['pdfSHA256'])

    def test_all_six_sources_are_image_only_and_keep_the_complete_declared_scope(self):
        import fitz
        totals = 0
        for entry, assertion in zip(self.inputs, self.oracle):
            with fitz.open(self.corpus / entry['pdf']) as pdf:
                self.assertEqual(pdf.page_count, 1)
                self.assertEqual(pdf[0].get_text(), '')
                self.assertEqual(len(pdf[0].get_images()), 1)
            body = [r for r in assertion['records'] if r['category'] == 'body']
            keys = [(r['target']['className'], r['target']['day'], r['target']['period'], r['target']['role']) for r in body]
            self.assertEqual(len(keys), len(set(keys)))
            self.assertEqual({key[3] for key in keys}, {'subject', 'teacher', 'room'})
            if entry['kind'] == 'timetable':
                self.assertEqual(len(body), 120)
                self.assertEqual({key[1] for key in keys}, set('12345'))
                self.assertEqual({key[2] for key in keys}, set(range(1, 9)))
            else:
                self.assertEqual(len(body), 51)
                self.assertEqual(len({key[0] for key in keys}), 17)
            self.assertTrue(all(r['text'].startswith('架空') for r in body))
            totals += len(body)
        self.assertEqual(totals, 444)

    def test_same_independent_normal_design_reproduces_pdf_and_source_pixels(self):
        protocol = json.loads((STUDY / 'protocol.json').read_text())
        output = self.root / 'repeat'; output.mkdir()
        entry, assertion = generate.normal(output, 'f1-timetable', self.fonts / 'KaiseiOpti-Regular.ttf',
                                           random.Random(protocol['seed']))
        self.assertEqual(entry['pdfSHA256'], self.inputs[0]['pdfSHA256'])
        self.assertEqual(assertion, self.oracle[0])

    def test_prior_source_is_never_overwritten(self):
        before = (self.corpus / 'inputs.json').read_bytes()
        with self.assertRaises(FileExistsError):
            generate.generate(self.corpus, self.fonts)
        self.assertEqual((self.corpus / 'inputs.json').read_bytes(), before)


class FullSourceAcquisitionTests(unittest.TestCase):
    def test_unrequested_vision_is_not_an_empty_or_fabricated_native_result(self):
        self.assertFalse(reader.has_native_capture(dict(nativeVisionState='notRequestedDimensionBound'), 'source2x4096'))
        self.assertTrue(reader.has_native_capture(dict(nativeVisionState='captured', nativeCapture='a', nativeCaptureSHA256='b'), 'current2048'))
        for variant, doc in [('current2048', dict(nativeVisionState='captured')),
            ('source2x4096', dict(nativeVisionState='captured', nativeCapture='a', nativeCaptureSHA256='b')),
            ('source2x4096', dict(nativeVisionState='notRequestedDimensionBound', nativeCapture='a'))]:
            with self.assertRaises(ValueError):
                reader.has_native_capture(doc, variant)

    def test_native_baseline_keeps_its_own_source_geometry_and_refuses_another_pdf(self):
        expected = dict(width=200, height=100, sourcePDFSHA256='a'*64, records=[
            dict(text=value, category='body', box=[4, y*2, 8, 6], cell=[0, 0, 40, 50],
                 target=dict(className='1_1', day='1', period=1, role=role))
            for value, y, role in [('架空A', 3, 'subject'), ('架空B', 10, 'teacher'), ('架空C', 17, 'room')]])
        capture = dict(width=100, height=50, lines=[dict(nativeOrder=n, candidates=[dict(text=value,
            confidence=.99, observationRange=dict(x=2, y=y, width=4, height=3))])
            for n, (value, y) in enumerate([('架空A', 3), ('架空B', 10), ('架空C', 17)])])
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); data=json.dumps(capture, ensure_ascii=False).encode()
            (root/'original.json').write_bytes(data)
            document = dict(width=100, height=50, sourcePDFSHA256='a'*64, nativeVisionState='captured',
                nativeCapture='original.json', nativeCaptureSHA256=hashlib.sha256(data).hexdigest())
            fields, records = compare.vision_inputs(root, document, expected)
            result, extra, body_extra = compare.assignment(fields, [[0, 0, 20, 25]], records)
            self.assertEqual([r['exact'] for r in result], [True, True, True])
            self.assertEqual((extra, body_extra), (0, 0))
            self.assertEqual(records[0]['box'], [2, 3, 4, 3])
            with self.assertRaisesRegex(ValueError, 'another source'):
                compare.vision_inputs(root, document, dict(expected, sourcePDFSHA256='b'*64))

    def test_post_test_capture_report_keeps_original_rank_unicode_probability_and_box(self):
        capture = dict(lines=[dict(nativeOrder=0, candidates=[
            dict(text='架空髙 I', confidence=.500000001,
                 observationRange=dict(x=1.25, y=2.5, width=8.75, height=9.125)),
            dict(text='架空高 l', confidence=.99),
            dict(text='架空髙 I', confidence=.49)])])
        before = json.dumps(capture, ensure_ascii=False, sort_keys=True)
        records = reader.native_records('fictional', 'current2048', capture)
        self.assertEqual(records, [dict(id='fictional', variant='current2048', nativeOrder=0,
            text='架空髙 I', confidence=.500000001, box=[1.25, 2.5, 8.75, 9.125],
            nativeCandidates=[dict(text='架空髙 I', confidence=.500000001),
                dict(text='架空高 l', confidence=.99), dict(text='架空髙 I', confidence=.49)])])
        self.assertEqual(json.dumps(capture, ensure_ascii=False, sort_keys=True), before)

    def test_post_test_capture_report_refuses_duplicate_or_missing_original_orders(self):
        for orders in [[0, 0], [1], [0, 2]]:
            with self.assertRaisesRegex(ValueError, 'inventory changed'):
                reader.native_records('fictional', 'current2048', dict(lines=[dict(nativeOrder=n) for n in orders]))

    def arrays(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest('Numerical crop checks run in the dedicated owned study environment')
        return np

    def test_frames_preserve_all_original_ink_without_grabbing_the_next_line(self):
        np = self.arrays()
        gray = np.full((16, 32), 255, dtype=np.uint8)
        gray[4:7, 3:10] = 0; gray[8:11, 3:10] = 0; gray[0, 31] = 254
        frames, coverage = reader.regions(gray, np.zeros_like(gray), [[1, 1, 28, 14]])
        self.assertEqual(len(frames), 3)
        self.assertEqual(coverage, dict(originalNonRuleInkPixels=43, assignedInkPixels=43, outsidePhysicalCellsInkPixels=1))
        self.assertEqual(sum(f['originalInkPixels'] for f in frames), 43)
        self.assertEqual(sum(f['ownerCell'] is None for f in frames), 1)
        self.assertEqual(gray[0, 31], 254)

    def test_competing_cell_owners_are_not_resolved_by_prediction_or_nearest_cell(self):
        np = self.arrays()
        gray = np.full((16, 32), 255, dtype=np.uint8); gray[5, 5] = 0
        with self.assertRaisesRegex(ValueError, 'competing physical cell owners'):
            reader.regions(gray, np.zeros_like(gray), [[1, 1, 12, 12], [3, 3, 12, 12]])

    def test_rule_mask_cannot_hide_white_gaps(self):
        np = self.arrays()
        gray = np.full((16, 32), 255, dtype=np.uint8); mask = np.zeros_like(gray); mask[2, 2] = 1
        with self.assertRaisesRegex(ValueError, 'covered white pixels'):
            reader.regions(gray, mask, [])

    def test_an_unread_region_is_not_ignored_when_another_fragment_matches(self):
        fields = [dict(text=value, box=[2, y, 4, 3], cell=[0, 0, 20, 25],
                       target=dict(className='1_1', day='1', period=1, role=role))
                  for value, y, role in [('架空A', 3, 'subject'), ('架空B', 10, 'teacher'), ('架空C', 17, 'room')]]
        records = [dict(box=[2, 3, 4, 3], text='架空A', eligible=True, order=0),
                   dict(box=[7, 3, 1, 3], text=None, eligible=False, order=1)]
        outcome, _, _ = compare.assignment(fields, [[0, 0, 20, 25]], records)
        self.assertFalse(outcome[0]['exact'])
        self.assertFalse(outcome[0]['eligible'])
        self.assertEqual(outcome[0]['contributingRecords'], 2)

    def test_a_physical_region_covering_two_semantic_cells_has_no_unique_owner(self):
        fields = []
        for cls, x in [('1_1', 2), ('1_2', 12)]:
            for role, y in [('subject', 3), ('teacher', 10), ('room', 17)]:
                fields.append(dict(text='架空', box=[x, y, 4, 3], cell=[x-2, 0, 10, 25],
                                   target=dict(className=cls, day='1', period=1, role=role)))
        outcome, extra, body_extra = compare.assignment(fields, [[0, 0, 22, 25]], [dict(box=[2, 3, 4, 3], text='架空', eligible=True, order=0)])
        self.assertEqual(extra, 1)
        self.assertEqual(body_extra, 1)
        self.assertTrue(all(not r['exact'] for r in outcome))

    def test_correct_fields_do_not_hide_an_unassigned_region_crossing_role_bands(self):
        fields = [dict(text=value, box=[2, y, 4, 3], cell=[0, 0, 20, 25],
                       target=dict(className='1_1', day='1', period=1, role=role))
                  for value, y, role in [('架空A', 3, 'subject'), ('架空B', 10, 'teacher'), ('架空C', 17, 'room')]]
        records = [dict(box=f['box'], text=f['text'], eligible=True, order=index) for index, f in enumerate(fields)]
        records.append(dict(box=[8, 5, 2, 14], text='架空余剰', eligible=True, order=3))
        outcome, extra, body_extra = compare.assignment(fields, [[0, 0, 20, 25]], records)
        self.assertTrue(all(r['exact'] for r in outcome))
        self.assertEqual(extra, 1)
        self.assertEqual(body_extra, 1)


if __name__ == '__main__':
    unittest.main()
