"""Freeze the exact current source and separate four density/color fictional PDF-only inputs."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/independent-reader-probe'))
import prepare as previous
RUNTIME_SOURCE = '2569b7a'
FILES = [v['file'] for v in json.loads((ROOT/'tools/independent-wide-timetable/dense-artifact-pins.json').read_text())['artifacts']]
SOURCES = previous.SOURCES
sha = previous.sha


def prepare(output, fixtures, pins=None):
    assert output.parent.is_dir() and not output.exists()
    output.mkdir()
    if pins is None: pins=json.loads((ROOT/'tools/independent-wide-timetable/dense-artifact-pins.json').read_text())
    manifest=json.loads((fixtures/'manifest.json').read_text())
    assert manifest['generatorSha256']==pins['generatorSha256']
    assert sha((ROOT/'tools/independent-wide-timetable/generate_dense.py').read_bytes())==pins['generatorSha256']
    assert sha((fixtures/'expected.json').read_bytes())==manifest['expectedSha256']==pins['expectedSha256']
    inputs=[]
    for name in FILES:
        artifact=next(item for item in manifest['artifacts'] if item['file']==name)
        pinned=next(item for item in pins['artifacts'] if item['file']==name)
        assert artifact['sha256']==pinned['sha256'] and artifact['bytes']==pinned['bytes']
        data=(fixtures/name).read_bytes();assert sha(data)==artifact['sha256'] and len(data)==artifact['bytes']
        inputs.append({'file':name,'sha256':sha(data),'bytes':len(data)})
    (output/'native-inputs.json').write_text(json.dumps({'schema':1,'files':inputs},indent=2)+'\n')
    folder=output/'fixed';folder.mkdir()
    parameters=previous.source_parameters();(folder/'SourceParameters.swift').write_bytes(parameters)
    rows=[]
    for name in SOURCES:
        current=(ROOT/'Takupoke'/name).read_bytes()
        frozen=subprocess.check_output(['git','show',RUNTIME_SOURCE+':Takupoke/'+name],cwd=ROOT)
        assert current==frozen,'Current production source differs from reviewed immutable runtime: '+name
        (folder/name).write_bytes(current)
        rows.append({'mode':'fixed','path':'Takupoke/'+name,'sha256':sha(current),'source':'exactReviewedRuntime'})
    receipt={'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),
        'runtimeSourceCommit':subprocess.check_output(['git','rev-parse',RUNTIME_SOURCE],cwd=ROOT).decode().strip(),
        'sourceFiles':rows,'sourceParameterSHA256':sha(parameters),
        'sourceParameters':'Exact public MaterialKind,maximumBytes,normalPeriodTimes declarations only; no runtime substitution',
        'generatedFixtureManifestSHA256':sha((fixtures/'manifest.json').read_bytes()),
        'scope':'Independent current-only actualReader/Strict/completecapture/Builder/Rules/Validator/in-memoryAnalysis four separate density/color calls',
        'ocrRequests':0,'modelInvocations':0,'expectedUse':'After actual Analysis only; assertions never enter source APIs',
        'nativeInputs':inputs,'fixedRequests':4,'baselineRequests':0,'denseRequests':4,'wideRequests':0}
    (output/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')


if __name__=='__main__':prepare(Path(sys.argv[1]),Path(sys.argv[2]))
