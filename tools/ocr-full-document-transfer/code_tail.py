"""Source-only trial of a separately tagged ASCII specialist, never a name map."""
import hashlib
import json
import math
from pathlib import Path
import time


def tail_frame(rgb, primary):
    import numpy as np
    pieces = primary.get('pieces') or []
    start = max((i+1 for i, p in enumerate(pieces) if any(ord(c) > 127 for c in p['text'])), default=0)
    suffix = ''.join(p['text'] for p in pieces[start:])
    if (not start or not 2 <= len(suffix) <= 32 or not any('0' <= c <= '9' for c in suffix) or
            any(not 33 <= ord(c) <= 126 for c in suffix)):
        return None, dict(state='outsideDeclaredNonAsciiPrefixTail')
    if not primary.get('paddingSupported'):
        return None, dict(state='primaryPaddingUnsupported')
    # CTC suggests a boundary; an original white band proves only an ink
    # partition, never the tail's script, literal correctness or field ownership.
    x, y, width, height = primary['frameBox']
    if rgb.shape != (height, width, 3):
        raise ValueError('Tail trial received different original pixels')
    prefix_end = max(p['end'] for p in pieces[:start]) * primary['inputWidth'] * width / (primary['timeCount'] * primary['validWidth'])
    tail_begin = min(p['start'] for p in pieces[start:]) * primary['inputWidth'] * width / (primary['timeCount'] * primary['validWidth'])
    proof = dict(state='noOriginalWhiteGap', originalSuffix=suffix, prefixPieceCount=start,
                 ctcPrefixEnd=prefix_end+x, ctcTailBegin=tail_begin+x)
    if not all(math.isfinite(v) for v in [prefix_end, tail_begin]) or not 0 <= prefix_end <= tail_begin <= width:
        return None, proof
    lo, hi = max(0, math.ceil(prefix_end)), min(width-1, math.floor(tail_begin))
    best, opened = None, None
    for column in range(lo, hi+2):
        white = column <= hi and bool((rgb[:, column] == 255).all())
        if white and opened is None:
            opened = column
        elif not white and opened is not None:
            if best is None or column-opened > best[1]-best[0]:
                best = (opened, column)
            opened = None
    if best is None:
        return None, proof
    split = (best[0]+best[1]) // 2
    if not prefix_end < split < width:
        return None, proof
    suffix_rgb = rgb[:, split:]
    nonwhite = np.any(suffix_rgb != 255, axis=2)
    ys, xs = np.nonzero(nonwhite)
    if len(xs) == 0:
        return None, dict(proof, state='noOriginalSuffixInk')
    left, right = max(0, int(xs.min())-2), min(width-split, int(xs.max())+3)
    top, bottom = max(0, int(ys.min())-2), min(height, int(ys.max())+3)
    framed = suffix_rgb[top:bottom, left:right]
    ink = int(np.any(framed != 255, axis=2).sum())
    if ink != int(nonwhite.sum()):
        raise ValueError('Original ASCII tail ink was omitted')
    return framed, dict(proof, state='framedOriginalSuffix',
        whiteGap=[x+best[0], y, best[1]-best[0], height], splitX=x+split,
        frameBox=[x+split+left, y+top, right-left, bottom-top], originalSuffixInkPixels=ink,
        sourcePixelsSHA256=hashlib.sha256(framed.tobytes()).hexdigest())


def selects(original_suffix, expert):
    text, pieces = expert['text'], expert['pieces']
    # Preserve the first bounded Windows-style length check. Insertion/deletion
    # needs separate evidence, not a vocabulary guess or a score comparison.
    return bool(pieces) and len(text) == len(original_suffix) and 2 <= len(text) <= 32 and (
        any('0' <= c <= '9' for c in text) and all(c.isascii() and (c.isalnum() or c in '_-') for c in text) and
        expert['paddingSupported'] and math.isfinite(expert['rejectProbability']) and
        0 <= expert['rejectProbability'] <= .05 and all(math.isfinite(p['confidence']) and .85 <= p['confidence'] <= 1 for p in pieces))


