#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
diagnostic_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-native-image.XXXXXX")"
trap 'rm -rf "$diagnostic_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$diagnostic_dir/python"
diagnostic_python="$diagnostic_dir/python/bin/python"
"$diagnostic_python" -m pip install --no-cache-dir --disable-pip-version-check \
    Pillow==12.3.0 fonttools==4.61.1 reportlab==4.4.9
# Same consumed fictional generation, not a new independent quality dataset.
"$diagnostic_python" -B tools/ocr-windows-transfer/prepare.py --output "$diagnostic_dir/inputs"
CLANG_MODULE_CACHE_PATH="$diagnostic_dir/modules" swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx26.0" -module-cache-path "$diagnostic_dir/modules" \
    tools/ocr-apple-native-diagnostic/diagnose.swift -o "$diagnostic_dir/diagnose"
"$diagnostic_dir/diagnose" "$diagnostic_dir/inputs"
