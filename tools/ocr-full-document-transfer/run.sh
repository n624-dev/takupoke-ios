#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
whole_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-full-source.XXXXXX")"
trap 'rm -rf "$whole_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$whole_dir/python"
whole_python="$whole_dir/python/bin/python"
"$whole_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-full-document-transfer/requirements.txt
"$whole_python" -B tools/ocr-full-document-transfer/generate.py --output "$whole_dir/inputs"
TAKUPOKE_OCR_FULL_FONTS="$whole_dir/inputs/fonts" \
    "$whole_python" -B -m unittest discover -s tests -p test_ocr_full_document_transfer.py -v
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
package.write_text(text.replace(marker, marker+' "RecoveryFullSourceProbeTests.swift",'))
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
PY
TAKUPOKE_OCR_FULL_INPUTS="$whole_dir/inputs" TAKUPOKE_OCR_FULL_OUTPUT="$whole_dir/acquisition" \
TMPDIR="$whole_dir/tmp" CLANG_MODULE_CACHE_PATH="$whole_dir/modules" SWIFTPM_MODULECACHE_OVERRIDE="$whole_dir/modules" \
    swift test --package-path "$whole_dir/project" --scratch-path "$whole_dir/build" \
    --cache-path "$whole_dir/cache" --config-path "$whole_dir/config" --security-path "$whole_dir/security" \
    --disable-dependency-cache --manifest-cache none --jobs 2 -Xswiftc -DTAKUPOKE_INTERNAL_DIAGNOSTICS \
    --filter RecoveryFullSourceProbeTests 2>&1 | tee "$whole_dir/native.log"
"$whole_python" -B - "$whole_dir/native.log" <<'PY'
from pathlib import Path
import re
import sys
text=Path(sys.argv[1]).read_text()
if text.count('FULL_SOURCE_CAPTURE_FINISHED pages=6 actualVisionCalls=6')!=1:
    raise ValueError('Actual full-source capture did not finish exactly once')
if len(re.findall(r'Test Case .*testAcquireFullOriginalPixelsNativeVisionAndPhysicalRules.*passed',text))!=1:
    raise ValueError('The native research test did not actually pass exactly once')
if 'Executed 1 test, with 0 failures' not in text:
    raise ValueError('Missing completed native test inventory')
PY
"$whole_python" -B tools/ocr-full-document-transfer/read.py --acquisition "$whole_dir/acquisition" --models "$whole_dir/models"
# The oracle becomes accessible only to this separate, post-inference process.
"$whole_python" -B tools/ocr-full-document-transfer/compare.py --acquisition "$whole_dir/acquisition" --oracle "$whole_dir/inputs/oracle.json"
