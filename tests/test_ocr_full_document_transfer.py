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
tails = module('code_tail')
class_cells = module('class_cell')


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
    def test_ascii_class_selection_keeps_both_raw_results_and_original_frame_provenance(self):
        primary = dict(ownerCell=3, state='recognized', actualCall=True, text='7_ZO', inkBox=[10,20,30,12],
                       frameBox=[8,18,34,16], sourcePixelsSHA256='original-rgb-hash', originalInkPixels=50,
                       ownPieceFloor085=True, paddingSupported=True)
        expert = dict(sourcePixelsSHA256='original-rgb-hash', text='7_ZQ', pieces=[dict(text=c, confidence=.99) for c in '7_ZQ'],
                      rejectProbability=.01, paddingSupported=True)
        candidate = dict(primary, text=expert['text'], selected=True, expert=expert)
        before = json.dumps([primary,candidate], ensure_ascii=False, sort_keys=True)
        chosen = class_cells.select_ascii_candidates([primary], [candidate], tails.selects)
        self.assertEqual(chosen, [candidate])
        self.assertEqual(json.dumps([primary,candidate], ensure_ascii=False, sort_keys=True), before)
        for key, value in [('frameBox',[8,18,35,16]), ('sourcePixelsSHA256','different'), ('ownerCell',4)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                class_cells.select_ascii_candidates([primary], [dict(candidate, **{key:value})], tails.selects)
        with self.assertRaisesRegex(ValueError, 'original result changed'):
            class_cells.select_ascii_candidates([primary], [dict(candidate, expert=dict(expert, sourcePixelsSHA256='different-actual-RGB'))], tails.selects)
        refused = dict(ownerCell=3, state='notExecuted', actualCall=False, selected=False)
        with self.assertRaisesRegex(ValueError, 'declared eligibility'):
            class_cells.select_ascii_candidates([primary], [refused], tails.selects)

    def test_ascii_class_refusal_cannot_lower_score_or_inject_expected_class_names(self):
        primary = dict(ownerCell=2, state='recognized', actualCall=True, text='Al_1', inkBox=[1,1,8,8],
                       frameBox=[0,0,10,10], sourcePixelsSHA256='original', originalInkPixels=12)
        expert = dict(sourcePixelsSHA256='original', text='AI_1', pieces=[dict(text=c, confidence=.84) for c in 'AI_1'],
                      rejectProbability=.01, paddingSupported=True)
        candidate = dict(primary, text='AI_1', selected=False, ownPieceFloor085=False, paddingSupported=True, expert=expert)
        self.assertEqual(class_cells.select_ascii_candidates([primary], [candidate], tails.selects), [primary])
        with self.assertRaisesRegex(ValueError, 'fixed conditions'):
            class_cells.select_ascii_candidates([primary], [dict(candidate, selected=True)], tails.selects)
        self.assertFalse(class_cells.ascii_eligible(dict(primary, text='架空1')))
        self.assertFalse(class_cells.ascii_eligible(dict(primary, text='Class')))
        self.assertFalse(class_cells.ascii_eligible(dict(primary, state='unsupported-width')))
        self.assertTrue(class_cells.ascii_eligible(dict(primary, text='7_ZQ')))

    def test_class_column_uses_actual_top_left_label_and_contiguous_physical_cells(self):
        cells = [[0, 0, 30, 20], [30, 0, 70, 20], [0, 20, 30, 20], [30, 20, 70, 20]]
        label = dict(index=0, ownerCell=0, text='クラス', ownPieceFloor085=True, paddingSupported=True)
        owners, proof = class_cells.column(cells, [label])
        self.assertEqual(owners, [2]); self.assertEqual(proof['headerCell'], 0)
        # The same word printed in a body cell is insufficient.
        self.assertEqual(class_cells.column(cells, [dict(label, ownerCell=2)])[0], [])
        self.assertEqual(class_cells.column(cells, [dict(label, ownerCell=1)])[0], [])
        self.assertEqual(class_cells.column(cells, [dict(label, ownPieceFloor085=False)])[0], [])
        self.assertEqual(class_cells.column(cells, [label, label])[0], [])
        self.assertEqual(class_cells.column(cells, [label, dict(label, text='別の印字')])[0], [])

    def test_class_column_does_not_skip_missing_or_competing_cells(self):
        label = dict(index=0, ownerCell=0, text='クラス', ownPieceFloor085=True, paddingSupported=True)
        for cells in [[[0, 0, 30, 20], [0, 30, 30, 20]],
                      [[0, 0, 30, 20], [0, 20, 30, 20], [0, 40, 40, 20]]]:
            with self.subTest(cells=cells):
                self.assertEqual(class_cells.column(cells, [label])[0], [])

    def test_whole_class_frame_preserves_detached_underscore_and_all_original_ink(self):
        np = self.arrays()
        gray = np.full((30, 40), 255, dtype=np.uint8); mask = np.zeros_like(gray)
        gray[8:18, 10:14] = 0; gray[8:18, 23:27] = 0; gray[19, 16:22] = 0
        original = gray.copy()
        cells = [[0, 0, 40, 30]]
        records, _ = reader.regions(gray, mask, cells)
        records = [dict(r, index=i) for i, r in enumerate(records)]
        self.assertGreater(len(records), 1)
        framed, proof = class_cells.frame(gray, mask, cells, records, 0)
        self.assertEqual(proof['state'], 'framedAllOriginalClassCellInk')
        self.assertEqual(framed['originalInkPixels'], 86)
        x, y, w, h = framed['frameBox']
        self.assertEqual(int((gray[y:y+h, x:x+w] != 255).sum()), 86)
        self.assertEqual(framed['inkBox'], [10, 8, 17, 12])
        np.testing.assert_array_equal(gray, original)
        self.assertEqual(framed['originalRecordIndices'], list(range(len(records))))

    def test_class_frame_rejects_two_actual_text_lines_empty_cells_and_inventory_loss(self):
        np = self.arrays()
        gray = np.full((40, 40), 255, dtype=np.uint8); mask = np.zeros_like(gray)
        cells = [[0, 0, 40, 40]]
        gray[4:12, 10:20] = 0; gray[22:30, 10:20] = 0
        records, _ = reader.regions(gray, mask, cells)
        records = [dict(r, index=i) for i, r in enumerate(records)]
        framed, proof = class_cells.frame(gray, mask, cells, records, 0)
        self.assertIsNone(framed); self.assertEqual(proof['state'], 'multipleMeasuredTextBands')
        with self.assertRaisesRegex(ValueError, 'original ink inventory changed'):
            class_cells.frame(gray, mask, cells, records[:-1], 0)
        gray[:] = 255
        self.assertEqual(class_cells.frame(gray, mask, cells, [], 0)[1]['state'], 'emptyMeasuredClassCell')

    def test_class_assertion_uses_actual_cell_ownership_and_keeps_extra_ink_visible(self):
        cells = [[0, 0, 40, 40], [40, 0, 40, 40]]
        fields = [dict(text='7_ZQ', box=[10, 8, 20, 12])]
        raw = [dict(ownerCell=0, inkBox=[10, 8, 20, 10], text='7 ZQ', ownPieceFloor085=True, paddingSupported=True),
               dict(ownerCell=0, inkBox=[15, 19, 5, 1], text='一', ownPieceFloor085=True, paddingSupported=True)]
        candidate = dict(ownerCell=0, inkBox=[10, 8, 20, 12], text='7_ZQ', actualCall=True,
                         state='recognized', ownPieceFloor085=False, paddingSupported=True, originalInkPixels=30)
        before = json.dumps([fields, cells, raw, candidate], ensure_ascii=False, sort_keys=True)
        original, _ = compare.class_assignment(fields, cells, raw, [])
        trial, extra = compare.class_assignment(fields, cells, raw, [candidate])
        self.assertFalse(original[0]['exact']); self.assertTrue(trial[0]['exact'])
        with self.assertRaisesRegex(ValueError, 'ownership differs'):
            compare.class_assignment(fields, cells, raw, [dict(candidate, ownerCell=1)])
        self.assertFalse(trial[0]['eligible']); self.assertEqual(extra, 0)
        self.assertEqual(compare.class_assignment(fields, cells, raw, [dict(candidate, ownerCell=1, inkBox=[50, 8, 20, 12])])[1], 1)
        other_ink = dict(raw[0], ownerCell=1, inkBox=[50, 8, 20, 10], originalInkPixels=25)
        refused = dict(ownerCell=1, state='multipleMeasuredTextBands', actualCall=False)
        self.assertEqual(compare.class_assignment(fields, cells, [*raw, other_ink], [refused])[1], 1)
        self.assertEqual(json.dumps([fields, cells, raw, candidate], ensure_ascii=False, sort_keys=True), before)
        with self.assertRaisesRegex(ValueError, 'no unique actual physical cell'):
            compare.class_assignment([dict(fields[0], box=[35, 8, 10, 12])], cells, raw, [])

    def test_composed_trial_preserves_original_unicode_records_and_low_prefix_score(self):
        primary = dict(text='髙003', ownPieceFloor085=True, paddingSupported=True,
                       pieces=[dict(text=c, confidence=.99) for c in '髙003'])
        proof = dict(prefixPieceCount=1, originalSuffix='003')
        expert = dict(text='O03', pieces=[dict(text=c, confidence=.99) for c in 'O03'],
                      paddingSupported=True, rejectProbability=.01)
        before = json.dumps([primary, proof, expert], ensure_ascii=False, sort_keys=True)
        trial = tails.compose(primary, proof, expert)
        self.assertEqual(trial['selectedText'].encode(), '髙O03'.encode())
        self.assertTrue(trial['selectedEligible'])
        self.assertTrue(trial['asciiTail']['selected'])
        self.assertEqual(json.dumps([primary, proof, expert], ensure_ascii=False, sort_keys=True), before)
        low = dict(primary, ownPieceFloor085=False, pieces=[dict(text='髙', confidence=.4), *primary['pieces'][1:]])
        trial = tails.compose(low, proof, expert)
        self.assertEqual(trial['selectedText'], '髙O03')
        self.assertFalse(trial['selectedEligible'])
        for rejected in [dict(expert, rejectProbability=.5),
                         dict(expert, text='O003', pieces=[dict(text=c, confidence=.99) for c in 'O003'])]:
            trial = tails.compose(primary, proof, rejected)
            self.assertFalse(trial['asciiTail']['selected'])
            self.assertEqual(trial['selectedText'], '髙003')
            self.assertTrue(trial['selectedEligible'])
        with self.assertRaisesRegex(ValueError, 'provenance'):
            tails.compose(primary, dict(proof, originalSuffix='O03'), expert)

    def test_ascii_tail_selection_does_not_infer_missing_letters_or_rename_codes(self):
        expert = dict(text='O03', pieces=[dict(confidence=.99)]*3,
                      paddingSupported=True, rejectProbability=.01)
        self.assertTrue(tails.selects('003', expert))
        self.assertFalse(tails.selects('03', expert))
        for change in [dict(rejectProbability=.051), dict(paddingSupported=False),
                       dict(pieces=[dict(confidence=.8499)]), dict(text='O 3'), dict(text='髙03')]:
            self.assertFalse(tails.selects('003', dict(expert, **change)))
        self.assertTrue(tails.selects('003', dict(expert, text='003')))

    def test_tail_candidate_keeps_raw_non_ascii_prefix_and_needs_original_white_columns(self):
        np = self.arrays()
        rgb = np.full((8, 24, 3), 255, dtype=np.uint8)
        rgb[2:6, 2:8] = 0; rgb[2:6, 14:21] = 0
        primary = dict(frameBox=[100, 200, 24, 8], inputWidth=320, validWidth=144, timeCount=40,
            paddingSupported=True, pieces=[dict(text='髙', start=1, end=6),
                dict(text='0', start=12, end=13), dict(text='0', start=14, end=15), dict(text='3', start=16, end=17)])
        before = json.dumps(primary, ensure_ascii=False, sort_keys=True)
        image, proof = tails.tail_frame(rgb, primary)
        self.assertIsNotNone(image)
        self.assertEqual(proof['originalSuffix'], '003')
        self.assertEqual(proof['prefixPieceCount'], 1)
        self.assertEqual(proof['originalSuffixInkPixels'], 28)
        self.assertTrue(np.all(rgb[:, proof['splitX']-100] == 255))
        self.assertEqual(json.dumps(primary, ensure_ascii=False, sort_keys=True), before)
        rgb[:, 8:17] = 0
        image, proof = tails.tail_frame(rgb, primary)
        self.assertIsNone(image)
        self.assertEqual(proof['state'], 'noOriginalWhiteGap')

    def test_padding_or_standalone_class_fragments_are_not_ascii_tail_trials(self):
        np = self.arrays()
        rgb = np.full((8, 24, 3), 255, dtype=np.uint8)
        for primary in [dict(pieces=[dict(text='1 1')]),
                        dict(pieces=[dict(text='髙'), dict(text='1')]),
                        dict(paddingSupported=False, pieces=[dict(text='髙'), dict(text='0'), dict(text='3')])]:
            image, _ = tails.tail_frame(rgb, primary)
            self.assertIsNone(image)

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