def compose(primary, proof, expert):
    count = proof['prefixPieceCount']
    if not 0 < count < len(primary['pieces']) or proof['originalSuffix'] != ''.join(p['text'] for p in primary['pieces'][count:]):
        raise ValueError('Original suffix provenance changed')
    if expert['text'] != ''.join(p['text'] for p in expert['pieces']):
        raise ValueError('Original ASCII pieces differ from its literal')
    selected = selects(proof['originalSuffix'], expert)
    prefix = ''.join(p['text'] for p in primary['pieces'][:count])
    return dict(selectedText=prefix+expert['text'] if selected else primary['text'],
        selectedEligible=all(p['confidence'] >= .85 for p in primary['pieces'][:count]) if selected else
            bool(primary.get('ownPieceFloor085') and primary.get('paddingSupported')),
        asciiTail=dict(proof, actualCall=True, selected=selected, expert=expert))


class ASCIITailReader:
    def __init__(self, models, infer, ort, np, options):
        self.infer, self.np, self.calls = infer, np, 0
        contract = json.loads((Path(__file__).resolve().parent.parent/'ocr-windows-transfer/protocol.json').read_text())
        pins = [p for p in contract['models'] if p['file'] in ['ascii-rec.onnx', 'ascii-dictionary.json']]
        if len(pins) != 2:
            raise ValueError('Fixed ASCII model inventory changed')
        for pin in pins:
            raw = (models/pin['file']).read_bytes()
            if len(raw) != pin['bytes'] or hashlib.sha256(raw).hexdigest() != pin['sha256']:
                raise ValueError('Fixed ASCII artifact changed')
        self.dictionary = json.loads((models/'ascii-dictionary.json').read_text())
        if len(self.dictionary) != 438:
            raise ValueError('Original ASCII vocabulary changed')
        self.session = ort.InferenceSession(str(models/'ascii-rec.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
        if ({v.name for v in self.session.get_inputs()} != {'x', 'valid_width'} or
                {v.name for v in self.session.get_outputs()} != {'probabilities', 'reject_probability'}):
            raise ValueError('Original ASCII native input/output contract changed')

    def refine(self, rgb, primary):
        fallback = dict(selectedText=primary['text'], selectedEligible=bool(primary.get('ownPieceFloor085') and primary.get('paddingSupported')))
        if primary['state'] != 'recognized':
            return dict(fallback, asciiTail=dict(state='primaryUnsupported', actualCall=False))
        image, proof = tail_frame(rgb, primary)
        if image is None:
            return dict(fallback, asciiTail=dict(proof, actualCall=False))
        if math.floor(48*max(320/48, image.shape[1]/image.shape[0])) > 960:
            return dict(fallback, asciiTail=dict(proof, state='unsupportedSuffixWidth', actualCall=False))
        return compose(primary, proof, self.recognize(image))

    def recognize(self, image):
        """Run the fixed specialist on an already independently framed image."""
        source_hash = hashlib.sha256(image.tobytes()).hexdigest()
        tensor, valid, padded = self.infer.transform(image)
        started = time.monotonic()
        output = dict(zip((v.name for v in self.session.get_outputs()), self.session.run(None,
            {'x': tensor, 'valid_width': self.np.array([valid], dtype=self.np.int64)})))
        self.calls += 1
        probability, reject = output['probabilities'], output['reject_probability']
        if list(reject.shape) != [1] or not math.isfinite(float(reject[0])) or not 0 <= reject[0] <= 1:
            raise ValueError('Original ASCII reject probability changed domain')
        pieces = self.infer.decode(probability, self.dictionary)
        return dict(sourcePixelsSHA256=source_hash, reader='english-v1', text=''.join(p['text'] for p in pieces), pieces=pieces,
            timeCount=int(probability.shape[1]), validWidth=valid, inputWidth=padded,
            paddingSupported=all(p['end']*padded <= valid*probability.shape[1] for p in pieces),
            rejectProbability=float(reject[0]), inputSHA256=hashlib.sha256(tensor.tobytes()).hexdigest(),
            seconds=time.monotonic()-started)
