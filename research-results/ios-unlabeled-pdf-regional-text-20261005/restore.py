"""Restore selected JSON observations and verify all public bytes; never regenerates native inputs."""
import base64,gzip,hashlib,importlib.util,json,sys
from pathlib import Path
root=Path(__file__).resolve().parent
manifest=json.loads((root/'manifest.json').read_text())
for row in manifest['files']:
    b=(root/row['path']).read_bytes()
    assert len(b)==row['bytes'] and hashlib.sha256(b).hexdigest()==row['sha256'],row['path']
def unpack(name):
    value=json.loads((root/name).read_text());packed=base64.b64decode(value['data'],validate=True)
    assert len(packed)==value['gzipBytes'] and hashlib.sha256(packed).hexdigest()==value['gzipSHA256']
    b=gzip.decompress(packed)
    assert len(b)==value['bytes'] and hashlib.sha256(b).hexdigest()==value['sha256']
    records=[json.loads(line) for line in b.splitlines()]
    assert all(r['type']!='inputImage' for r in records)
    assert b'losslessPNGBase64' not in b
    return b,records
raw,records=unpack('raw-observations.json')
unpack('orientation-attempt-selected-raw.json')
spec=importlib.util.spec_from_file_location('portable',root/'analyze.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
actual=module.analyze(records,json.loads((root/'posthoc-drawing.json').read_text()))
assert (json.dumps(actual,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode()==(root/'derived-evidence.json').read_bytes()
if len(sys.argv)==2:
    with Path(sys.argv[1]).open('xb') as f:f.write(raw)
print(json.dumps({'publicFileHashesVerified':len(manifest['files']),'selectedRawBytes':len(raw),'selectedRawSHA256':hashlib.sha256(raw).hexdigest(),'derivedReproducedByteExactly':True,'inputImageRecordsPublished':0}))
