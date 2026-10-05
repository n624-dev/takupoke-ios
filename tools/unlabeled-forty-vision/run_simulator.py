"""One fresh unlabeled forty-slot source drawing and one Document request; bounded lossless CI transport."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import log_transport

EXPECTED_STREAMS={'native/stdout','native/stderr','metadata/execution'}
MAX_RAW_BYTES=64*1024*1024


def restore_complete(log):
    result=log_transport.restore(log)
    assert set(result)==EXPECTED_STREAMS,'Missing or extra stream; acquisition unassessed'
    return result


def receipt(raw):
    records=[];invalid=0
    for line in raw.splitlines():
        try:
            value=json.loads(line)
            assert isinstance(value,dict)
            records.append(value)
        except (ValueError,AssertionError):
            invalid+=1
    summaries=[v for v in records if v.get('type')=='summary']
    assessments=[v for v in records if v.get('type')=='literalAssessment']
    assertion=assessments[0] if len(assessments)==1 else {}
    return {'rawBytes':len(raw),'rawSHA256':hashlib.sha256(raw).hexdigest(),
            'recordTypes':[v.get('type') for v in records], 'invalidLines':invalid,
            'recordSequenceComplete':[v.get('type') for v in records]==['input','page','drawing','literalAssessment','summary'] and invalid==0,
            'summary':summaries[0] if len(summaries)==1 else None,
            'all40LiteralMatched':assertion.get('all40LiteralMatch') is True and assertion.get('state')=='ASSESSED',
            'assessedLiteralMismatch':assertion.get('all40LiteralMatch') is False and assertion.get('state')=='ASSESSED',
            'literalUnassessed':assertion.get('state')!='ASSESSED',
            'scope':'serialization/transport only; all PDF endpoint/adoption/formal storage unassessed here'}


def main(work):
    assert work.is_dir() and (work/'.unlabeled-forty-owned').is_file()
    record={'sourceCommit':os.environ['GITHUB_SHA'],'runId':os.environ['GITHUB_RUN_ID'],
            'attempt':os.environ['GITHUB_RUN_ATTEMPT'],'plannedRequests':1,'steps':[],
            'pdfInputs':0,'originalOrPriorImageInputs':0,'modelInvocations':0}
    udid=None;exit_status=1;cleanup_error=None
    def command(argv,timeout=180):
        p=subprocess.run(argv,capture_output=True,text=True,timeout=timeout)
        record['steps'].append({'argv':argv,'exitCode':p.returncode,'stdout':p.stdout[-12000:],'stderr':p.stderr[-8000:]})
        assert p.returncode==0,'Native environment command failed'
        return p.stdout
    try:
        record['xcode']=command(['xcodebuild','-version'])
        record['hostOS']=command(['sw_vers'])
        record['hostArchitecture']=command(['uname','-m']).strip()
        record['sdk']=command(['xcrun','--sdk','iphonesimulator','--show-sdk-version']).strip()
        runtimes=json.loads(command(['xcrun','simctl','list','runtimes','-j']))['runtimes']
        available=[r for r in runtimes if r.get('isAvailable') and r.get('version','').split('.')[0]=='27' and 'iOS' in r['name']]
        assert available,'No actual iOS27 runtime'
        runtime=max(available,key=lambda r:tuple(map(int,r['version'].split('.'))));record['runtime']=runtime
        udid=command(['xcrun','simctl','create',f"UnlabeledForty-{record['runId']}-{record['attempt']}",
                      'com.apple.CoreSimulator.SimDeviceType.iPhone-14',runtime['identifier']]).strip()
        assert re.fullmatch(r'[0-9A-Fa-f-]{36}',udid)
        (work/'owned-simulator.json').write_text(json.dumps({'udid':udid,'runId':record['runId'],'attempt':record['attempt']})+'\n')
        command(['xcrun','simctl','boot',udid]);command(['xcrun','simctl','bootstatus',udid,'-b'],timeout=240)
        paths=[work/f'native.{stream}' for stream in ['stdout','stderr']]
        started=time.monotonic()
        with paths[0].open('wb') as out,paths[1].open('wb') as err:
            p=subprocess.Popen(['xcrun','simctl','spawn',udid,str(work/'UnlabeledFortyProbe'),str(work)],stdout=out,stderr=err)
            try:
                while True:
                    assert sum(path.stat().st_size for path in paths)<=MAX_RAW_BYTES,'Raw transport bound exceeded'
                    remaining=600-(time.monotonic()-started)
                    if remaining<=0:raise subprocess.TimeoutExpired(p.args,600)
                    try:
                        status=p.wait(timeout=min(.5,remaining));break
                    except subprocess.TimeoutExpired:continue
            except Exception:
                p.terminate()
                try:p.wait(timeout=15)
                except subprocess.TimeoutExpired:p.kill();p.wait(timeout=15)
                record['nativeExitCode']=p.returncode
                raise
        record.update({'nativeExitCode':status,'nativeSeconds':time.monotonic()-started})
        record['receipt']=receipt(paths[0].read_bytes())
        assert status==0 and record['receipt']['recordSequenceComplete'],'Native/transport incomplete; no quality conclusion'
        record['nativeExecutionComplete']=True;exit_status=0
    except Exception as error:
        record['executionError']=repr(error);record['nativeExecutionComplete']=False
    finally:
        if udid:
            try:command(['xcrun','simctl','shutdown',udid],timeout=90)
            except Exception as e:record['shutdownError']=repr(e)
            try:command(['xcrun','simctl','delete',udid],timeout=90)
            except Exception as e:cleanup_error=repr(e);record['cleanupError']=cleanup_error
        for stream in ['stdout','stderr']:
            path=work/f'native.{stream}'
            if path.is_file():
                raw=path.read_bytes()
                if stream=='stdout':record['receipt']=receipt(raw[:MAX_RAW_BYTES])
                assert len(raw)<=MAX_RAW_BYTES,'Output bound exceeded; incomplete'
                for line in log_transport.encode(raw,'native/'+stream):print(line,flush=True)
        here=Path(__file__).resolve().parent
        record['helperSourceSHA256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(here.iterdir()) if p.is_file()}
        record['sourceReceipt']=json.loads((work/'prepared/source-receipt.json').read_text())
        execution=(json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode()
        for line in log_transport.encode(execution,'metadata/execution'):print(line,flush=True)
        print('IOS_UNLABELED_FORTY_SUMMARY '+json.dumps({'runId':record['runId'],'nativeExecutionComplete':record.get('nativeExecutionComplete',False),'receipt':record.get('receipt')}),flush=True)
    return 1 if cleanup_error else exit_status


if __name__=='__main__':sys.exit(main(Path(sys.argv[1]).resolve()))
