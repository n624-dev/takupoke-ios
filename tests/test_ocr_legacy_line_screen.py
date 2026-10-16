import copy
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('legacy_line_screen', Path(__file__).resolve().parents[1]/'tools/ocr-legacy-line-screen/compare.py')
MODULE = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(MODULE)


class LegacyLineScreenTests(unittest.TestCase):
    def fixture(self):
        frames, oracle, rows = [], [], []
        for page in range(1, 7):
            for field in range(1, 25):
                identity = f'p{page}-f{field}'
                oracle.append(dict(id=identity, text='架空検査', font='fictional', group='control'))
                frames.extend(dict(id=identity, frame=name, sha256='a'*64) for name in ['observed-ink-margin-2', 'physical-interior'])
                for factor in [1, 4]:
                    rows.append(dict(id=identity, factor=factor, sourceImageSHA256='a'*64, sourceRGBAHash='b'*64,
                        inputRGBAHash=('b' if factor == 1 else 'c')*64, sourceWidth=40, sourceHeight=20,
                        inputWidth=40*factor, inputHeight=20*factor, everyScaledPixelVerified=True, revision=3,
                        languages=['ja-JP', 'en-US'], usesLanguageCorrection=False, seconds=.1, state='recognized',
                        characterMappingErrors=0,
                        observations=[dict(sourceBox=[2, 2, 30, 12], candidates=[dict(text='架空検査', confidence=.9)])]))
        return frames, oracle, dict(actualCalls=288, records=rows)

    def test_preserves_high_score_wrong_and_counts_paired_gains_and_losses(self):
        frames, oracle, capture = self.fixture()
        capture['records'][0]['observations'][0]['candidates'][0]['text'] = '架空誤読'
        capture['records'][3]['observations'][0]['candidates'][0]['text'] = '架空誤読'
        result = MODULE.evaluate(frames, oracle, capture)
        self.assertEqual(result['paired'], dict(gains=1, losses=1))
        self.assertEqual([r['ownNative085Wrong'] for r in result['summaries']], [1, 1])

    def test_refuses_omission_duplication_source_drift_and_changed_configuration(self):
        for mutation in ['omit', 'duplicate', 'hash', 'width', 'source', 'revision', 'correction']:
            with self.subTest(mutation=mutation):
                frames, oracle, capture = self.fixture(); row = capture['records'][1]
                if mutation == 'omit': capture['records'].pop()
                elif mutation == 'duplicate': capture['records'][-1] = copy.deepcopy(row)
                elif mutation == 'hash': row['sourceImageSHA256'] = 'd'*64
                elif mutation == 'width': row['inputWidth'] += 1
                elif mutation == 'source': row['sourceRGBAHash'] = 'e'*64
                elif mutation == 'revision': row['revision'] = 2
                else: row['usesLanguageCorrection'] = True
                with self.assertRaises(ValueError): MODULE.evaluate(frames, oracle, capture)

    def test_api_error_is_not_an_empty_or_successful_recognition(self):
        frames, oracle, capture = self.fixture(); row = capture['records'][1]
        row.update(state='nativeError', errorDomain='FictionalError', errorCode=7)
        with self.assertRaises(ValueError): MODULE.evaluate(frames, oracle, capture)
        del row['observations']
        result = MODULE.evaluate(frames, oracle, capture)
        self.assertEqual(result['summaries'][1]['nativeErrors'], 1)
        self.assertEqual(result['summaries'][1]['exact'], 143)
        self.assertEqual(result['paired']['losses'], 1)

    def test_split_outside_and_low_native_scores_are_retained(self):
        frames, oracle, capture = self.fixture()
        capture['records'][0]['observations'][0]['candidates'][0]['confidence'] = .84
        capture['records'][2]['observations'] *= 2
        capture['records'][4]['observations'][0]['sourceBox'] = [-1, 2, 30, 12]
        result = MODULE.evaluate(frames, oracle, capture)
        self.assertEqual(result['summaries'][0]['exact'], 142)
        self.assertEqual(result['summaries'][0]['ownNative085Exact'], 141)
        self.assertEqual(result['summaries'][0]['missingSplitOrOutside'], 2)

    def test_geometry_error_preserves_recognized_literal_and_native_confidence(self):
        frames, oracle, capture = self.fixture()
        capture['records'][1]['characterMappingErrors'] = 1
        result = MODULE.evaluate(frames, oracle, capture)
        self.assertEqual(result['summaries'][1]['nativeGeometryErrors'], 1)
        self.assertEqual(result['summaries'][1]['exact'], 144)
        self.assertEqual(result['fields'][1]['confidence'], .9)


if __name__ == '__main__':
    unittest.main()
