"""Upload/read back only run-owned artifacts to an existing draft QA prerelease."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import quote

repo=os.environ['GITHUB_REPOSITORY'];tag=os.environ['QA_TAG']
run_id=os.environ['GITHUB_RUN_ID'];attempt=os.environ['GITHUB_RUN_ATTEMPT']
candidate=os.environ['QA_CANDIDATE_ID'];assert re.fullmatch(r'[a-z0-9-]+',candidate)
release_id_text=os.environ['QA_RELEASE_ID'];assert release_id_text.isdigit() and int(release_id_text)>0
expected_release_id=int(release_id_text)
assert re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',repo)
assert re.fullmatch(r'model-probe-ios-[0-9]{8}(-[a-z0-9]+)?',tag)
assert run_id.isdigit() and attempt.isdigit()
package=Path(sys.argv[1]).resolve();receipt_path=package/'upload-owned-assets.json'
def api(path,extra=(),binary=False):
    value=subprocess.run(['gh','api',path,*extra],check=True,capture_output=True)
    return value.stdout if binary else json.loads(value.stdout)
def release():
    value=api(f'repos/{repo}/releases/{expected_release_id}')
    assert value['id']==expected_release_id and value['tag_name']==tag and value['draft'] and value['prerelease'], 'Only exact immutable draft research prerelease allowed'
    return value
def cleanup_owned(owned):
    result=[]
    for asset_id in owned:
        try:release()
        except Exception as error:
            result.append(dict(assetId=asset_id,deleteExitCode=None,confirmedAbsent=False,releaseGuardError=str(error)))
            continue
        deleted=subprocess.run(['gh','api',f'repos/{repo}/releases/assets/{asset_id}','-X','DELETE'],capture_output=True,check=False)
        check=subprocess.run(['gh','api',f'repos/{repo}/releases/assets/{asset_id}'],capture_output=True,check=False)
        result.append(dict(assetId=asset_id,deleteExitCode=deleted.returncode,confirmedAbsent=check.returncode!=0 and b'HTTP 404' in check.stderr))
    return result
if '--cleanup' in sys.argv[2:]:
    if not receipt_path.exists():raise SystemExit(0)
    saved=json.loads(receipt_path.read_text())
    assert saved['runId']==run_id and saved['attempt']==attempt and saved['releaseId']==expected_release_id
    if saved['status']=='allUploadedAndReadbackVerified':raise SystemExit(0)
    before=set(saved['preexistingAssetIds']);owned=list(saved['ownedAssetIds'])
    try:
        state=api(f'repos/{repo}/releases/{saved["releaseId"]}')
        for asset in state['assets']:
            if asset['id'] not in before and asset['name'] in saved['targetNames'] and asset.get('uploader',{}).get('login')=='github-actions[bot]' and asset['id'] not in owned:owned.append(asset['id'])
    except Exception:pass
    saved['cleanup']=cleanup_owned(owned);saved['ownedAssetIds']=owned
    saved['status']='failedOwnAssetsCleanupChecked';receipt_path.write_text(json.dumps(saved,indent=2)+'\n')
    print(json.dumps(dict(status=saved['status'],cleanup=saved['cleanup'])))
    raise SystemExit(0 if all(item['confirmedAbsent'] for item in saved['cleanup']) else 1)
initial=release();release_id=initial['id'];preexisting={x['id'] for x in initial['assets']}
files=[package/'gguf-component-evidence.zip',package/'batch-report.json']
names=[f'ios-gguf-{candidate}-{run_id}-{attempt}.zip',f'ios-gguf-{candidate}-{run_id}-{attempt}.json']
assert all(name not in {x['name'] for x in initial['assets']} for name in names), 'This run already owns artifact names; existing assets must remain'
owned=[];verified=[]
def save(status):
    receipt_path.write_text(json.dumps(dict(scope='Only uniquely named assets created by this run, no source/model/release changes',releaseId=release_id,runId=run_id,attempt=attempt,status=status,ownedAssetIds=owned,preexistingAssetIds=sorted(preexisting),targetNames=names,verified=verified),indent=2)+'\n')
save('started')
try:
    for path,name in zip(files,names):
        state=release();assert state['id']==release_id
        upload=api(f'https://uploads.github.com/repos/{repo}/releases/{release_id}/assets?name={quote(name,safe="")}',('-X','POST','-H','Content-Type: application/octet-stream','--input',str(path)))
        assert upload['name']==name and upload['id'] not in preexisting
        owned.append(upload['id']);save('uploadedAwaitingReadback')
        download=api(f'repos/{repo}/releases/assets/{upload["id"]}',('-H','Accept: application/octet-stream'),binary=True)
        actual=hashlib.sha256(download).hexdigest();expected=hashlib.sha256(path.read_bytes()).hexdigest()
        assert len(download)==path.stat().st_size==upload['size'] and actual==expected, 'Uploaded artifact readback mismatch'
        verified.append(dict(assetId=upload['id'],name=name,bytes=len(download),sha256=actual));save('verifiedPartial')
    state=release();assert state['id']==release_id
    save('allUploadedAndReadbackVerified')
except BaseException:
    # An upload response can fail after the server created its asset. Recover
    # only this uniquely run/attempt-named bot asset, absent in the preimage.
    try:
        state=api(f'repos/{repo}/releases/{release_id}')
        for asset in state['assets']:
            if asset['id'] not in preexisting and asset['name'] in names and asset.get('uploader',{}).get('login')=='github-actions[bot]':
                if asset['id'] not in owned:owned.append(asset['id'])
    except Exception:pass
    save('failedCleaningOnlyOwnAssets')
    cleanup=cleanup_owned(owned);save('failedOwnAssetsCleanupChecked')
    saved=json.loads(receipt_path.read_text());saved['cleanup']=cleanup;receipt_path.write_text(json.dumps(saved,indent=2)+'\n')
    print(json.dumps(dict(status=saved['status'],cleanup=cleanup)))
    raise
print(json.dumps(dict(status='Uploaded and exactreadbackverified',assets=verified)))
