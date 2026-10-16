#!/usr/bin/env python3
"""Read expected strings only after every fixed recognizer has completed."""
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path


def distance(a, b):
    row = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        following = [i]
        for j, y in enumerate(b, 1):
            following.append(min(following[-1] + 1, row[j] + 1, row[j-1] + (x != y)))
        row = following
    return row[-1]


def contains(outer, inner):
    x, y, w, h = outer
    xx, yy, ww, hh = inner
    return x <= xx and y <= yy and xx+ww <= x+w and yy+hh <= y+h


def intersects(a, b):
    x, y, w, h = a
    xx, yy, ww, hh = b
    return min(x+w, xx+ww) > max(x, xx) and min(y+h, yy+hh) > max(y, yy)


def vision_value(lines, region):
    hits = [line for line in lines if intersects(region, line['box'])]
    if len(hits) != 1:
        return None, None, 'missing' if not hits else 'split-or-conflict'
    line = hits[0]
    if not contains(region, line['box']):
        return None, None, 'outside-physical-region'
    if not line['candidates']:
        return None, None, 'candidate-missing'
    best = line['candidates'][0]
    score = best['confidence']
    if not math.isfinite(score) or not 0 <= score <= 1:
        raise ValueError('Invalid native Vision confidence')
    return best['text'], score, 'single-contained'


def compare(root):
    def load(name):
        return json.loads((root / name).read_text())
    inputs, physical = load('inputs.json'), load('physical.json')
    page_output, crop_output, onnx = load('vision-pages.json'), load('vision-crops.json'), load('onnx.json')
    frames = {(f['id'], f['frame']): f for f in load('frames.json')['frames']}
    oracle = {f['id']: f for f in load('oracle.json')['fields']}
    if (len(oracle) != 144 or len(physical['crops']) != 144 or len(frames) != 288
            or len(page_output['pages']) != 6 or page_output['calls'] != 6
            or len(crop_output['records']) != 576 or crop_output['calls'] != 576
            or len(onnx['records']) != 1152 or onnx['calls'] != 1152):
        raise ValueError('Actual inference inventory is incomplete')
    page_index = {p['page']: p for p in page_output['pages']}
    observed = {}

    def add(identity, frame, reader, text, score, eligible, status):
        key = (identity, frame, reader)
        if key in observed or identity not in oracle:
            raise ValueError('Duplicate or unknown output')
        expected = oracle[identity]
        observed[key] = dict(id=identity, frame=frame, reader=reader, text=text, score=score, status=status,
                             eligible=eligible, exact=text == expected['text'],
                             errors=distance(expected['text'], text or ''), characters=len(expected['text']),
                             font=expected['font'], group=expected['group'])

    for item in physical['crops']:
        text, score, status = vision_value(page_index[item['page']]['lines'], item['box'])
        add(item['id'], 'page', 'vision-documents-page-default', text, score, score is not None and score >= .85, status)
    for row in crop_output['records']:
        key = (row['id'], row['frame'])
        if row['imageSHA256'] != frames[key]['sha256']:
            raise ValueError('Vision did not read the common crop')
        text, score, status = vision_value(row['lines'], [0, 0, row['width'], row['height']])
        add(row['id'], row['frame'], row['reader'], text, score, score is not None and score >= .85, status)
    for row in onnx['records']:
        key = (row['id'], row['frame'])
        if row['imageSHA256'] != frames[key]['sha256'] or row['text'] != ''.join(p['text'] for p in row['pieces']):
            raise ValueError('ONNX source or native decode mismatch')
        score = min((p['confidence'] for p in row['pieces']), default=None)
        eligible = bool(row['pieces']) and row['paddingSupported'] and score is not None and score >= .85 and (
            row['rejectProbability'] is None or row['rejectProbability'] <= .05)
        add(row['id'], row['frame'], row['reader'], row['text'], score, eligible,
            'native-ctc' if row['paddingSupported'] else 'native-ctc-unsupported-padding')
    expected_readers = {('page', 'vision-documents-page-default')} | {
        (frame, reader) for frame in ['physical-interior', 'observed-ink-margin-2'] for reader in [
            'vision-documents-crop-default', 'vision-text-crop-accurate-default',
            'paddle-v6', 'english-v1', 'english-v3', 'japanese-v3']}
    if len(observed) != 144 * len(expected_readers):
        raise ValueError('Incomplete fixed reader inventory')
    for identity in oracle:
        if {(frame, reader) for (i, frame, reader) in observed if i == identity} != expected_readers:
            raise ValueError('Each field must have every fixed reader')
    summary = defaultdict(lambda: dict(total=0, exact=0, characterErrors=0, characters=0,
                                     ownScoreEligibleCorrect=0, ownScoreEligibleWrong=0, missingOrSplit=0,
                                     gainsAgainstPageDocuments=0, lossesAgainstPageDocuments=0))
    for key, row in observed.items():
        baseline = observed[(row['id'], 'page', 'vision-documents-page-default')]
        for font, group in [(row['font'], row['group']), (row['font'], 'ALL'), ('ALL', 'ALL')]:
            total = summary[(row['reader'], row['frame'], font, group)]
            total['total'] += 1
            total['exact'] += row['exact']
            total['characterErrors'] += row['errors']
            total['characters'] += row['characters']
            total['ownScoreEligibleCorrect'] += row['eligible'] and row['exact']
            total['ownScoreEligibleWrong'] += row['eligible'] and not row['exact']
            total['missingOrSplit'] += row['text'] is None
            total['gainsAgainstPageDocuments'] += row['exact'] and not baseline['exact']
            total['lossesAgainstPageDocuments'] += baseline['exact'] and not row['exact']
    totals = [dict(reader=k[0], frame=k[1], font=k[2], group=k[3], **v) for k, v in sorted(summary.items())]
    identities = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in [
        'inputs.json', 'oracle.json', 'physical.json', 'frames.json', 'vision-pages.json', 'vision-crops.json', 'onnx.json']}
    return dict(scope='Recognizer-only discovery; physical regions are generator-provided, not proved application ownership. '
                      'Missing/split/uncontained native lines count as unassigned strings in CER. '
                      'Own scores differ across models and are not calibrated or interchangeable. '
                      'No full-document, real-school, iPhone, additional-model qualification or adoption claim.',
                actualVisionCalls=page_output['calls'] + crop_output['calls'], actualONNXCalls=onnx['calls'],
                maxONNXProcessRSSBytes=onnx['maxRSSBytes'], os=page_output['os'], runtime=onnx['runtime'],
                fields=len(oracle), records=len(observed), fileSHA256=identities, summary=totals)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    result = compare(args.root)
    path = args.root / 'comparison.json'
    if path.exists():
        raise ValueError('Never overwrite the closed comparison')
    path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True) + '\n')
    print('OCR_SCREEN_RECEIPT ' + json.dumps({k: v for k, v in result.items() if k != 'summary'}, sort_keys=True))
    for row in result['summary']:
        print('OCR_SCREEN_SUMMARY ' + json.dumps(row, sort_keys=True))


if __name__ == '__main__':
    main()
