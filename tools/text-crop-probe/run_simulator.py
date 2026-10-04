"""One owned iOS simulator, two overlapping crop text OCR requests; no document OCR."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

work = Path(sys.argv[1]).resolve()
assert work.is_dir() and (work / '.text-crop-owned').is_file()
record = {'scope':'Actual iOS simulator one-page two-region text OCR component comparison; not physical iPhone or formal recovery qualification',
          'runId':os.environ['GITHUB_RUN_ID'], 'attempt':os.environ['GITHUB_RUN_ATTEMPT'], 'sourceCommit':os.environ['GITHUB_SHA'], 'steps':[]}
udid = None
cleanup_error = None
exit_status = 1
started = None
MAX_RAW_BYTES = 64*1024*1024

def command(argv, timeout=180):
    p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    record['steps'].append({'argv':argv,'exitCode':p.returncode,'stdout':p.stdout[-12000:],'stderr':p.stderr[-8000:]})
    if p.returncode: raise RuntimeError('Command failed: ' + ' '.join(argv[:3]))
    return p.stdout

try:
    record['hostOS'] = command(['sw_vers'])
    record['hostArchitecture'] = command(['uname','-m']).strip()
    record['hostCPU'] = command(['sysctl','-n','machdep.cpu.brand_string']).strip()
    record['hostLogicalCPU'] = command(['sysctl','-n','hw.logicalcpu']).strip()
    record['hostPhysicalMemoryBytes'] = command(['sysctl','-n','hw.memsize']).strip()
    record['xcode'] = command(['xcodebuild','-version'])
    record['simulatorSDK'] = command(['xcrun','--sdk','iphonesimulator','--show-sdk-version']).strip()
    runtimes = json.loads(command(['xcrun','simctl','list','runtimes','-j']))['runtimes']
    available = [r for r in runtimes if r.get('isAvailable') and r.get('version','').split('.')[0] == '27' and 'iOS' in r['name']]
    assert available, 'No real iOS27 simulator runtime'
    runtime = max(available,key=lambda r:tuple(map(int,r['version'].split('.'))))
    record['simulatorRuntime'] = runtime
    udid = command(['xcrun','simctl','create',f"TextCrop-{record['runId']}-{record['attempt']}",
                    'com.apple.CoreSimulator.SimDeviceType.iPhone-14',runtime['identifier']]).strip()
    assert re.fullmatch(r'[0-9A-Fa-f-]{36}',udid), 'Invalid owned simulator ID'
    (work/'owned-simulator.json').write_text(json.dumps({'udid':udid,'runId':record['runId'],'attempt':record['attempt']})+'\n',encoding='utf-8')
    command(['xcrun','simctl','boot',udid]); command(['xcrun','simctl','bootstatus',udid,'-b'],timeout=240)
    started = time.monotonic()
    with (work/'native.stdout').open('wb') as out, (work/'native.stderr').open('wb') as err:
        p = subprocess.Popen(['xcrun','simctl','spawn',udid,str(work/'TextCropProbe'),str(work/'prepared')],stdout=out,stderr=err)
        try:
            while True:
                if (work/'native.stdout').stat().st_size > MAX_RAW_BYTES:
                    raise RuntimeError('Bounded raw transport exceeded; partial bytes remain pinned')
                remaining = 1200-(time.monotonic()-started)
                if remaining <= 0: raise subprocess.TimeoutExpired(p.args,1200)
                try:
                    status = p.wait(timeout=min(0.5,remaining)); break
                except subprocess.TimeoutExpired:
                    continue
        except (subprocess.TimeoutExpired,RuntimeError) as cause:
            p.terminate()
            try: p.wait(timeout=15)
            except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=15)
            record['nativeExitCode'] = p.returncode
            raise RuntimeError('Native wall/transport guard; partial pages remain unassessed: '+str(cause))
    record['nativeExitCode'] = status
    record['nativeSeconds'] = time.monotonic()-started
    assert (work/'native.stdout').stat().st_size <= MAX_RAW_BYTES, 'Bounded raw transport exceeded'
    raw = (work/'native.stdout').read_bytes()
    record['nativeRawSHA256'] = hashlib.sha256(raw).hexdigest()
    record['nativeRawBytes'] = len(raw)
    records = [json.loads(line) for line in raw.splitlines() if line.strip()]
    pages = [v for v in records if v.get('type') == 'region']
    expected = [('independent-Timetable-literal-乙',1,'left'),('independent-Timetable-literal-乙',1,'right')]
    assert [(p['fixture'],p['page'],p['region']) for p in pages] == expected, 'Incomplete crop acquisition; unreturned regions not scored'
    assert status == 0, 'Native command failure'
    summaries = [v for v in records if v.get('type') == 'summary']
    assert len(summaries) == 1 and summaries[0]['requestCount'] == 2, 'Finite two-request receipt missing'
    record['requestCount'] = summaries[0]['requestCount']
    record['attemptedRegions'] = len(pages)
    record['readReturnedRegions'] = sum(v['readReturned'] for v in pages)
    record['operationalErrors'] = sum('operationalError' in v for v in pages)
    record['formalAssessed'] = 0
    record['nativeExecutionComplete'] = True
    exit_status = 0
except Exception as error:
    record['executionError'] = repr(error)
    record['nativeExecutionComplete'] = False
finally:
    if started is not None: record['nativeSeconds'] = time.monotonic()-started
    raw_path = work/'native.stdout'
    if raw_path.is_file():
        raw_hash = hashlib.sha256()
        with raw_path.open('rb') as source:
            while chunk := source.read(65536): raw_hash.update(chunk)
        record['nativeRawSHA256'] = raw_hash.hexdigest()
        record['nativeRawBytes'] = raw_path.stat().st_size
        with raw_path.open('rb') as source: raw_bytes = source.read(MAX_RAW_BYTES)
        record['rawParsingTruncated'] = record['nativeRawBytes'] > MAX_RAW_BYTES
        partial = []
        for line in raw_bytes.splitlines():
            try:
                value = json.loads(line)
                if value.get('type') == 'page': partial.append(value)
            except (ValueError, AttributeError):
                record['nonJSONOrIncompleteRawLines'] = record.get('nonJSONOrIncompleteRawLines',0)+1
        record['recordedRegions'] = len(partial)
        record['readReturnedRegions'] = sum(bool(v.get('readReturned')) for v in partial)
        record['diagnosticCompletedRegions'] = sum(bool(v.get('diagnosticComplete')) for v in partial)
        record['serializationCompletedRegions'] = sum(bool(v.get('serializationCompleted')) for v in partial)
        record['cropPNGRecordedRegions'] = sum('cropPNG' in v for v in partial)
        record['recordedOperationalErrors'] = sum('operationalError' in v for v in partial)
        record['plannedRegionsWithoutRecord'] = max(0,2-len(partial))
    if udid:
        try:
            command(['xcrun','simctl','shutdown',udid],timeout=90)
        except Exception as error:
            record['shutdownError'] = repr(error)
        try:
            command(['xcrun','simctl','delete',udid],timeout=90)
        except Exception as error:
            cleanup_error = repr(error); record['cleanupError'] = cleanup_error
    for name in ['native.stdout','native.stderr']:
        path = work/name
        if path.is_file():
            print('IOS_TEXT_CROP_' + name.upper().replace('.','_') + '_BEGIN',flush=True)
            with path.open('rb') as source:
                while chunk := source.read(65536): sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
            print('\nIOS_TEXT_CROP_' + name.upper().replace('.','_') + '_END',flush=True)
    record['extraction'] = json.loads((work/'prepared/extraction.json').read_text())
    print('IOS_TEXT_CROP_EXECUTION_JSON ' + json.dumps(record,ensure_ascii=False),flush=True)
    (work/'execution.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sys.exit(1 if cleanup_error else exit_status)
