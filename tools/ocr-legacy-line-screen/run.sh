#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
legacy_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-legacy-lines.XXXXXX")"
trap 'rm -rf "$legacy_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$legacy_dir/python"
legacy_python="$legacy_dir/python/bin/python"
"$legacy_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-windows-transfer/requirements.txt
"$legacy_python" -B -m unittest discover -s tests -p test_ocr_legacy_line_screen.py -v
"$legacy_python" -B tools/ocr-windows-transfer/prepare.py --output "$legacy_dir/inputs"
CLANG_MODULE_CACHE_PATH="$legacy_dir/modules" swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx26.0" -module-cache-path "$legacy_dir/modules" \
    tools/ocr-ios-runtime-parity/rasterize.swift -o "$legacy_dir/rasterize"
"$legacy_dir/rasterize" "$legacy_dir/inputs"
"$legacy_python" -B tools/ocr-windows-transfer/frames.py "$legacy_dir/inputs"
CLANG_MODULE_CACHE_PATH="$legacy_dir/modules" swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx26.0" -module-cache-path "$legacy_dir/modules" \
    tools/ocr-legacy-line-screen/read.swift -o "$legacy_dir/reader"
"$legacy_dir/reader" "$legacy_dir/inputs" 2>&1 | tee "$legacy_dir/native.log"
"$legacy_python" -B - "$legacy_dir/native.log" <<'PY'
from pathlib import Path
import sys
if Path(sys.argv[1]).read_text().count('LEGACY_LINE_CAPTURE_FINISHED actualCalls=288')!=1:
    raise ValueError('Native reader did not complete its entire inventory')
PY
# Oracle is first read by this separate process, after every native call.
"$legacy_python" -B tools/ocr-legacy-line-screen/compare.py "$legacy_dir/inputs"
