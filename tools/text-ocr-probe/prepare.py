"""Reuse immutable input verification and extract the exact original thumbnail statements."""
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ORIGINAL = HERE.parent / 'vision-acquisition-probe'
spec = importlib.util.spec_from_file_location('original_prepare', ORIGINAL / 'prepare.py')
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)

def prepare(output):
    original.prepare(output)
    source = (original.ROOT / 'Takupoke/PDFRecoveryRecognition.swift').read_text()
    read = original.block(source, 'static func read(')
    start = read.index('            let bounds = page.bounds(for: .cropBox)')
    end = read.index('            // One bounded page per request;', start)
    statements = read[start:end]
    generated = ('import Foundation\nimport PDFKit\nimport UIKit\n'
                 'enum OriginalTextRaster {\n'
                 '    static func render(_ page: PDFPage, index: Int) throws -> CGImage {\n'
                 + statements + '            return raster\n    }\n}\n').encode()
    (output / 'OriginalTextRaster.swift').write_bytes(generated)
    receipt = json.loads((output / 'extraction.json').read_text())
    receipt['textOCRComparison'] = {
        'scope': 'Only extracted thumbnail statements execute; original .read and document OCR are never called',
        'renderStatementsSHA256': original.sha(statements.encode()),
        'generatedRasterSHA256': original.sha(generated),
        'api': 'RecognizeTextRequest', 'recognitionLevel': 'accurate',
        'recognitionLanguages': ['ja-JP', 'en-US'], 'usesLanguageCorrection': False,
        'automaticallyDetectsLanguage': False, 'customWords': [],
        'requestCount': 10, 'candidatesPerObservation': 1,
        'confidencePredicate': 'finite and 0.85...1; diagnostic only',
        'nativeInputs': 'Only original two PDFs and input manifest; no expected text, gold or drawing source',
    }
    (output / 'extraction.json').write_text(json.dumps(receipt, indent=2) + '\n')

if __name__ == '__main__':
    prepare(Path(sys.argv[1]))
