"""Retain bounded real reports/failures and notices, never downloaded weights."""
import json
import os
from pathlib import Path
import sys
import zipfile
from run_batch import atomic_json, digest
source, work = map(Path, sys.argv[1:])
package = work / 'package'
package.mkdir(exist_ok=True)
report_path = work / 'batch-report.json'
if not report_path.is_file():
    atomic_json(report_path, dict(scope='Native CPU component controls only; no qualification',candidateId=os.environ['QA_CANDIDATE_ID'],nativeExecutionComplete=False,executionError=dict(type='PreparationOrBuildFailure',message='Native model process was not reached; see retained actual CI log'),usefulAIRecoveryDenominator=0))
report = json.loads(report_path.read_text())
certificate = work / 'native-certificate.json'
if certificate.is_file():
    report['nativeCertificateControl'] = json.loads(certificate.read_text())
else:
    report['nativeCertificateControl'] = dict(executed=False,reason='Native Swift scorer did not return a report; see retained native-scorer log')
report['sourceRecipePins'] = {p.name:dict(bytes=p.stat().st_size,sha256=digest(p)) for p in sorted(source.glob('*')) if p.is_file() and p.suffix in ('.py','.json','.swift')}
report['nativeScorerCompleted'] = certificate.is_file() and (work/'native-scorer-status.txt').is_file() and (work/'native-scorer-status.txt').read_text().strip()=='0'
logs=[]
with zipfile.ZipFile(package/'gguf-component-evidence.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for p in sorted(source.glob('licenses/*')):
        if p.is_file():archive.write(p,'licenses/'+p.name)
    for name in ('candidates.json','corpus.json','NativeScorer.swift','README.md','simulator-failure.json','prompt-audit.json'):
        archive.write(source/name,'recipe/'+name)
    for p in (work/'llama/LICENSE',work/'host.json'):
        if p.is_file():archive.write(p,'runtime/'+p.name)
    for name in ('runtime-build.log','runtime.log','native-scorer.log'):
        p=work/name
        if p.is_file():
            size=p.stat().st_size
            with p.open('rb') as stream:data=stream.read(1048576)
            archive.writestr('logs/'+name,data)
            logs.append(dict(file=name,originalBytes=size,originalSHA256=digest(p),retainedBytes=len(data),truncated=size>len(data)))
    report['logs']=logs
    atomic_json(package/'batch-report.json',report)
    archive.write(package/'batch-report.json','batch-report.json')
    if certificate.is_file():archive.write(certificate,'native-certificate.json')
with zipfile.ZipFile(package/'gguf-component-evidence.zip') as archive:
    assert archive.testzip() is None
print(json.dumps(dict(packageBytes=(package/'gguf-component-evidence.zip').stat().st_size,packageSHA256=digest(package/'gguf-component-evidence.zip'),nativeExecutionComplete=report['nativeExecutionComplete'],nativeScorerCompleted=report['nativeScorerCompleted'])))
