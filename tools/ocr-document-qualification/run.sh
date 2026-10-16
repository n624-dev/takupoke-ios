#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
: "${TKPK_OCR_QUALIFICATION_CASE:?Require a frozen qualification case}"
whole_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-qualification.XXXXXX")"
trap 'rm -rf "$whole_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -B - "$TKPK_OCR_QUALIFICATION_CASE" <<'PY'
import hashlib,json
from pathlib import Path
import sys
path=Path('tools/ocr-document-qualification/protocol.json')
protocol=json.loads(path.read_text())
if sys.argv[1] not in protocol['cases']: raise ValueError('Undeclared frozen source case')
print('QUALIFICATION_PROTOCOL '+json.dumps(dict(case=sys.argv[1],protocolSHA256=hashlib.sha256(path.read_bytes()).hexdigest(),
      study=protocol['study'],scope=protocol['scope']),sort_keys=True),flush=True)
PY
python3 -m venv "$whole_dir/python"
whole_python="$whole_dir/python/bin/python"
"$whole_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-full-document-transfer/requirements.txt
"$whole_python" -B tools/ocr-document-qualification/generate.py --case "$TKPK_OCR_QUALIFICATION_CASE" --output "$whole_dir/inputs"
TAKUPOKE_OCR_FULL_FONTS="$whole_dir/inputs/fonts" \
    "$whole_python" -B -m unittest discover -s tests -p test_ocr_document_qualification.py -v
mkdir -p "$whole_dir/project" "$whole_dir/tmp" "$whole_dir/models"
cp Package.swift Package.resolved "$whole_dir/project/"
cp -R Takupoke tests "$whole_dir/project/"
"$whole_python" -B - "$whole_dir" <<'PY'
import importlib.util
import json
from pathlib import Path
import sys
root=Path(sys.argv[1])
package=root/'project/Package.swift'
text=package.read_text(); marker='"StrictPDFCompatibilityTests.swift",'
if text.count(marker)!=1:
    raise ValueError('Owned research test registration marker changed')
package.write_text(text.replace(marker, marker+' "RecoveryDocumentQualificationTests.swift",'))
# A read-only accessor in the SAME owned source file can expose its original
# private mask. No production method is replaced or patched, even in this copy.
original=Path('Takupoke/RecoveryRasterGrid.swift').read_bytes()
owned=root/'project/Takupoke/RecoveryRasterGrid.swift'
if owned.read_bytes()!=original:
    raise ValueError('Owned production source changed before research access')
owned.write_bytes(original+b'\n'+Path('tools/ocr-full-document-transfer/mask-access.swift').read_bytes())
if not owned.read_bytes().startswith(original):
    raise ValueError('Original raster algorithm was altered')
spec=importlib.util.spec_from_file_location('public_artifact_fetch', 'tools/ocr-windows-transfer/prepare.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
pins=json.loads(Path('tools/ocr-ios-runtime-parity/protocol.json').read_text())
for pin in [pins['model'],pins['dictionary']]:
    module.fetch(pin,root/'models')
ascii_pins=json.loads(Path('tools/ocr-windows-transfer/protocol.json').read_text())['models']
for pin in ascii_pins:
    if pin['file'] in ['ascii-rec.onnx','ascii-dictionary.json']:
        module.fetch(pin,root/'models')

PY
TAKUPOKE_OCR_QUALIFICATION_INPUTS="$whole_dir/inputs" TAKUPOKE_OCR_QUALIFICATION_OUTPUT="$whole_dir/acquisition" \
TMPDIR="$whole_dir/tmp" CLANG_MODULE_CACHE_PATH="$whole_dir/modules" SWIFTPM_MODULECACHE_OVERRIDE="$whole_dir/modules" \
    swift test --package-path "$whole_dir/project" --scratch-path "$whole_dir/build" \
    --cache-path "$whole_dir/cache" --config-path "$whole_dir/config" --security-path "$whole_dir/security" \
    --disable-dependency-cache --manifest-cache none --jobs 2 -Xswiftc -DTAKUPOKE_INTERNAL_DIAGNOSTICS \
    --filter RecoveryDocumentQualificationTests 2>&1 | tee "$whole_dir/native.log"
"$whole_python" -B - "$whole_dir/native.log" <<'PY'
from pathlib import Path
import re
import sys
text=Path(sys.argv[1]).read_text()
if text.count('FULL_SOURCE_CAPTURE_FINISHED pages=2 actualVisionCalls=1')!=1:
    raise ValueError('Actual full-source capture did not finish exactly once')
if len(re.findall(r'Test Case .*testAcquireCompleteFrozenOriginalSource.*passed',text))!=1:
    raise ValueError('The native research test did not actually pass exactly once')
if 'Executed 1 test, with 0 failures' not in text:
    raise ValueError('Missing completed native test inventory')
PY
for whole_variant in current2048 source2x4096; do
    "$whole_python" -B tools/ocr-full-document-transfer/read.py --cohort full-scope --acquisition "$whole_dir/acquisition/$whole_variant" --models "$whole_dir/models"
done
# The oracle becomes accessible only to this separate, post-inference process.
for whole_variant in current2048 source2x4096; do
    "$whole_python" -B tools/ocr-full-document-transfer/compare.py --cohort full-scope --acquisition "$whole_dir/acquisition/$whole_variant" --oracle "$whole_dir/inputs/oracle.json" --vision-acquisition "$whole_dir/acquisition/current2048"
done
