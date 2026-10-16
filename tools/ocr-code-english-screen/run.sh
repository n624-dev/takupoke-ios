#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
code_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-code-english.XXXXXX")"
trap 'rm -rf "$code_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$code_dir/python"
code_python="$code_dir/python/bin/python"
"$code_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-windows-transfer/requirements.txt
"$code_python" -B -m unittest discover -s tests -p test_ocr_code_english_screen.py -v
"$code_python" -B tools/ocr-code-english-screen/prepare.py --output "$code_dir/study"
"$code_python" -B - "$code_dir/study/inputs" <<'PY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1])
print('CODE_ENGLISH_FROZEN '+json.dumps({name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ['inputs.json','oracle.json']},sort_keys=True),flush=True)
PY
CLANG_MODULE_CACHE_PATH="$code_dir/modules" swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx26.0" -module-cache-path "$code_dir/modules" \
    tools/ocr-code-english-screen/read.swift -o "$code_dir/reader"
"$code_dir/reader" "$code_dir/study/inputs" 2>&1 | tee "$code_dir/native.log"
"$code_python" -B - "$code_dir/native.log" <<'PY'
from pathlib import Path
import sys
if Path(sys.argv[1]).read_text().count('CODE_ENGLISH_NATIVE_FINISHED actualCalls=192')!=1:
    raise ValueError('Native reader did not finish exactly one complete inventory')
PY
"$code_python" -B tools/ocr-code-english-screen/read.py "$code_dir/study/inputs" "$code_dir/study/models"
"$code_python" -B tools/ocr-code-english-screen/compare.py "$code_dir/study/inputs"
