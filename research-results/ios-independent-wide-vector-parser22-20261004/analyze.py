"""Posthoc independently generated vector assertions; never a native input."""
import base64
import gzip
import hashlib
import json
from pathlib import Path
import sys

EXPECTED_SHA = 'efdcb749420be6b000bf172f41102fd6c98b4e6b600dd22d07b41168788ce191'
KEYS = {'baseline/stdout', 'baseline/stderr', 'fixed/stdout', 'fixed/stderr', 'metadata/execution'}
FILES = ['unlabeled.pdf', 'labeled-control.pdf', 'unlabeled-no-unused-font.pdf',
         'labeled-control-no-unused-font.pdf', 'parallel-mismatch.pdf', 'unreadable-body.pdf']


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def unpack(folder):
    streams = {}
    for key in KEYS:
        value = json.loads((folder / (key.replace('/', '-') + '.raw.json')).read_text())
        assert value['key'] == key and value['encoding'] == 'gzip-base64'
        raw = gzip.decompress(base64.b64decode(value['data'], validate=True))
        assert len(raw) == value['bytes'] and sha(raw) == value['sha256']
        streams[key] = raw
    assert set(streams) == KEYS
    return streams


def literal(analysis, expected):
    observed = {}
    for value in analysis['lessons']:
        key = (value['className'], value['weekday'], value['period'])
        observed.setdefault(key, []).append({field: value['names'][field] for field in ['subject', 'teacher', 'room']})
    keys = {(v['className'], v['weekday'], v['period']) for v in expected['slots']}
    assert len(keys) == len(expected['slots']) == 680
    mismatches = []
    for slot in expected['slots']:
        actual = observed.get((slot['className'], slot['weekday'], slot['period']), [])
        if actual != slot['lessons']:
            mismatches.append({**slot, 'actualLessons': actual})
    extra = sorted(set(observed) - keys)
    metadata = analysis['schoolYear'] == expected['schoolYear'] and analysis['term'] == expected['term']
    classes = set(v['className'] for v in analysis['lessons']) == set(expected['classes'])
    return {'assertionOnly': True, 'literalSlotsAssessed': 680, 'literalSlotsMatched': 680 - len(mismatches),
            'mismatches': mismatches, 'extraSlotKeys': extra, 'yearAndTermMatch': metadata, 'classesMatch': classes,
            'all680LiteralMatch': not mismatches and not extra and metadata and classes}


def analyze(streams, expected_raw):
    assert set(streams) == KEYS and sha(expected_raw) == EXPECTED_SHA
    expected = json.loads(expected_raw)
    execution = json.loads(streams['metadata/execution'])
    assert execution['nativeExecutionComplete'] is True
    assert [v['file'] for v in execution['sourceReceipt']['nativeInputs']] == FILES
    result = {'sourceCommit': execution['sourceCommit'], 'runId': execution['runId'], 'attempt': execution['attempt'],
              'externalLogReadbackComplete': True, 'keys': sorted(streams), 'rawStreams': [], 'phases': {},
              'expectedSHA256': EXPECTED_SHA, 'ocrRequests': 0, 'modelInvocations': 0,
              'limits': 'Independent generated vector fixtures only; no physical-device, persistence/manual-UI or OCR/model quality qualification. Blank slots compare absence only after complete native Reader/actual parser.'}
    for key, raw in sorted(streams.items()):
        result['rawStreams'].append({'key': key, 'bytes': len(raw), 'sha256': sha(raw)})
    for mode in ['baseline', 'fixed']:
        raw = streams[mode + '/stdout']
        phase = execution['phases'][mode]
        assert len(raw) == phase['originalRawBytes'] and sha(raw) == phase['originalRawSHA256']
        assert phase['nativeExitCode'] == 0 and phase['parsingTruncated'] is False
        values = [json.loads(line) for line in raw.splitlines() if line.strip()]
        environments = [v for v in values if v.get('type') == 'environment']
        summaries = [v for v in values if v.get('type') == 'summary']
        cases = [v for v in values if v.get('type') == 'fixture']
        files = FILES[:4] if mode == 'baseline' else FILES
        assert len(environments) == len(summaries) == 1 and [v['file'] for v in cases] == files
        assert len(values) == len(cases) + 2
        summary = summaries[0]
        assert summary['plannedReaderCalls'] == summary['recordedCases'] == len(files)
        assert summary['attemptedReaderCalls'] == sum(v['readerCallStarted'] is True for v in cases)
        assert summary['readReturned'] == sum(v['readReturned'] is True for v in cases)
        assert summary['analysesReturned'] == sum(v['analysisReturned'] is True for v in cases)
        rows = []
        for case in cases:
            pin = next(v for v in execution['sourceReceipt']['nativeInputs'] if v['file'] == case['file'])
            assert case['pdfSHA256'] == pin['sha256'] and case['pdfBytes'] == pin['bytes']
            assert case['ocrRequests'] == case['modelInvocations'] == 0
            row = {k: case[k] for k in ['file', 'pdfSHA256', 'pdfBytes', 'readerOnly', 'readerCallStarted', 'readReturned', 'analysisReturned', 'capture', 'seconds']}
            for key in ['route', 'strictReturned', 'failureStage', 'failure', 'strictError', 'glyphCount', 'ruleCount',
                        'engineState', 'engineErrors', 'validatorCanAdopt', 'validatorErrors', 'builderRequiredSlots',
                        'builderInputErrors', 'structureState', 'structureErrors', 'structureProposalAdoptionAssessed']:
                if key in case:
                    row[key] = case[key]
            if 'layouts' in case:
                assert sum(len(v['glyphs']) for v in case['layouts']) == case['glyphCount']
                assert sum(len(v['lines']) for v in case['layouts']) == case['ruleCount']
                row['actualPages'] = [{'glyphs': len(v['glyphs']), 'rules': len(v['lines']), 'width': v['width'], 'height': v['height']} for v in case['layouts']]
            if case['analysisReturned']:
                assert 'actualAnalysis' in case and case['capture']['complete'] is True
                independently = literal(case['actualAnalysis'], expected)
                row['independentLiteralAssertion'] = independently
                if 'literalAssertion' in case:
                    assert independently['literalSlotsMatched'] == case['literalAssertion']['literalSlotsMatched']
                    assert independently['all680LiteralMatch'] == case['literalAssertion']['all680LiteralMatch']
            rows.append(row)
        result['phases'][mode] = {'summary': summary, 'cases': rows, 'nativeReceipt': phase}
    return result


if __name__ == '__main__':
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent
    result = analyze(unpack(folder), (folder / 'expected.json').read_bytes())
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode()
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_bytes(encoded)
    else:
        sys.stdout.buffer.write(encoded)
