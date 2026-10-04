"""Posthoc operator counters on independently generated PDFs, not native OCR."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import sys
import fitz


def tokens(data):
    result, i = [], 0
    whitespace = b'\x00\t\n\f\r '
    delimiters = b'()<>[]{}/%'
    while i < len(data):
        if data[i] in whitespace:
            i += 1; continue
        if data[i] == ord('%'):
            while i < len(data) and data[i] not in b'\r\n': i += 1
            continue
        if data[i] == ord('('):
            i += 1; depth = 1
            while depth:
                assert i < len(data)
                if data[i] == ord('\\'): i += 2; continue
                if data[i] == ord('('): depth += 1
                elif data[i] == ord(')'): depth -= 1
                i += 1
            continue
        if data[i] == ord('<') and data[i:i+2] != b'<<':
            end = data.index(b'>', i+1); i = end+1; continue
        if data[i] == ord('/'):
            i += 1
            while i < len(data) and data[i] not in whitespace + delimiters: i += 1
            continue
        if data[i] in delimiters:
            i += 1; continue
        start = i
        while i < len(data) and data[i] not in whitespace + delimiters: i += 1
        result.append(data[start:i].decode('ascii'))
    return result


def counters(pdf):
    with fitz.open(pdf) as document:
        assert len(document) == 1
        streams = [document.xref_stream(xref) for xref in document[0].get_contents()]
    content = b'\n'.join(streams)
    operators = [token for token in tokens(content) if re.fullmatch(r'[A-Za-z][A-Za-z0-9*]*|[\'\"]', token)]
    counts = Counter(operators)
    paths, maximum_paths, maximum_points, stack, maximum_stack, segments = [], 0, 0, 0, 0, 0
    paint = {'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*'}
    for op in operators:
        if op == 'q': stack += 1; maximum_stack = max(maximum_stack, stack)
        elif op == 'Q': stack -= 1; assert stack >= 0
        elif op == 'n': paths = []
        elif op == 'm': paths.append(1)
        elif op == 're': paths.append(5)
        elif op == 'l': assert paths; paths[-1] += 1
        elif op == 'h': assert paths; paths[-1] += 1
        elif op in paint:
            if op in {'s', 'b', 'b*'} and paths: paths[-1] += 1
            if op in {'S', 's', 'B', 'B*', 'b', 'b*'}:
                segments += sum(max(0, points-1) for points in paths)
            paths = []
        maximum_paths = max(maximum_paths, len(paths))
        maximum_points = max(maximum_points, max(paths, default=0))
    assert stack == 0
    return {'contentStreams': len(streams), 'uncompressedContentBytes': len(content), 'contentSHA256': hashlib.sha256(content).hexdigest(),
            'operatorCounts': dict(sorted(counts.items())), 'allOperatorUpperBoundForRegisteredCallbacks': len(operators),
            'maximumGraphicsStack': maximum_stack, 'maximumSimultaneousPaths': maximum_paths,
            'maximumPointsPerPath': maximum_points, 'strokeSegmentsUpperBoundForRules': segments}


if __name__ == '__main__':
    fixtures, source, evidence = map(Path, sys.argv[1:4])
    assert hashlib.sha256((source/'Takupoke/PDFPathReader.swift').read_bytes()).hexdigest() == '8e2677f3e0b1eca10f5212b437a5348c6441fa1fc57af03965efc09c036c7d4d', 'Pinned old production guard source changed'
    derived = json.loads(evidence.read_text())
    rows = []
    for case in derived['phases']['fixed']['cases']:
        path = fixtures / case['file']
        raw = path.read_bytes(); assert hashlib.sha256(raw).hexdigest() == case['pdfSHA256']
        counted = counters(path)
        # These four production guards cannot trigger on this content: the
        # callback count is at most all parsed operators, rules are at most
        # stroke segments (no thin fills), paths/points/stacks are bounded here.
        bounded = counted['allOperatorUpperBoundForRegisteredCallbacks'] < 1000000 and counted['maximumGraphicsStack'] < 64 and counted['maximumSimultaneousPaths'] <= 10000 and counted['maximumPointsPerPath'] <= 10000 and counted['strokeSegmentsUpperBoundForRules'] < 100000
        row = {'file': case['file'], 'pdfSHA256': case['pdfSHA256'], **counted,
               'otherPathReaderLimitGuardsUnreachableFromThisContent': bounded,
               'nativeFailureCode': case.get('failure', {}).get('code'), 'nativeFailureStage': case.get('failureStage'),
               'nativeReaderReturned': case['readReturned'], 'nativeCaptureComplete': case['capture']['complete']}
        glyphs = sum(page.get('glyphs', 0) for page in case['capture']['pages'])
        if case.get('failure', {}).get('code') == 'limit':
            assert bounded and not any(counted['operatorCounts'].get(op, 0) for op in ['f', 'F', 'f*', 'B', 'B*', 'b', 'b*'])
            row['limitOriginBySourceAndGuardElimination'] = 'PDFPathReader.consumePaintWork maximumPaintWork=1000000; native does not emit the exact counter'
            row['nativePartialGlyphCount'] = glyphs
            row['conditionalDisjointStrokeCollisionCharges'] = glyphs * counted['strokeSegmentsUpperBoundForRules']
            row['conditionalAllDisjointPaintWork'] = (glyphs+3) * counted['strokeSegmentsUpperBoundForRules']
            row['conditionalDescription'] = 'Full-page total if every stroke and glyph bbox is disjoint; not an emitted native operation counter. Native partial glyph boxes were hashed/count-recorded but not exported.'
        rows.append(row)
    result = {'method': 'Static lexical counters on frozen independently generated PDF content + exact current source guard tracing; no production change/native request',
              'sourceCommit': derived['sourceCommit'], 'sourcePath': 'Takupoke/PDFPathReader.swift',
              'sourceSHA256': hashlib.sha256((source/'Takupoke/PDFPathReader.swift').read_bytes()).hexdigest(),
              'paintLimitUnchanged': 1000000, 'cases': rows,
              'limits': 'Actual native paintWork/operations counters were not emitted. Guard origin is static elimination plus actual .limit at paths; future source fix must preserve exact inclusive bbox/pad, cancellation and caps.'}
    Path(sys.argv[4]).write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'cases': [{k: row[k] for k in ['file', 'allOperatorUpperBoundForRegisteredCallbacks', 'maximumGraphicsStack', 'maximumSimultaneousPaths', 'maximumPointsPerPath', 'strokeSegmentsUpperBoundForRules', 'nativeFailureCode']} for row in rows]}, indent=2))
