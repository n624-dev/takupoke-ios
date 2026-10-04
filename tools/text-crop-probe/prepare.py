"""Reuse unchanged input/raster verification for one finite two-region comparison."""
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('text_prepare', HERE.parent / 'text-ocr-probe/prepare.py')
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)

def prepare(output):
    original.prepare(output)
    receipt = json.loads((output / 'extraction.json').read_text())
    settings = receipt.pop('textOCRComparison')
    settings.update(scope='Only first original literal PDF page is rendered once; two lossless crops go to two text requests, no full-page request',
                    requestCount=2, selectedFixture='independent-Timetable-literal-乙', selectedPage=1,
                    cropRule='Integer midpoint +/-16 original pixels; 32px overlap; full height; no resizing',
                    inverseRule='Original top-left pixel x = crop pixel x + crop x offset; y unchanged')
    receipt['textCropComparison'] = settings
    (output / 'extraction.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__ == '__main__':
    prepare(Path(sys.argv[1]))
