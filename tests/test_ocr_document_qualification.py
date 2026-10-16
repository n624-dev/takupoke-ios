"""Complete frozen invented source designs, never model-selected examples."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]/'tools/ocr-document-qualification'
spec = importlib.util.spec_from_file_location('qualification_source_design', ROOT/'generate.py')
generate = importlib.util.module_from_spec(spec); spec.loader.exec_module(generate)


class CompleteSourceDesignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        value = os.environ.get('TAKUPOKE_OCR_FULL_FONTS')
        if not value: raise unittest.SkipTest('Dedicated pinned public font source environment')
        cls.fonts = Path(value)
        cls.protocol = json.loads((ROOT/'protocol.json').read_text())

    def test_all_six_frozen_sources_have_all_classes_days_periods_and_image_only_pixels(self):
        import fitz
        for case in self.protocol['cases']:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)/'source'; generate.generate(root, case, self.fonts)
                manifest = json.loads((root/'inputs.json').read_text())['documents']
                self.assertEqual(len(manifest), 1)
                entry = manifest[0]
                self.assertEqual(set(entry), {'id','kind','pdf','pdfSHA256','pageCount'})
                self.assertEqual(entry['id'], 'qualification-'+case)
                with fitz.open(root/entry['pdf']) as pdf:
                    self.assertEqual(len(pdf), 1); self.assertEqual(pdf[0].get_text(), '')
                    self.assertEqual(len(pdf[0].get_images()), 1)
                source = json.loads((root/'oracle.json').read_text())['documents'][0]
                body = [r for r in source['records'] if r['category']=='body']
                classes = [r['text'] for r in source['records'] if r['category']=='class']
                self.assertEqual(classes, self.protocol['classes']); self.assertEqual(len(classes), 17)
                self.assertEqual(len(body), self.protocol['requiredBodyFields'][entry['kind']])
                targets = [(r['target']['className'],r['target']['day'],r['target']['period'],r['target']['role']) for r in body]
                self.assertEqual(len(targets), len(set(targets)))
                self.assertEqual(len({t[1] for t in targets}), 5)
                self.assertEqual({t[2] for t in targets}, set(range(1,self.protocol['periods'][entry['kind']]+1)))
                self.assertEqual({t[3] for t in targets}, {'subject','teacher','room'})
                self.assertTrue(all(r['text'].startswith(('架空講座','架空担当','架空棟')) for r in body))

    def test_frozen_case_reproduces_pdf_and_oracle_without_reading_model_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); a, b = root/'a', root/'b'
            for output in [a,b]: generate.generate(output, 'f2-return', self.fonts)
            for name in ['inputs.json','oracle.json','qualification-f2-return.pdf','qualification-f2-return-source.png']:
                self.assertEqual((a/name).read_bytes(), (b/name).read_bytes())

    def test_unknown_case_and_overwrite_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)/'source'
            with self.assertRaisesRegex(ValueError, 'Undeclared frozen'):
                generate.generate(output, 'selected-after-results', self.fonts)
            generate.generate(output, 'f1-timetable', self.fonts)
            before = (output/'inputs.json').read_bytes()
            with self.assertRaises(FileExistsError): generate.generate(output, 'f1-timetable', self.fonts)
            self.assertEqual((output/'inputs.json').read_bytes(), before)


if __name__ == '__main__': unittest.main()
