#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
study_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-ocr-screen.XXXXXX")"
trap 'rm -rf "$study_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$study_dir/python"
study_python="$study_dir/python/bin/python"
"$study_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-windows-transfer/requirements.txt
"$study_python" -B -m unittest discover -s tests -p test_ocr_windows_transfer.py -v
"$study_python" -B tools/ocr-windows-transfer/prepare.py --output "$study_dir/inputs"
"$study_python" -B tools/ocr-windows-transfer/prepare.py --models-only --output "$study_dir/models"
# Module/SDK caches are owned scratch, never an Actions cache or artifact.
CLANG_MODULE_CACHE_PATH="$study_dir/modules" swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx26.0" -module-cache-path "$study_dir/modules" \
    tools/ocr-windows-transfer/vision.swift -o "$study_dir/vision"
"$study_dir/vision" extract "$study_dir/inputs"
"$study_python" -B tools/ocr-windows-transfer/frames.py "$study_dir/inputs"
"$study_dir/vision" crops "$study_dir/inputs"
"$study_python" -B tools/ocr-windows-transfer/infer.py --models "$study_dir/models" --study "$study_dir/inputs"
"$study_python" -B tools/ocr-windows-transfer/compare.py "$study_dir/inputs"
# These are generated, entirely fictional records. Expected strings never go
# to either reader. Print only after every native call and comparison completed.
"$study_python" -B - "$study_dir/inputs" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
for name in ['inputs.json', 'oracle.json', 'physical.json', 'frames.json',
             'vision-pages.json', 'vision-crops.json', 'onnx.json']:
    data = json.loads((root / name).read_text())
    if name == 'onnx.json':
        for record in data['records']:
            print('OCR_SCREEN_ONNX ' + json.dumps(record, ensure_ascii=False, sort_keys=True))
    elif name == 'vision-crops.json':
        for record in data['records']:
            print('OCR_SCREEN_VISION_CROP ' + json.dumps(record, ensure_ascii=False, sort_keys=True))
    elif name == 'vision-pages.json':
        for record in data['pages']:
            print('OCR_SCREEN_VISION_PAGE ' + json.dumps(record, ensure_ascii=False, sort_keys=True))
    else:
        print('OCR_SCREEN_MANIFEST ' + json.dumps(dict(file=name, value=data), ensure_ascii=False, sort_keys=True))
PY
