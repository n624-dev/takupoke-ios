#!/usr/bin/env python3
"""Fetch only the fixed ASCII model and official iOS CPU framework."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parent


spec = importlib.util.spec_from_file_location('ios_cpu_archive_helpers', ROOT.parent/'ocr-ios-runtime-parity/prepare.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
extract_slices = base.extract_slices


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    protocol = json.loads((ROOT / 'protocol.json').read_text())
    runtime = protocol['runtime']
    package = args.output / 'runtime.nupkg'
    total, hasher = 0, hashlib.sha256()
    with urllib.request.urlopen(runtime['url'], timeout=120) as response, package.open('xb') as destination:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > runtime['packageBytes']:
                raise ValueError('Native package exceeds pinned size')
            hasher.update(chunk)
            destination.write(chunk)
    if total != runtime['packageBytes']:
        raise ValueError('Native package is incomplete')
    with zipfile.ZipFile(package) as archive:
        info = archive.getinfo(runtime['entry'])
        if info.file_size != runtime['frameworkBytes']:
            raise ValueError('Native framework archive size changed')
        with archive.open(info) as source:
            data = source.read(runtime['frameworkBytes'] + 1)
    if len(data) != runtime['frameworkBytes'] or hashlib.sha256(data).hexdigest() != runtime['frameworkSHA256']:
        raise ValueError('Native framework archive hash mismatch')
    extract_slices(data, args.output)
    package.unlink()
    spec = importlib.util.spec_from_file_location('fictional_asset_preparation', ROOT.parent / 'ocr-windows-transfer/prepare.py')
    shared = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shared)
    models = args.output / 'models'
    models.mkdir()
    for pin in [protocol['model'], protocol['dictionary']]:
        shared.fetch(pin, models)
    receipt = dict(packageBytes=total, observedPackageSHA256=hasher.hexdigest(),
                   verifiedInnerArchiveSHA256=runtime['frameworkSHA256'],
                   verifiedInnerArchiveBytes=len(data), url=runtime['url'])
    (args.output / 'package-receipt.json').write_text(json.dumps(receipt, sort_keys=True) + '\n')
    print('ORT_IOS_PACKAGE ' + json.dumps(receipt, sort_keys=True))


if __name__ == '__main__':
    main()
