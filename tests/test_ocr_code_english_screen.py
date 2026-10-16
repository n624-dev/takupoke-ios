"""Synthetic comparator contracts only; these mocks are not OCR accuracy results."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

FOLDER = Path(__file__).resolve().parents[1]/'tools/ocr-code-english-screen'
sys.path.insert(0,str(FOLDER))
from code_english_contract import inputs, sha
spec = importlib.util.spec_from_file_location('original_code_comparison',FOLDER/'compare.py')
comparison = importlib.util.module_from_spec(spec); spec.loader.exec_module(comparison)
sys.path.remove(str(FOLDER))


def fixture():
    frames, oracle, native, model = [], [], [], []
    normalized = [.1,.1,.8,.8]
    box = [2,(1-(.1+.8))*10,16,8]
    for i in range(192):
        identity = f'code-{i:04}'
        frames.append(dict(id=identity,rgb=identity+'.rgb',width=20,height=10,rgbSHA256='a'*64))
        oracle.append(dict(id=identity,text='A1',font='fictional-unit-font',size=10))
        characters = [dict(text=c,nativeNormalizedBox=normalized,sourceBox=box) for c in 'A1']
        native.append(dict(id=identity,width=20,height=10,sourceRGBSHA256='a'*64,actualRGBSHA256='a'*64,
            originalPixelsReadbackVerified=True,revision=3,languages=['en-US'],usesLanguageCorrection=False,
            recognitionLevel='accurate',automaticLanguageDetection=False,minimumTextHeight=0,customWords=[],
            seconds=.01,state='recognized',characterMappingErrors=0,observations=[dict(nativeNormalizedBox=normalized,
                sourceBox=box,candidates=[dict(text='A1',confidence=.95,characters=characters)])]))
        model.append(dict(id=identity,reader='english-v1',sourcePixelsSHA256='a'*64,inputSHA256='b'*64,
            inputWidth=320,validWidth=96,timeCount=40,rejectProbability=.01,paddingSupported=True,seconds=.01,
            text='A1',pieces=[dict(text='A',start=0,end=1,confidence=.95),dict(text='1',start=2,end=3,confidence=.95)]))
    return frames, oracle, dict(actualCalls=192,records=native), dict(actualCalls=192,records=model)


class OriginalCodeEnglishTests(unittest.TestCase):
    def test_identical_pixel_conflicting_literals_are_reported_without_removing_fields(self):
        args = fixture(); args[1][0]['text'] = 'A0'
        fields, summary = comparison.evaluate(*args)
        self.assertEqual(len(fields),192)
        self.assertEqual(summary['differentLiteralIdenticalImageGroups'],1)
        self.assertEqual(summary['sourceByteLiteralCeiling'],191)
        self.assertEqual(summary['nativeLiteral'],191)

    def test_complete_inventory_and_distinct_literal_probability_domains(self):
        args = fixture()
        args[2]['records'][0]['observations'][0]['candidates'][0]['confidence'] = .84
        args[3]['records'][1]['pieces'][0]['confidence'] = .84
        fields, summary = comparison.evaluate(*args)
        self.assertEqual(len(fields),192)
        self.assertEqual((summary['nativeLiteral'],summary['modelLiteral']),(192,192))
        self.assertEqual((summary['nativeOwn085Exact'],summary['modelOwnConditionsExact']),(191,191))
        self.assertFalse(summary['physicalOwnershipQualified'])
        self.assertFalse(summary['wholeDocumentQualified'])

    def test_high_score_wrong_outputs_and_paired_losses_are_retained(self):
        args = fixture()
        top = args[2]['records'][0]['observations'][0]['candidates'][0]
        top['text'] = 'AI'; top['characters'][-1]['text'] = 'I'
        row = args[3]['records'][1]; row['text'] = 'A0'; row['pieces'][-1]['text'] = '0'
        _, summary = comparison.evaluate(*args)
        self.assertEqual((summary['nativeOwn085Wrong'],summary['modelOwnConditionsWrong']),(1,1))
        self.assertEqual((summary['nativeGainsOverV1'],summary['nativeLossesOverV1']),(1,1))

    def test_missing_duplicate_reordered_and_partial_calls_fail(self):
        for mutation in range(5):
            args = fixture()
            if mutation == 0: args[0].pop()
            if mutation == 1: args[1].pop()
            if mutation == 2: args[2]['records'][1]['id'] = 'code-0000'
            if mutation == 3: args[3]['records'].reverse()
            if mutation == 4: args[2]['actualCalls'] = 191
            with self.assertRaises(ValueError): comparison.evaluate(*args)

    def test_changed_pixels_configuration_and_padding_are_rejected(self):
        for mutation in range(6):
            args = fixture(); n, m = args[2]['records'][0], args[3]['records'][0]
            if mutation == 0: n['actualRGBSHA256'] = 'b'*64
            if mutation == 1: m['sourcePixelsSHA256'] = 'b'*64
            if mutation == 2: n['languages'] = ['ja-JP','en-US']
            if mutation == 3: n['usesLanguageCorrection'] = True
            if mutation == 4: m['paddingSupported'] = False
            if mutation == 5: m['validWidth'] = 95
            with self.assertRaises(ValueError): comparison.evaluate(*args)

    def test_geometry_remains_original_and_outside_is_not_clamped_or_hidden(self):
        args = fixture(); observation = args[2]['records'][0]['observations'][0]
        observation['sourceBox'][0] += 1
        with self.assertRaises(ValueError): comparison.evaluate(*args)
        args = fixture(); observation = args[2]['records'][0]['observations'][0]
        observation['nativeNormalizedBox'] = [-.1,.1,.8,.8]
        observation['sourceBox'] = [-2,(1-(.1+.8))*10,16,8]
        _, summary = comparison.evaluate(*args)
        self.assertEqual(summary['nativeBoxesOutsideSmallFrame'],1)
        self.assertEqual(summary['nativeLiteral'],192)
        self.assertFalse(summary['physicalOwnershipQualified'])


        args = fixture(); record = args[2]['records'][0]
        character = record['observations'][0]['candidates'][0]['characters'][0]
        character.pop('nativeNormalizedBox'); character.pop('sourceBox')
        character.update(mappingErrorDomain='fictional-unit-geometry',mappingErrorCode=9)
        with self.assertRaises(ValueError): comparison.evaluate(*args)
        record['characterMappingErrors'] = 1
        fields, summary = comparison.evaluate(*args)
        self.assertEqual(len(fields),192)
        self.assertEqual(summary['nativeGeometryErrors'],1)

    def test_input_inventory_rejects_expected_text_and_original_byte_drift(self):
        frames, _, _, _ = fixture(); raw = bytes([255])*600
        with tempfile.TemporaryDirectory(prefix='original-code-contract-') as scratch:
            root = Path(scratch)
            for r in frames:
                r['rgbSHA256'] = sha(raw); (root/r['rgb']).write_bytes(raw)
            path = root/'inputs.json'; path.write_text(json.dumps(dict(frames=frames)))
            self.assertEqual(len(inputs(root)),192)
            frames[0]['text'] = 'unexpected-oracle'; path.write_text(json.dumps(dict(frames=frames)))
            with self.assertRaises(ValueError): inputs(root)
            del frames[0]['text']; path.write_text(json.dumps(dict(frames=frames)))
            (root/frames[0]['rgb']).write_bytes(raw[:-1]+b'\x00')
            with self.assertRaises(ValueError): inputs(root)

    def test_native_api_error_is_retained_and_cli_fails_after_complete_raw_report(self):
        frames, oracle, native, model = fixture(); raw = bytes([255])*600
        native['records'][0].pop('observations'); native['records'][0].pop('characterMappingErrors')
        native['records'][0].update(state='nativeError',errorDomain='fictional-unit-api',errorCode=7)
        with tempfile.TemporaryDirectory(prefix='original-code-failure-') as scratch:
            root = Path(scratch)
            for f, n, m in zip(frames,native['records'],model['records']):
                f['rgbSHA256'] = n['sourceRGBSHA256'] = n['actualRGBSHA256'] = m['sourcePixelsSHA256'] = sha(raw)
                (root/f['rgb']).write_bytes(raw)
            for name, value in [('inputs.json',dict(frames=frames)),('oracle.json',dict(fields=oracle)),('native.json',native),('model.json',model)]:
                (root/name).write_text(json.dumps(value))
            output = io.StringIO()
            with patch.object(sys,'argv',['compare.py',str(root)]), contextlib.redirect_stdout(output), self.assertRaises(ValueError):
                comparison.main()
            self.assertEqual(sum(x.startswith('CODE_ENGLISH_NATIVE ') for x in output.getvalue().splitlines()),192)
            self.assertEqual(sum(x.startswith('CODE_ENGLISH_FIELD ') for x in output.getvalue().splitlines()),192)
            self.assertIn('"nativeErrors": 1',output.getvalue())


if __name__ == '__main__':
    unittest.main()
