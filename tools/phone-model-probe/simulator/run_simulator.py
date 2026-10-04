"""Run an actual fixed Core AI probe on an owned iOS27 simulator; export errors."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import traceback
import zipfile

parser=argparse.ArgumentParser()
parser.add_argument('app',type=Path);parser.add_argument('model_zip',type=Path);parser.add_argument('project',type=Path);parser.add_argument('work',type=Path)
args=parser.parse_args();work=args.work.resolve()
assert work.is_dir() and (work/'.ios-model-simulator-owned').is_file()
package=work/'package';package.mkdir()
record=dict(scope='Actual iOS27 simulator component probe only; no physical iPhone/model recovery quality proof',status='starting',steps=[],nativeExecutionComplete=False)
start=time.monotonic();device=None

def command(argv, timeout=180):
    before=time.monotonic();p=subprocess.run(argv,capture_output=True,text=True,timeout=timeout)
    record['steps'].append(dict(command=argv,exitCode=p.returncode,seconds=time.monotonic()-before,stdout=p.stdout[-16000:],stderr=p.stderr[-16000:]))
    if p.returncode:raise RuntimeError(f'Command failed {p.returncode}: {argv[0:3]}')
    return p.stdout

try:
    record['hostOS']=command(['sw_vers']);record['hostArchitecture']=command(['uname','-m']).strip();record['xcode']=command(['xcodebuild','-version'])
    record['simulatorSDK']=command(['xcrun','--sdk','iphonesimulator','--show-sdk-version']).strip()
    manifest=json.loads((args.project/'Resources/ModelBundleManifest.json').read_text());record['actualModelManifest']=manifest
    assert manifest['files'] and len(manifest['files'])==7
    model=work/'verified-model';model.mkdir()
    folder='qwen3-0.6b-c1899de-ios-mixed'
    with zipfile.ZipFile(args.model_zip) as zipped:
        for item in manifest['files']:
            parts=Path(item['path']).parts
            assert parts and not Path(item['path']).is_absolute() and '..' not in parts and '\\' not in item['path']
            output=model/item['path'];output.parent.mkdir(parents=True,exist_ok=True)
            h=hashlib.sha256();count=0
            with zipped.open(folder+'/'+item['path']) as source,output.open('xb') as destination:
                while chunk:=source.read(1024*1024):
                    count+=len(chunk);assert count<=item['bytes'];h.update(chunk);destination.write(chunk)
            assert count==item['bytes'] and h.hexdigest()==item['sha256']
    runtime_json=json.loads(command(['xcrun','simctl','list','runtimes','-j']))
    runtimes=[r for r in runtime_json['runtimes'] if r.get('isAvailable') and r.get('version','').split('.')[0]=='27' and 'iOS' in r['name']]
    assert runtimes,'No available iOS27 simulator runtime'
    runtime=max(runtimes,key=lambda r:tuple(int(v) for v in r['version'].split('.')));record['simulatorRuntime']=runtime
    name=f"ModelProbe-{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    device=command(['xcrun','simctl','create',name,'com.apple.CoreSimulator.SimDeviceType.iPhone-14',runtime['identifier']]).strip()
    assert re.fullmatch(r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',device)
    owner=dict(udid=device,runId=os.environ['GITHUB_RUN_ID'],attempt=os.environ['GITHUB_RUN_ATTEMPT'],name=name)
    (work/'owned-simulator.json').write_text(json.dumps(owner)+'\n');record['ownedSimulator']=owner
    command(['xcrun','simctl','boot',device]);command(['xcrun','simctl','bootstatus',device,'-b'],timeout=240)
    command(['xcrun','simctl','install',device,str(args.app)])
    container=Path(command(['xcrun','simctl','get_app_container',device,'jp.n624.takupoke-modelprobe','data']).strip())
    documents=container/'Documents';documents.mkdir(exist_ok=True)
    shutil.copytree(model,documents/'CIModel')
    command(['xcrun','simctl','launch',device,'jp.n624.takupoke-modelprobe','--ci-native-probe'])
    deadline=time.monotonic()+600;output=None
    while time.monotonic()<deadline:
        candidates=sorted(documents.glob('model-probe-*.json'))
        if candidates:output=candidates[-1];break
        failure=documents/'ci-import-failure.json'
        if failure.is_file():output=failure;break
        time.sleep(2)
    assert output is not None,'No app report within600s; no successful inference assumed'
    report=json.loads(output.read_text());record['appReport']=report
    shutil.copy2(output,package/'ios-model-simulator.json')
    cases=report.get('cases',[])
    expected=json.loads((args.project/'Resources/PinnedCorpus.json').read_text())
    assert [v['caseId'] for v in cases]==[v['id'] for v in expected],'Partial app execution'
    for result in cases:
        sample=result['report'];assert sample['executionEnvironment'].startswith('iOSSimulator')
        samples=sample['samples'];assert any(s['operation']=='awaitedNativeUnload' for s in samples)
        assert not any(s.get('errorCode') is not None or s['operation'] in ['generationError','unloadError'] for s in samples)
        generations=[s for s in samples if s['operation'] in ['firstGeneration','warmGeneration']]
        assert sum(s['operation']=='firstGeneration' for s in generations)==1 and sum(s['operation']=='warmGeneration' for s in generations)==2
        for generated in generations:
            assert isinstance(generated.get('rawOutput'),str) and generated['rawOutput'].strip()
            json.loads(generated['rawOutput'])
    record['nativeExecutionComplete']=True;record['status']='actualNativeGenerationsCompleted:semanticCertificateQualityUnevaluated'
except BaseException as error:
    record['status']='actualSimulatorProbeFailed';record['error']=repr(error);record['traceback']=traceback.format_exc()[-16000:]
finally:
    if device:
        try:
            command(['xcrun','simctl','io',device,'screenshot',str(package/'ios-model-simulator-ui.png')],timeout=60)
            record['simulatorScreenshot']='ios-model-simulator-ui.png: actual simulator image, not physical UI evidence'
        except Exception as screenshot_error:
            record['simulatorScreenshot']=dict(error=repr(screenshot_error))
        try:
            p=subprocess.run(['xcrun','simctl','spawn',device,'log','show','--last','10m','--style','compact','--predicate','process == "ModelProbe"'],capture_output=True,text=True,timeout=60,check=False)
            record['modelProcessLog']=dict(exitCode=p.returncode,stdout=p.stdout[-150000:],stderr=p.stderr[-8000:])
        except Exception as log_error:
            record['modelProcessLog']=dict(error=repr(log_error))
    record['seconds']=time.monotonic()-start
    (package/'ios-model-simulator-execution.json').write_text(json.dumps(record,indent=2)+'\n')
    if not (package/'ios-model-simulator.json').exists():
        (package/'ios-model-simulator.json').write_text(json.dumps(dict(scope=record['scope'],actualFailure=record.get('error'),steps=record['steps']),indent=2)+'\n')
print(json.dumps(dict(status=record['status'],nativeExecutionComplete=record['nativeExecutionComplete'],seconds=record['seconds'])))
# The workflow uploads actual partial/error diagnostics before enforcing this gate.
