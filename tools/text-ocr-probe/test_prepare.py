import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('text_prepare', HERE / 'prepare.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class TextComparisonTests(unittest.TestCase):
    def test_exact_original_render_statements_and_pdf_bytes(self):
        with tempfile.TemporaryDirectory() as parent:
            output = Path(parent) / 'prepared'
            module.prepare(output)
            read = module.original.block((module.original.ROOT / 'Takupoke/PDFRecoveryRecognition.swift').read_text(), 'static func read(')
            start = read.index('            let bounds = page.bounds(for: .cropBox)')
            statements = read[start:read.index('            // One bounded page per request;', start)]
            raster = (output / 'OriginalTextRaster.swift').read_text()
            self.assertIn(statements, raster)
            self.assertNotIn('RecognizeDocumentsRequest', raster)
            inputs = json.loads((output / 'inputs.json').read_text())
            self.assertEqual((output / 'inputs.json').read_bytes(), (module.ORIGINAL / 'inputs.json').read_bytes())
            for fixture in inputs['fixtures']:
                self.assertEqual(module.original.sha((output / (fixture['id']+'.pdf')).read_bytes()), fixture['pdfSha256'])
            receipt = json.loads((output / 'extraction.json').read_text())['textOCRComparison']
            self.assertEqual(receipt['renderStatementsSHA256'], module.original.sha(statements.encode()))
            self.assertEqual(receipt['generatedRasterSHA256'], module.original.sha(raster.encode()))
            self.assertEqual(receipt['requestCount'], 10)
            self.assertEqual(receipt['recognitionLanguages'], ['ja-JP', 'en-US'])

if __name__ == '__main__':
    unittest.main()
