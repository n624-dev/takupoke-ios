#!/usr/bin/env python3
"""Assertion-only comparison, executed after the oracle-free reader has exited."""
import argparse
import hashlib
import json
from pathlib import Path


def contains(outer, inner):
    x, y, w, h = outer
    a, b, c, d = inner
    return x <= a and y <= b and a+c <= x+w and b+d <= y+h


def cell_key(target):
    return target['className'], target['day'], target['period']


def scale(box, sx, sy):
    return [box[0]*sx, box[1]*sy, box[2]*sx, box[3]*sy]


def intersects(a, b):
    return max(a[0], b[0]) < min(a[0]+a[2], b[0]+b[2]) and max(a[1], b[1]) < min(a[1]+a[3], b[1]+b[3])


def assignment(fields, cells, records):
    # The oracle is used only now, to assert semantic ownership of the actual
    # independently acquired closed cells and original line boxes.
    expected_cells = {}
    for field in fields:
        expected_cells.setdefault(cell_key(field['target']), []).append(field)
    owners = []
    for cell in cells:
        keys = [key for key, values in expected_cells.items() if all(contains(cell, f['box']) for f in values)]
        owners.append(keys[0] if len(keys) == 1 else None)
    matched = [[] for _ in fields]
    unassigned, unassigned_body = 0, 0
    for record in records:
        box = record['box']
        physical = [index for index, cell in enumerate(cells) if contains(cell, box)]
        if len(physical) != 1 or owners[physical[0]] is None:
            unassigned += 1
            unassigned_body += any(intersects(box, field['cell']) for field in fields)
            continue
        key = owners[physical[0]]
        candidates = sorted([(index, f) for index, f in enumerate(fields) if cell_key(f['target']) == key], key=lambda item: item[1]['box'][1])
        accepted = []
        for ordinal, (index, field) in enumerate(candidates):
            cell = field['cell']
            top = cell[1] if ordinal == 0 else (candidates[ordinal-1][1]['box'][1]+candidates[ordinal-1][1]['box'][3]+field['box'][1])/2
            bottom = cell[1]+cell[3] if ordinal+1 == len(candidates) else (field['box'][1]+field['box'][3]+candidates[ordinal+1][1]['box'][1])/2
            if contains([cell[0], top, cell[2], bottom-top], box):
                accepted.append(index)
        if len(accepted) != 1:
            unassigned += 1
            unassigned_body += any(intersects(box, field['cell']) for field in fields)
            continue
        matched[accepted[0]].append(record)
    outcome = []
    for field, parts in zip(fields, matched):
        parts.sort(key=lambda r: (r['box'][1], r['box'][0], r['order']))
        literal = ''.join(p['text'] or '' for p in parts)
        exact = bool(parts) and all(p['text'] for p in parts) and literal.encode() == field['text'].encode()
        eligible = bool(parts) and all(p['eligible'] and p['text'] for p in parts)
        outcome.append(dict(target=field['target'], exact=exact, eligible=eligible,
                            predicted=literal, expected=field['text'], contributingRecords=len(parts)))
    return outcome, unassigned, unassigned_body


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--acquisition', type=Path, required=True)
    parser.add_argument('--oracle', type=Path, required=True)
    args = parser.parse_args()
    root = args.acquisition
    # The recognition process is already finished; no model is imported here.
    result_bytes = (root / 'recognized.json').read_bytes()
    recognition = json.loads(result_bytes)
    acquisition = json.loads((root / 'acquisition.json').read_text())
    variant, acquired = acquisition['variant'], acquisition['documents']
    if variant != recognition['variant']:
        raise ValueError('Original acquisition condition differs from the completed recognition')
    oracle = json.loads(args.oracle.read_text())['documents']
    if len(acquired) != len(oracle) or len(recognition['documents']) != len(acquired):
        raise ValueError('Completed source inventory differs from the assertion cohort')
    summaries, all_pairs = [], []
    for document, predicted, expected in zip(acquired, recognition['documents'], oracle):
        if (document['id'] != predicted['id'] or document['id'] != expected['id'] or
                predicted['sourcePDFSHA256'] != document['sourcePDFSHA256'] or expected['sourcePDFSHA256'] != document['sourcePDFSHA256']):
            raise ValueError('Actual source identities changed before comparison')
        sx, sy = document['width']/expected['width'], document['height']/expected['height']
        fields = [dict(r, box=scale(r['box'], sx, sy), cell=scale(r['cell'], sx, sy)) for r in expected['records'] if r['category'] == 'body']
        capture_bytes = (root / document['nativeCapture']).read_bytes()
        if hashlib.sha256(capture_bytes).hexdigest() != document['nativeCaptureSHA256']:
            raise ValueError('Original native capture changed before comparison')
        capture = json.loads(capture_bytes)
        vision = []
        for line in capture['lines']:
            candidate = line['candidates'][0]
            box = candidate.get('observationRange')
            if box is None:
                raise ValueError('Original Vision observation range is missing')
            vision.append(dict(box=[box['x'], box['y'], box['width'], box['height']], order=line['nativeOrder'],
                               text=candidate['text'], eligible=candidate['confidence'] >= .85))
        paddle = [dict(box=r['inkBox'], order=r['index'], text=r['text'],
                       eligible=r.get('ownPieceFloor085', False) and r.get('paddingSupported', False)) for r in predicted['records']]
        base, base_extra, base_body_extra = assignment(fields, document['cells'], vision)
        trial, trial_extra, trial_body_extra = assignment(fields, document['cells'], paddle)
        row = dict(id=document['id'], variant=variant, fields=len(fields), visionExact=sum(r['exact'] for r in base),
                   paddleExact=sum(r['exact'] for r in trial), gains=sum(not a['exact'] and b['exact'] for a, b in zip(base, trial)),
                   losses=sum(a['exact'] and not b['exact'] for a, b in zip(base, trial)),
                   visionOwnScoreEligibleWrong=sum(r['eligible'] and not r['exact'] for r in base),
                   paddleOwnPiecesEligibleWrong=sum(r['eligible'] and not r['exact'] for r in trial),
                   visionUnassignedIncludingHeaders=base_extra, paddleUnassignedIncludingHeaders=trial_extra,
                   visionUnassignedInBody=base_body_extra, paddleUnassignedInBody=trial_body_extra,
                   visionAllDeclaredBodyExactAndNoUnassignedRegion=all(r['exact'] for r in base) and base_body_extra == 0,
                   paddleAllDeclaredBodyExactAndNoUnassignedRegion=all(r['exact'] for r in trial) and trial_body_extra == 0,
                   actualPhysicalCells=len(document['cells']), originalInkCoverage=predicted['coverage'])
        summaries.append(row)
        all_pairs.append(dict(id=document['id'], vision=base, paddle=trial))
        print('FULL_SOURCE_GEOMETRY ' + json.dumps(dict(variant=variant, **document), sort_keys=True), flush=True)
        for field, original, candidate in zip(fields, base, trial):
            print('FULL_SOURCE_FIELD ' + json.dumps(dict(id=document['id'], variant=variant, field=field,
                  vision=original, paddle=candidate), ensure_ascii=False, sort_keys=True), flush=True)
        print('FULL_SOURCE_SUMMARY ' + json.dumps(row, sort_keys=True), flush=True)
    if sum(r['fields'] for r in summaries) != 444:
        raise ValueError('Incomplete required assertion fields')
    receipt = dict(study='ios-ocr-full-source-discovery-v2', variant=variant, documents=len(summaries), requiredBodyFields=444,
                   actualONNXCalls=recognition['actualCalls'], actualVisionCalls=6,
                   recognizedFileSHA256=hashlib.sha256(result_bytes).hexdigest(),
                   scope='Initial declared whole-source acquisition/body ownership discovery. Source-only raw pixels; not formal Builder/Validator adoption, held-out qualification, app change or physical iPhone execution. Own scores are not calibrated or interchangeable.')
    (root / 'comparison.json').write_text(json.dumps(dict(receipt=receipt, summaries=summaries, pairs=all_pairs), ensure_ascii=False, sort_keys=True)+'\n')
    print('FULL_SOURCE_RECEIPT ' + json.dumps(receipt, sort_keys=True), flush=True)


if __name__ == '__main__':
    main()
