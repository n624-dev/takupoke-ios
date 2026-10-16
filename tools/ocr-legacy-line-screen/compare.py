#!/usr/bin/env python3
"""Post-recognition comparison only; no oracle access in the native reader."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re


def evaluate(frames, oracle, capture):
    identities = {f'p{page}-f{field}' for page in range(1, 7) for field in range(1, 25)}
    selected = [f for f in frames if f['frame'] == 'observed-ink-margin-2']
    by_id = {f['id']: f for f in selected}
    expected = {f['id']: f for f in oracle}
    if (len(frames) != 288 or len(selected) != 144 or len(by_id) != 144 or set(by_id) != identities or
            len(oracle) != 144 or set(expected) != identities or capture['actualCalls'] != 288 or
            len(capture['records']) != 288):
        raise ValueError('Incomplete fixed input or native call inventory')
    seen, observations, source = set(), {}, {}
    for row in capture['records']:
        identity, factor = row['id'], row['factor']
        if identity not in identities or type(factor) is not int or factor not in [1, 4] or (identity, factor) in seen:
            raise ValueError('Unknown or duplicate native output')
        seen.add((identity, factor))
        if (row['sourceImageSHA256'] != by_id[identity]['sha256'] or row['revision'] != 3 or
                row['languages'] != ['ja-JP', 'en-US'] or row['usesLanguageCorrection'] is not False or
                row['everyScaledPixelVerified'] is not True or any(type(row[k]) is not int or not 1 <= row[k] <= 2048
                    for k in ['sourceWidth', 'sourceHeight']) or
                row['inputWidth'] != factor*row['sourceWidth'] or row['inputHeight'] != factor*row['sourceHeight']):
            raise ValueError('Native source, configuration or input transform changed')
        for key in ['sourceImageSHA256', 'sourceRGBAHash', 'inputRGBAHash']:
            if not isinstance(row[key], str) or re.fullmatch('[0-9a-f]{64}', row[key]) is None:
                raise ValueError('Invalid original pixel hash')
        if factor == 1 and row['inputRGBAHash'] != row['sourceRGBAHash']:
            raise ValueError('The original condition changed its actual pixels')
        identity_source = (row['sourceRGBAHash'], row['sourceWidth'], row['sourceHeight'])
        if identity in source and source[identity] != identity_source:
            raise ValueError('The two conditions received different originals')
        source[identity] = identity_source
        if not math.isfinite(row['seconds']) or row['seconds'] < 0:
            raise ValueError('Invalid native call duration')
        text, confidence, status = None, None, row['state']
        if row['state'] == 'nativeError':
            if 'observations' in row or not isinstance(row['errorDomain'], str) or type(row['errorCode']) is not int:
                raise ValueError('An API error was converted into recognized output')
        elif row['state'] == 'recognized':
            if type(row['characterMappingErrors']) is not int or row['characterMappingErrors'] < 0:
                raise ValueError('Invalid native character mapping error inventory')
            hits = row['observations']
            status = 'missing' if not hits else 'split-or-conflict'
            if len(hits) == 1 and hits[0]['candidates']:
                x, y, w, h = hits[0]['sourceBox']
                if not all(math.isfinite(v) for v in [x, y, w, h]) or w <= 0 or h <= 0:
                    raise ValueError('Invalid native observation geometry')
                if x >= 0 and y >= 0 and x+w <= row['sourceWidth'] and y+h <= row['sourceHeight']:
                    first = hits[0]['candidates'][0]
                    text, confidence, status = first['text'], first['confidence'], 'single-contained'
                    if not isinstance(text, str) or not math.isfinite(confidence) or not 0 <= confidence <= 1:
                        raise ValueError('Invalid original native candidate')
                else:
                    status = 'outside-original-frame'
        else:
            raise ValueError('Unknown native result state')
        observations[(identity, factor)] = dict(id=identity, factor=factor, text=text, confidence=confidence,
            exact=text == expected[identity]['text'], eligible=confidence is not None and confidence >= .85,
            status=status, nativeGeometryErrors=row.get('characterMappingErrors', 0),
            font=expected[identity]['font'], group=expected[identity]['group'])
    if seen != {(identity, factor) for identity in identities for factor in [1, 4]}:
        raise ValueError('A native condition is missing')
    summaries = []
    for factor in [1, 4]:
        rows = [r for r in observations.values() if r['factor'] == factor]
        summaries.append(dict(factor=factor, fields=144, exact=sum(r['exact'] for r in rows),
            ownNative085Exact=sum(r['exact'] and r['eligible'] for r in rows),
            ownNative085Wrong=sum(not r['exact'] and r['eligible'] for r in rows),
            nativeErrors=sum(r['status'] == 'nativeError' for r in rows),
            nativeGeometryErrors=sum(r['nativeGeometryErrors'] for r in rows),
            missingSplitOrOutside=sum(r['status'] not in ['nativeError', 'single-contained'] for r in rows)))
    changes = dict(gains=sum(not observations[(i, 1)]['exact'] and observations[(i, 4)]['exact'] for i in identities),
                   losses=sum(observations[(i, 1)]['exact'] and not observations[(i, 4)]['exact'] for i in identities))
    return dict(study='ios-ocr-legacy-line-screen-v1', actualNativeCalls=288, summaries=summaries, paired=changes,
                fields=list(observations.values()), originalPhysicalOwnershipQualified=False,
                applicationChanged=False, physicalIPhoneExecution=False)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('root', type=Path); args = parser.parse_args()
    def load(name):
        return json.loads((args.root/name).read_text())
    capture = load('legacy-lines.json')
    result = evaluate(load('frames.json')['frames'], load('oracle.json')['fields'], capture)
    for row in capture['records']:
        print('LEGACY_LINE_NATIVE '+json.dumps(row, ensure_ascii=False, sort_keys=True), flush=True)
    for row in result['fields']:
        print('LEGACY_LINE_FIELD '+json.dumps(row, ensure_ascii=False, sort_keys=True), flush=True)
    receipt = {k: v for k, v in result.items() if k != 'fields'}
    receipt['nativeFileSHA256'] = hashlib.sha256((args.root/'legacy-lines.json').read_bytes()).hexdigest()
    print('LEGACY_LINE_RECEIPT '+json.dumps(receipt, sort_keys=True), flush=True)
    print('::notice title=Fictional legacy Vision line screen::'+json.dumps(receipt, sort_keys=True), flush=True)
    if any(row['nativeErrors'] or row['nativeGeometryErrors'] for row in result['summaries']):
        raise ValueError('Native API errors remain failures; all conditions were recorded before failing')


if __name__ == '__main__':
    main()
