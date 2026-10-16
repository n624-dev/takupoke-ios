"""Oracle-free input and public artifact checks shared by research readers."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COUNT = 192


def sha(data):
    return hashlib.sha256(data).hexdigest()


def public_pins():
    raw = (ROOT.parent/'ocr-windows-transfer/protocol.json').read_bytes()
    if sha(raw) != '715195d08d4a1e65e4b685ea5b1c265c8208b3b4346ca8c385ba0f27278d3d3b':
        raise ValueError('Frozen public artifact contract changed')
    return json.loads(raw)


def inputs(root):
    manifest = json.loads((root/'inputs.json').read_text())
    if set(manifest) != {'frames'} or len(manifest['frames']) != COUNT:
        raise ValueError('Incomplete original frame inventory')
    rows = manifest['frames']
    if [r['id'] for r in rows] != [f'code-{i:04}' for i in range(COUNT)]:
        raise ValueError('Changed, duplicate or reordered original inputs')
    for r in rows:
        if (set(r) != {'id','rgb','rgbSHA256','width','height'} or r['rgb'] != r['id']+'.rgb' or
                any(type(r[k]) is not int or not 1 <= r[k] <= 2048 for k in ['width','height'])):
            raise ValueError('Invalid oracle-free source record')
        raw = (root/r['rgb']).read_bytes()
        if len(raw) != r['width']*r['height']*3 or sha(raw) != r['rgbSHA256']:
            raise ValueError('Original RGB bytes changed')
    return rows
