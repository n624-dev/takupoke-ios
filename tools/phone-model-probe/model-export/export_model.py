"""Pinned public official conversion on CI; publish no model qualification."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile

COREAI_REVISION = '52c84ba874b2c57adcede08a671ce96ed1b3f433'
MODEL_REVISION = 'c1899de289a04d12100db370d81485cdf75e47ca'
BUNDLE_NAME = 'qwen3-0.6b-c1899de-ios-mixed'
RECIPE_SHA = 'abb475910f45dac4bd4ac69de005f93d51d0a40d5e5819623c5d58f173f0307d'
PATCH_BEFORE = 'ebfb1b425c2e4e4a7b282b7fb0c5ce037bdacc5a2fe0c2f41caef0dbdd374b07'
PATCH_AFTER = '8285c597e9366473d5e3a8fbb0653c4b6161aeec6056259dfc4ab14aae315634'

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        while chunk := source.read(1024 * 1024): h.update(chunk)
    return h.hexdigest()

def download(name, destination, size, expected):
    assert '/' not in name
    h = hashlib.sha256(); count = 0
    url = f'https://huggingface.co/Qwen/Qwen3-0.6B/resolve/{MODEL_REVISION}/{name}'
    with urllib.request.urlopen(url, timeout=120) as response, destination.open('xb') as output:
        while chunk := response.read(1024 * 1024):
            count += len(chunk); assert count <= size
            h.update(chunk); output.write(chunk)
    assert count == size and h.hexdigest() == expected, f'Pinned input mismatch: {name}'

parser = argparse.ArgumentParser()
parser.add_argument('work', type=Path)
parser.add_argument('source', type=Path)
args = parser.parse_args()
work = args.work.resolve(); source = args.source.resolve()
assert work.is_dir() and (work / '.ios-model-export-owned').is_file()
assert sys.version_info[:2] == (3, 12)
coreai = work / 'coreai-models'
assert subprocess.check_output(['git', '-C', str(coreai), 'rev-parse', 'HEAD'], text=True).strip() == COREAI_REVISION
recipe = coreai / 'models/qwen3/qwen3_0_6b_mixed_4bit_8bit.yaml'
assert digest(recipe) == RECIPE_SHA
checkpoint = work / 'checkpoint'; checkpoint.mkdir()
pins = json.loads((source / 'checkpoint-pins.json').read_text())
assert pins['model'] == 'Qwen/Qwen3-0.6B' and pins['revision'] == MODEL_REVISION
for row in pins['files']: download(row['file'], checkpoint / row['file'], row['size'], row['sha256'])
package = work / 'package'; package.mkdir()
download('README.md', package / 'SOURCE-MODEL-CARD.txt', 13965, '1ab64a26fcb3b461423b89a433a8c858f1bf8d4086f979cbb3ff878d47cf20e9')
download('LICENSE', package / 'SOURCE-MODEL-LICENSE.txt', 11343, '832dd9e00a68dd83b3c3fb9f5588dad7dcf337a0db50f7d9483f310cd292e92e')
shutil.copy2(coreai / 'LICENSE', package / 'COREAI-MODELS-LICENSE.txt')
assert digest(package / 'COREAI-MODELS-LICENSE.txt') == '0ce5470a3d6a7c2a2d28b3effa68a6298a56e092da1c166bd0eba977f6e075ab'
# Resource concurrency only: numerical compression recipe remains unchanged.
spec = importlib.util.find_spec('coreai_models'); assert spec and spec.submodule_search_locations
compression = Path(next(iter(spec.submodule_search_locations))) / 'export/compression.py'
assert digest(compression) == PATCH_BEFORE
old = 'palettizer.prepare(example_inputs=example_inputs, num_workers=32)'
new = 'palettizer.prepare(example_inputs=example_inputs, num_workers=1)'
text = compression.read_text(); assert text.count(old) == 1
compression.write_text(text.replace(old, new)); assert digest(compression) == PATCH_AFTER
command = [str(Path(sys.executable).parent / 'coreai.llm.export'), str(checkpoint), '--experimental',
           '--platform', 'iOS', '--compute-precision', 'float16', '--max-context-length', '4096',
           '--compression-config', str(recipe), '--output-dir', str(work / 'converted'), '--output-name', BUNDLE_NAME]
environment = dict(os.environ, HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1', OMP_NUM_THREADS='2', MKL_NUM_THREADS='2',
                   MAX_JOBS='2', TORCH_EXTENSIONS_DIR=str(work / 'torch-build'))
start = time.monotonic()
with (package / 'CONVERSION.log').open('w') as log:
    completed = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
if completed.returncode:
    print((package / 'CONVERSION.log').read_text()[-24000:]); raise SystemExit(completed.returncode)
bundle = work / 'converted' / BUNDLE_NAME
required = {'metadata.json', f'{BUNDLE_NAME}.aimodel/main.hash', f'{BUNDLE_NAME}.aimodel/main.mlirb',
            f'{BUNDLE_NAME}.aimodel/metadata.json', 'tokenizer/chat_template.jinja', 'tokenizer/tokenizer.json', 'tokenizer/tokenizer_config.json'}
files = []
for path in sorted(bundle.rglob('*')):
    assert not path.is_symlink()
    if path.is_file(): files.append(dict(path=path.relative_to(bundle).as_posix(), bytes=path.stat().st_size, sha256=digest(path)))
assert {x['path'] for x in files} == required
assert sum(x['bytes'] for x in files) <= 2_500_000_000
identity = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
manifest = dict(scope='New actual CI conversion; no native inference, quality qualification, or product activation', bundleSHA256=identity, files=files)
(package / 'MODEL-BUNDLE-MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
freeze = subprocess.check_output([sys.executable, '-m', 'pip', 'freeze'], text=True)
(package / 'CONVERSION-DEPENDENCIES.txt').write_text(freeze)
provenance = dict(scope=manifest['scope'], sourceModel=pins['model'], sourceRevision=MODEL_REVISION,
                  sourceFiles=pins['files'], coreAIModelsRevision=COREAI_REVISION, recipeSHA256=RECIPE_SHA,
                  command=command, resourceOnlyPatch=dict(beforeSHA256=PATCH_BEFORE, afterSHA256=PATCH_AFTER, old=old, new=new),
                  seconds=time.monotonic()-start, conversionPeakRSSKiB=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
                  memoryScope='Linux RUSAGE_CHILDREN.ru_maxrss: largest child high-water RSS, not concurrent complete process-tree peak or phone memory',
                  python=sys.version, workflowCommit=os.environ['GITHUB_SHA'], runId=os.environ['GITHUB_RUN_ID'], attempt=os.environ['GITHUB_RUN_ATTEMPT'],
                  bundleManifest=manifest, qualification='NONE: native simulator/physical validation remains pending')
(package / 'MODEL-PROVENANCE.json').write_text(json.dumps(provenance, indent=2) + '\n')
archive = package / 'ios-coreai-model.zip'
extras = sorted(p for p in package.iterdir() if p.is_file())
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
    for row in files: zipped.write(bundle / row['path'], f'{BUNDLE_NAME}/{row["path"]}')
    for path in extras: zipped.write(path, path.name)
with zipfile.ZipFile(archive) as zipped:
    assert zipped.testzip() is None
    for row in files:
        h = hashlib.sha256(); count = 0
        with zipped.open(f'{BUNDLE_NAME}/{row["path"]}') as member:
            while chunk := member.read(1024 * 1024): h.update(chunk); count += len(chunk)
        assert count == row['bytes'] and h.hexdigest() == row['sha256']
receipt = dict(scope=manifest['scope'], archiveBytes=archive.stat().st_size, archiveSHA256=digest(archive),
               bundleFolder=BUNDLE_NAME, bundleManifest=manifest,
               reviewedSourceNeedsUpdate='Compare actual seven output file hashes with original; review/app manifest/sourceZIP must match these actual bytes before import',
               workflowCommit=os.environ['GITHUB_SHA'], runId=os.environ['GITHUB_RUN_ID'], attempt=os.environ['GITHUB_RUN_ATTEMPT'])
(package / 'ios-coreai-model-manifest.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))
