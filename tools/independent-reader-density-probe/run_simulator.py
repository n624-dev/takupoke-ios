"""Independent current-source phase: exactly four fixed pipeline calls; no baseline rerun."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "independent-reader-probe"))
import log_transport

MAX_RAW_BYTES = 64 * 1024 * 1024


EXPECTED_STREAMS = {'fixed/stdout', 'fixed/stderr', 'metadata/execution'}


def restore_complete(log):
    restored = log_transport.restore(log)
    assert set(restored) == EXPECTED_STREAMS, 'Missing or extra current-phase streams; no transport completeness claim'
    return restored


def failure_class(value):
    error = value.get('failure')
    if not isinstance(error, dict):
        return None
    # Production PDFParseError.Code is unreadable/unsupported/ambiguous/
    # limit/cancelled/storage. Only these two source-shape failures establish
    # semantic refusal here; IO, bounds, cancellation and timeouts are unassessed.
    if value.get('analysisReturned') is False and error.get('type') == 'PDFParseError' and error.get('code') in {'unsupported', 'ambiguous'}:
        return 'semanticRefusal'
    if error.get('domain') in {'SourceOnlyRulesNotComplete', 'NativeValidatorRejected'}:
        return 'rulesIncomplete'
    if error.get('domain') == 'StructureProposalNotAssessed':
        return 'structureUnassessed'
    return 'executionOrUnassessed'


def receipt(raw, planned_files):
    values, invalid = [], 0
    for line in raw.splitlines():
        if not line.strip():
            continue
        try:
            value = json.loads(line)
            if not isinstance(value, dict):
                raise ValueError('Record must be an object')
            values.append(value)
        except ValueError:
            invalid += 1
    fixtures = [v for v in values if v.get('type') == 'fixture']
    actual_files = [v.get('file') for v in fixtures]
    positive = [v for v in fixtures if v.get('file') in planned_files[:4]]
    negative = [v for v in fixtures if v.get('file') in planned_files[4:]]
    return {'rawSHA256': hashlib.sha256(raw).hexdigest(), 'rawBytes': len(raw),
            'recordedFiles': actual_files, 'plannedFilesWithoutRecord': [v for v in planned_files if v not in actual_files],
            'attemptedReaderCalls': sum(v.get('readerCallStarted') is True for v in fixtures),
            'readReturned': sum(v.get('readReturned') is True for v in fixtures),
            'analysesReturned': sum(v.get('analysisReturned') is True for v in fixtures),
            'sourceFailures': sum('failure' in v for v in fixtures),
            'failureClasses': {name: sum(failure_class(v) == name for v in fixtures) for name in ['semanticRefusal', 'rulesIncomplete', 'structureUnassessed', 'executionOrUnassessed']},
            'positiveAll680LiteralMatches': sum(v.get('literalAssertion', {}).get('all680LiteralMatch') is True for v in positive),
            'positiveLiteralMismatches': sum(v.get('literalAssertion', {}).get('all680LiteralMatch') is False for v in positive),
            'positiveLiteralUnassessed': sum(v.get('analysisReturned') is True and not isinstance(v.get('literalAssertion', {}).get('all680LiteralMatch'), bool) for v in positive),
            'negativeSemanticRefusals': sum(failure_class(v) == 'semanticRefusal' for v in negative),
            'negativeRulesIncomplete': sum(failure_class(v) == 'rulesIncomplete' for v in negative),
            'negativeStructureUnassessed': sum(failure_class(v) == 'structureUnassessed' for v in negative),
            'negativeExecutionOrUnassessed': sum(failure_class(v) == 'executionOrUnassessed' for v in negative),
            'negativeAnalysesReturned': sum(v.get('analysisReturned') is True for v in negative),
            'nonJSONOrIncompleteLines': invalid,
            'transportComplete': actual_files == planned_files and invalid == 0 and len([v for v in values if v.get('type') == 'summary']) == 1,
            'semanticResultsSeparateFromTransport': True}


def main(work):
    assert work.is_dir() and (work / '.independent-reader-owned').is_file()
    inputs = json.loads((work / 'prepared/native-inputs.json').read_text())
    files = [v['file'] for v in inputs['files']]
    assert len(files) == 4 and len(set(files)) == 4
    expected_sha = json.loads((work / 'fixtures/manifest.json').read_text())['expectedSha256']
    record = {'scope': 'Actual iOS simulator generated vector PDFs; no OCR/models, physical iPhone, persistence or quality qualification',
              'runId': os.environ['GITHUB_RUN_ID'], 'attempt': os.environ['GITHUB_RUN_ATTEMPT'],
              'sourceCommit': os.environ['GITHUB_SHA'], 'steps': [], 'phases': {}, 'ocrRequests': 0, 'modelInvocations': 0}
    udid, cleanup_error, exit_status = None, None, 1

    def command(argv, timeout=180):
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        record['steps'].append({'argv': argv, 'exitCode': p.returncode, 'stdout': p.stdout[-12000:], 'stderr': p.stderr[-8000:]})
        if p.returncode:
            raise RuntimeError('Command failed: ' + ' '.join(argv[:3]))
        return p.stdout

    try:
        record['hostOS'] = command(['sw_vers'])
        record['hostArchitecture'] = command(['uname', '-m']).strip()
        record['xcode'] = command(['xcodebuild', '-version'])
        record['simulatorSDK'] = command(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version']).strip()
        runtimes = json.loads(command(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
        available = [r for r in runtimes if r.get('isAvailable') and r.get('version', '').split('.')[0] == '27' and 'iOS' in r['name']]
        assert available, 'No real iOS27 simulator runtime'
        runtime = max(available, key=lambda r: tuple(map(int, r['version'].split('.'))))
        record['simulatorRuntime'] = runtime
        udid = command(['xcrun', 'simctl', 'create', f"IndependentReader-{record['runId']}-{record['attempt']}",
                        'com.apple.CoreSimulator.SimDeviceType.iPhone-14', runtime['identifier']]).strip()
        assert re.fullmatch(r'[0-9A-Fa-f-]{36}', udid)
        (work / 'owned-simulator.json').write_text(json.dumps({'udid': udid, 'runId': record['runId'], 'attempt': record['attempt']}) + '\n')
        command(['xcrun', 'simctl', 'boot', udid])
        command(['xcrun', 'simctl', 'bootstatus', udid, '-b'], timeout=240)
        for mode, binary in [('fixed', 'IndependentReaderFixed')]:
            started = time.monotonic()
            paths = [work / f'native.{mode}.{stream}' for stream in ['stdout', 'stderr']]
            phase = record['phases'][mode] = {'plannedReaderCalls': 4}
            with paths[0].open('wb') as out, paths[1].open('wb') as err:
                p = subprocess.Popen(['xcrun', 'simctl', 'spawn', udid, str(work / binary), mode,
                                      str(work / 'prepared'), str(work / 'fixtures'), str(work / 'fixtures/expected.json'), expected_sha], stdout=out, stderr=err)
                try:
                    while True:
                        if sum(path.stat().st_size for path in paths) > MAX_RAW_BYTES:
                            raise RuntimeError('Bounded native transport exceeded')
                        remaining = 1200 - (time.monotonic() - started)
                        if remaining <= 0:
                            raise subprocess.TimeoutExpired(p.args, 1200)
                        try:
                            status = p.wait(timeout=min(0.5, remaining))
                            break
                        except subprocess.TimeoutExpired:
                            continue
                except Exception:
                    p.terminate()
                    try:
                        p.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        p.kill(); p.wait(timeout=15)
                    phase['nativeExitCode'] = p.returncode
                    raise
            phase.update(receipt(paths[0].read_bytes(), files))
            phase['nativeExitCode'] = status
            phase['nativeSeconds'] = time.monotonic() - started
            assert status == 0 and phase['transportComplete'], 'Incomplete native transport; missing results unassessed'
        record['nativeExecutionComplete'] = True
        exit_status = 0
    except Exception as error:
        record['executionError'] = repr(error)
        record['nativeExecutionComplete'] = False
    finally:
        for mode in ['fixed']:
            path = work / f'native.{mode}.stdout'
            if path.is_file():
                raw = path.read_bytes()
                phase = record['phases'].setdefault(mode, {})
                phase.update(receipt(raw[:MAX_RAW_BYTES], files))
                phase['originalRawSHA256'] = hashlib.sha256(raw).hexdigest()
                phase['originalRawBytes'] = len(raw)
                phase['parsingTruncated'] = len(raw) > MAX_RAW_BYTES
        if udid:
            try:
                command(['xcrun', 'simctl', 'shutdown', udid], timeout=90)
            except Exception as error:
                record['shutdownError'] = repr(error)
            try:
                command(['xcrun', 'simctl', 'delete', udid], timeout=90)
            except Exception as error:
                cleanup_error = repr(error); record['cleanupError'] = cleanup_error
        for mode in ['fixed']:
            for stream in ['stdout', 'stderr']:
                path = work / f'native.{mode}.{stream}'
                if path.is_file():
                    raw = path.read_bytes()
                    lines = list(log_transport.encode(raw, mode + '/' + stream))
                    assert log_transport.restore('\n'.join(lines))[mode + '/' + stream] == raw
                    for line in lines:
                        print(line, flush=True)
        record['sourceReceipt'] = json.loads((work / 'prepared/source-receipt.json').read_text())
        record['generatedFixtureManifest'] = json.loads((work / 'fixtures/manifest.json').read_text())
        execution = (json.dumps(record, ensure_ascii=False, indent=2) + '\n').encode()
        for line in log_transport.encode(execution, 'metadata/execution'):
            print(line, flush=True)
        print('IOS_INDEPENDENT_READER_SUMMARY ' + json.dumps({'runId': record['runId'], 'sourceCommit': record['sourceCommit'],
            'nativeExecutionComplete': record['nativeExecutionComplete'], 'phases': record['phases'], 'ocrRequests': 0, 'modelInvocations': 0}), flush=True)
        (work / 'execution.json').write_bytes(execution)
    return 1 if cleanup_error else exit_status


if __name__ == '__main__':
    sys.exit(main(Path(sys.argv[1]).resolve()))
