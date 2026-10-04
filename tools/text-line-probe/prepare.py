"""Derive bounded ROIs only from captured low-confidence observation geometry."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys
import zlib

HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent.parent / 'research-results/ios-text-crop-one-page-20261004'
RAW_SHA = 'feeb3cdd4ea2f930f305cc94050c8ba5ba018a10ba259f7a14abc8823ca8b78c'
PAD = 2
LIMIT = 16

def sha(data):
    return hashlib.sha256(data).hexdigest()

def rgba_png(data):
    """Decode the captured noninterlaced 8-bit RGBA PNG, with CRC checks."""
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    offset, packed, dimensions = 8, bytearray(), None
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset+4])[0]
        kind = data[offset+4:offset+8]; payload = data[offset+8:offset+8+length]
        assert zlib.crc32(kind + payload) & 0xffffffff == struct.unpack('>I', data[offset+8+length:offset+12+length])[0]
        if kind == b'IHDR':
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            assert (depth, color, compression, filtering, interlace) == (8, 6, 0, 0, 0)
            dimensions = width, height
        elif kind == b'IDAT': packed.extend(payload)
        offset += length + 12
    assert dimensions and 0 < width <= 2048 and 0 < height <= 2048
    filtered = zlib.decompress(packed); stride = width*4
    assert len(filtered) == height*(stride+1)
    previous = bytearray(stride); result = bytearray()
    for y in range(height):
        mode = filtered[y*(stride+1)]; row = bytearray(filtered[y*(stride+1)+1:(y+1)*(stride+1)])
        assert mode in range(5)
        for x in range(stride):
            a = row[x-4] if x >= 4 else 0; b = previous[x]; c = previous[x-4] if x >= 4 else 0
            p = a+b-c
            pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
            predictor = (0, a, b, (a+b)//2, a if pa <= pb and pa <= pc else b if pb <= pc else c)[mode]
            row[x] = (row[x]+predictor) & 255
        result.extend(row); previous = row
    assert all(result[x] == 255 for x in range(3, len(result), 4)), 'Opaque captured pixels required'
    return width, height, bytes(result)

def derive(records):
    env = next(value for value in records if value.get('type') == 'environment')
    width, height = env['originalImage']['width'], env['originalImage']['height']
    assert (width, height) == (984, 197)
    regions = [value for value in records if value.get('type') == 'region']
    assert [value['region'] for value in regions] == ['left', 'right']
    rois = []
    for region in regions:
        assert region['readReturned'] and region['serializationCompleted']
        for line in region['lines']:
            confidence = line['confidence']
            assert isinstance(confidence, (float, int)) and math.isfinite(confidence) and 0 <= confidence <= 1
            if confidence >= .85: continue
            box = line['observationBox']; assert box['finite']
            original, local = box['originalPixelTopLeft'], box['cropPixelTopLeft']
            x, y, w, h = (original[key] for key in ['x', 'y', 'width', 'height'])
            assert all(math.isfinite(value) for value in [x, y, w, h]) and w > 0 and h > 0
            assert abs(x-local['x']-region['offsetX']) < 1e-6 and abs(y-local['y']-region['offsetY']) < 1e-6
            left, top = max(0, math.floor(x)-PAD), max(0, math.floor(y)-PAD)
            right, bottom = min(width, math.ceil(x+w)+PAD), min(height, math.ceil(y+h)+PAD)
            assert left < right and top < bottom
            rois.append({'id': f"{region['region']}-{line['nativeOrder']:04d}",
                         'sourceRegion': region['region'], 'sourceNativeOrder': line['nativeOrder'],
                         'sourceConfidence': confidence, 'sourceObservationOriginalPixelBox': original,
                         'x': left, 'y': top, 'width': right-left, 'height': bottom-top})
    assert 0 < len(rois) <= LIMIT and len({roi['id'] for roi in rois}) == len(rois)
    return env, rois

def prepare(output):
    raw = (PRIOR/'native-raw.jsonl').read_bytes(); assert sha(raw) == RAW_SHA
    env, rois = derive([json.loads(line) for line in raw.splitlines()])
    png = (PRIOR/'native-render/original.png').read_bytes()
    assert sha(png) == env['originalPNG']['sha256']
    width, height, rgba = rgba_png(png)
    assert (width, height) == (env['originalImage']['width'], env['originalImage']['height'])
    spec = importlib.util.spec_from_file_location('original_text_prepare', HERE.parent/'text-ocr-probe/prepare.py')
    original = importlib.util.module_from_spec(spec); spec.loader.exec_module(original)
    original.prepare(output)
    manifest = {'schema': 1, 'fixture': env['fixture'], 'page': 1, 'pdfSha256': env['pdfSHA256'],
                'capturedRawSHA256': RAW_SHA, 'originalPNG_SHA256': sha(png),
                'originalRGBA_SHA256': sha(rgba), 'originalImage': env['originalImage'],
                'selection': 'Every finite top1 confidence <0.85; geometry only, raw text is not read',
                'paddingPixels': PAD, 'maxRequests': LIMIT, 'requestCount': len(rois), 'rois': rois}
    (output/'line-rois.json').write_text(json.dumps(manifest, indent=2)+'\n')
    receipt = json.loads((output/'extraction.json').read_text())
    settings = receipt.pop('textOCRComparison')
    settings.update(scope='First original literal page rendered once; only captured low-confidence line ROIs requested',
                    requestCount=len(rois), selectedFixture=env['fixture'], selectedPage=1,
                    nativeInputs='Original PDFs and input manifest plus actual-observation geometry ROI manifest only; no raw/expected text or gold',
                    cropRule='floor(min)-2, ceil(max)+2, integer clip to original image; no resizing',
                    inverseRule='Original top-left pixel x/y = local pixel x/y + ROI integer offsets',
                    roiManifestSHA256=sha((output/'line-rois.json').read_bytes()), capturedRawSHA256=RAW_SHA)
    receipt['textLineComparison'] = settings
    (output/'extraction.json').write_text(json.dumps(receipt, indent=2)+'\n')

if __name__ == '__main__': prepare(Path(sys.argv[1]))
