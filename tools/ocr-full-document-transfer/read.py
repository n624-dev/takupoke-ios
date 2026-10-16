#!/usr/bin/env python3
"""Recognize actual physical regions; this process never reads an oracle."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import time


ROOT = Path(__file__).resolve().parent


def shared_infer():
    spec = importlib.util.spec_from_file_location('original_pixel_recognizer', ROOT.parent / 'ocr-windows-transfer/infer.py')
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result


def intervals(active):
    result, start = [], None
    for index, value in enumerate([*active, False]):
        if value and start is None:
            start = index
        elif not value and start is not None:
            result.append((start, index)); start = None
    return result


def regions(gray, mask, cells):
    import numpy as np
    if gray.ndim != 2 or mask.shape != gray.shape or not np.isin(mask, [0, 1]).all():
        raise ValueError('Invalid original pixel/mask shape')
    if ((mask != 0) & (gray == 255)).any():
        raise ValueError('A production rule mask covered white pixels')
    height, width = gray.shape
    ink = (gray != 255) & (mask == 0)
    owner = np.full(gray.shape, -1, dtype=np.int32)
    rectangles = []
    for index, box in enumerate(cells):
        if len(box) != 4 or not all(math.isfinite(x) for x in box):
            raise ValueError('Invalid actual physical cell')
        x, y, w, h = box
        if not (0 <= x and 0 <= y and w > 0 and h > 0 and x+w <= width and y+h <= height):
            raise ValueError('Actual physical cell is outside the original page')
        bounds = (max(0, math.ceil(x-.5)), max(0, math.ceil(y-.5)),
                  min(width, math.floor(x+w-.5)+1), min(height, math.floor(y+h-.5)+1))
        rectangles.append(bounds)
        a, b, c, d = bounds
        local = ink[b:d, a:c]
        existing = owner[b:d, a:c]
        if (local & (existing != -1)).any():
            raise ValueError('Printed ink has competing physical cell owners')
        existing[local] = index
    output, counted = [], 0
    for index, (a, b, c, d) in enumerate([*rectangles, (0, 0, width, height)]):
        identity = index if index < len(cells) else -1
        local = ink[b:d, a:c] & (owner[b:d, a:c] == identity)
        bands = intervals(local.any(axis=1))
        for ordinal, (top, bottom) in enumerate(bands):
            top_limit = 0 if ordinal == 0 else (bands[ordinal-1][1] + top) // 2
            bottom_limit = d-b if ordinal+1 == len(bands) else (bottom + bands[ordinal+1][0]) // 2
            occupied = intervals(local[top:bottom].any(axis=0))
            groups = []
            for left, right in occupied:
                if groups and left-groups[-1][1] < max(4, bottom-top):
                    groups[-1] = (groups[-1][0], right)
                else:
                    groups.append((left, right))
            for column, (left, right) in enumerate(groups):
                left_limit = 0 if column == 0 else (groups[column-1][1] + left) // 2
                right_limit = c-a if column+1 == len(groups) else (right + groups[column+1][0]) // 2
                x0, y0 = a+max(left_limit, left-2), b+max(top_limit, top-2)
                x1, y1 = a+min(right_limit, right+2), b+min(bottom_limit, bottom+2)
                expected_ink = int(local[top:bottom, left:right].sum())
                actual = ink[y0:y1, x0:x1]
                if (actual & (owner[y0:y1, x0:x1] != identity)).any() or int(actual.sum()) != expected_ink:
                    raise ValueError('Original-pixel frame includes another ink region')
                counted += expected_ink
                output.append(dict(ownerCell=None if identity == -1 else identity,
                                   inkBox=[a+left, b+top, right-left, bottom-top],
                                   frameBox=[x0, y0, x1-x0, y1-y0], originalInkPixels=expected_ink))
    if counted != int(ink.sum()):
        raise ValueError('Some original non-rule ink was omitted or duplicated')
    return output, dict(originalNonRuleInkPixels=int(ink.sum()), assignedInkPixels=counted,
                        outsidePhysicalCellsInkPixels=int((ink & (owner == -1)).sum()))


def checked_file(root, entry, name):
    filename = entry[name]
    if '/' in filename or '..' in filename:
        raise ValueError('Invalid owned acquisition filename')
    data = (root / filename).read_bytes()
    if hashlib.sha256(data).hexdigest() != entry[name+'SHA256']:
        raise ValueError('Original acquisition artifact changed')
    return data


def native_records(identity, variant, capture):
    """Report the saved original capture only after XCTest has exited."""
    lines = capture['lines']
    if len(lines) > 100000 or [line['nativeOrder'] for line in lines] != list(range(len(lines))):
        raise ValueError('Original native line inventory changed')
    result = []
    for line in lines:
        first = line['candidates'][0]
        box = first.get('observationRange')
        if box is None:
            raise ValueError('Original native observation range is missing')
        result.append(dict(id=identity, variant=variant, nativeOrder=line['nativeOrder'],
            text=first['text'], confidence=first['confidence'],
            box=[box[k] for k in ['x', 'y', 'width', 'height']],
            nativeCandidates=[dict(text=c['text'], confidence=c['confidence']) for c in line['candidates']]))
    return result


def has_native_capture(document, variant):
    expected = 'captured' if variant == 'current2048' else 'notRequestedDimensionBound'
    present = 'nativeCapture' in document and 'nativeCaptureSHA256' in document
    if document.get('nativeVisionState') != expected or present != (variant == 'current2048'):
        raise ValueError('Original native acquisition state is inconsistent')
    if variant != 'current2048' and ('nativeCapture' in document or 'nativeCaptureSHA256' in document):
        raise ValueError('Unrequested Vision is not an empty or fabricated capture')
    return present


def main():
    import numpy as np
    import onnxruntime as ort
    from PIL import Image
    parser = argparse.ArgumentParser()
    parser.add_argument('--acquisition', type=Path, required=True)
    parser.add_argument('--models', type=Path, required=True)
    args = parser.parse_args()
    root = args.acquisition
    target = root / 'recognized.json'
    if target.exists():
        raise ValueError('Never overwrite a completed recognition')
    pins = json.loads((ROOT.parent / 'ocr-ios-runtime-parity/protocol.json').read_text())
    for pin in [pins['model'], pins['dictionary']]:
        data = (args.models / pin['file']).read_bytes()
        if len(data) != pin['bytes'] or hashlib.sha256(data).hexdigest() != pin['sha256']:
            raise ValueError('Pinned recognition artifact changed')
    if ort.__version__ != pins['runtime']['version']:
        raise ValueError('CPU Runtime changed')
    ort.disable_telemetry_events()
    options = ort.SessionOptions(); options.intra_op_num_threads = 2; options.inter_op_num_threads = 1; options.log_severity_level = 3
    session = ort.InferenceSession(str(args.models / pins['model']['file']), sess_options=options, providers=['CPUExecutionProvider'])
    dictionary = json.loads((args.models / pins['dictionary']['file']).read_text())
    infer = shared_infer()
    acquisition = json.loads((root / 'acquisition.json').read_text())
    variant, documents = acquisition['variant'], acquisition['documents']
    if variant not in ['current2048', 'source2x4096']:
        raise ValueError('Undeclared acquisition comparison condition')
    if len(documents) != 6 or len({d['id'] for d in documents}) != 6:
        raise ValueError('Incomplete actual acquisition')
    results, calls = [], 0
    for document in documents:
        checked_file(root, document, 'image')
        gray_data = checked_file(root, document, 'grayscale')
        mask_data = checked_file(root, document, 'mask')
        if has_native_capture(document, variant):
            original_capture = checked_file(root, document, 'nativeCapture')
            native = native_records(document['id'], variant, json.loads(original_capture))
            for record in native:
                print('FULL_SOURCE_VISION ' + json.dumps(record, ensure_ascii=False, sort_keys=True), flush=True)
            print('FULL_SOURCE_NATIVE_CAPTURE ' + json.dumps(dict(id=document['id'], variant=variant,
                originalNativeLineCount=len(native), nativeCaptureSHA256=document['nativeCaptureSHA256']), sort_keys=True), flush=True)
        else:
            print('FULL_SOURCE_NATIVE_UNREQUESTED ' + json.dumps(dict(id=document['id'], variant=variant,
                reason='Original Vision adapter retains its 2048px dimension bound; use unchanged current2048 baseline.'), sort_keys=True), flush=True)
        height, width = document['height'], document['width']
        gray = np.frombuffer(gray_data, dtype=np.uint8).reshape(height, width)
        mask = np.frombuffer(mask_data, dtype=np.uint8).reshape(height, width)
        with Image.open(root / document['image']) as image:
            rgb = np.asarray(image.convert('RGB'))
            # Check source pixels and coordinate orientation against the actual
            # production raster before choosing any frame; never flip to fit.
            derived_gray = ((rgb.astype(np.uint32) * np.array([299, 587, 114], dtype=np.uint32)).sum(axis=2) // 1000).astype(np.uint8)
            if rgb.shape[:2] != (height, width) or not np.array_equal(derived_gray, gray):
                raise ValueError('PNG pixels and production raster do not agree')
            proposed, coverage = regions(gray, mask, document['cells'])
            captured = []
            for index, region in enumerate(proposed):
                x, y, w, h = region['frameBox']
                source = rgb[y:y+h, x:x+w]
                record = dict(region, index=index, sourcePixelsSHA256=hashlib.sha256(source.tobytes()).hexdigest())
                # Width refusal is an explicit model capacity result, not blank.
                if math.floor(48 * max(320/48, w/h)) > 960:
                    record.update(state='unsupported-width', text=None, pieces=None)
                else:
                    tensor, valid, padded = infer.transform(source)
                    started = time.monotonic()
                    probability = session.run(None, {'x': tensor})[0]
                    calls += 1
                    pieces = infer.decode(probability, dictionary)
                    record.update(state='recognized', text=''.join(p['text'] for p in pieces), pieces=pieces,
                        inputSHA256=hashlib.sha256(tensor.tobytes()).hexdigest(), seconds=time.monotonic()-started,
                        validWidth=valid, inputWidth=padded, timeCount=int(probability.shape[1]),
                        paddingSupported=all(p['end']*padded <= valid*probability.shape[1] for p in pieces),
                        ownPieceFloor085=bool(pieces) and all(p['confidence'] >= .85 for p in pieces))
                captured.append(record)
                print('FULL_SOURCE_RECOGNITION ' + json.dumps(dict(id=document['id'], variant=variant, **record), ensure_ascii=False, sort_keys=True), flush=True)
            results.append(dict(id=document['id'], sourcePDFSHA256=document['sourcePDFSHA256'], coverage=coverage, records=captured))
    if calls != sum(r['state'] == 'recognized' for d in results for r in d['records']):
        raise ValueError('Actual model-call inventory is incomplete')
    target.write_text(json.dumps(dict(variant=variant, documents=results, actualCalls=calls, runtime=ort.__version__), ensure_ascii=False, sort_keys=True)+'\n')
    print('FULL_SOURCE_RECOGNITION_FINISHED ' + json.dumps(dict(variant=variant, documents=len(results), actualCalls=calls)), flush=True)


if __name__ == '__main__':
    main()
