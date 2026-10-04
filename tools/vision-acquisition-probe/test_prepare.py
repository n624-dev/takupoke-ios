import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('prepare',HERE/'prepare.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class PreparationTests(unittest.TestCase):
    def test_unique_selector_and_balanced_real_blocks(self):
        self.assertEqual(module.block('enum A { let text = "}"; /* { */ let x = 2 }','enum A'), 'enum A { let text = "}"; /* { */ let x = 2 }')
        for text in ['enum A {} enum A {}','enum B {}','enum A {']:
            with self.assertRaises(ValueError): module.block(text,'enum A')
    def test_frozen_source_and_original_pdf_bytes(self):
        with tempfile.TemporaryDirectory() as parent:
            output=Path(parent)/'prepared'; module.prepare(output)
            inputs=json.loads((output/'inputs.json').read_text())
            self.assertEqual(len(inputs['fixtures']),2)
            self.assertEqual(sum(len(v['pages']) for v in inputs['fixtures']),10)
            for v in inputs['fixtures']:
                self.assertEqual(module.sha((output/(v['id']+'.pdf')).read_bytes()),v['pdfSha256'])
            generated=(output/'OriginalAcquisition.swift').read_text()
            original=(module.ROOT/'Takupoke/PDFRecoveryRecognition.swift').read_text()
            body=module.block(original,'static func read(')
            self.assertIn(body,generated)
            self.assertNotIn('static func layouts(',generated)
            self.assertNotIn('CoreAI',generated)
            self.assertEqual(module.sha(body.encode()),json.loads((output/'extraction.json').read_text())['readBodySHA256'])
    def test_source_tamper_before_generation(self):
        # Supply an isolated fake root, leaving the real production bytes untouched.
        previous=module.ROOT
        try:
            with tempfile.TemporaryDirectory() as parent:
                root=Path(parent);(root/'Takupoke').mkdir()
                (root/'Takupoke/PDFRecoveryRecognition.swift').write_text('changed')
                module.ROOT=root
                with self.assertRaises(ValueError): module.prepare(root/'output')
                self.assertFalse((root/'output').exists())
        finally: module.ROOT=previous

if __name__=='__main__': unittest.main()
