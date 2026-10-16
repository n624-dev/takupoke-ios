#!/usr/bin/env python3
"""Fetch public fixed assets separately from inference; never accept a school input."""
import argparse
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import stat
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parent


def extract_slices(data, output):
    allowed = ('onnxruntime.xcframework/ios-arm64/',
               'onnxruntime.xcframework/ios-arm64_x86_64-simulator/')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for info in archive.infolist():
            if not info.filename.startswith(allowed):
                continue
            path = PurePosixPath(info.filename)
            if path.is_absolute() or '..' in path.parts or stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError('Unsafe native framework member')
            if info.file_size > 256 * 1024 * 1024:
                raise ValueError('Native framework member exceeds bound')
            target = output.joinpath(*path.parts)
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as stream:
                    value = stream.read(info.file_size + 1)
                if len(value) != info.file_size or target.exists():
                    raise ValueError('Native framework output mismatch')
                target.write_bytes(value)


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
