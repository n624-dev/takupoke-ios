#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
: "${TKPK_PARITY_IOS:?Require an explicit supported iOS major}"
parity_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-ios-ascii.XXXXXX")"
trap 'rm -rf "$parity_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$parity_dir/python"
parity_python="$parity_dir/python/bin/python"
"$parity_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-windows-transfer/requirements.txt
"$parity_python" -B -m unittest discover -s tests -p test_ocr_research_receipt.py -v
"$parity_python" -B -m unittest discover -s tests -p 'test_ocr_ios*runtime_parity.py' -v
"$parity_python" -B tools/ocr-ios-ascii-runtime-parity/prepare.py "$parity_dir/assets"
"$parity_python" -B tools/ocr-windows-transfer/prepare.py --output "$parity_dir/inputs"
CLANG_MODULE_CACHE_PATH="$parity_dir/modules" swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx26.0" -module-cache-path "$parity_dir/modules" \
    tools/ocr-ios-runtime-parity/rasterize.swift -o "$parity_dir/rasterize"
"$parity_dir/rasterize" "$parity_dir/inputs"
"$parity_python" -B tools/ocr-windows-transfer/frames.py "$parity_dir/inputs"
sim_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
device_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
"$parity_python" -B - "$TKPK_PARITY_IOS" "$(xcrun --sdk iphonesimulator --show-sdk-version)" "$(xcrun --sdk iphoneos --show-sdk-version)" <<'PY'
import sys
major=int(sys.argv[1])
assert major in (26,27)
assert all(int(version.split('.')[0])==major for version in sys.argv[2:]), 'Wrong Apple SDK'
PY
sim_framework="$parity_dir/assets/onnxruntime.xcframework/ios-arm64_x86_64-simulator"
device_framework="$parity_dir/assets/onnxruntime.xcframework/ios-arm64"
# Official slices are universal static archives inside framework bundles.
# Link their Apple dependencies explicitly; register no CoreML execution provider.
framework_args=(-framework onnxruntime -framework Foundation -framework CoreML -framework Accelerate -lz)
# Cross-compile against the real iPhone SDK; no execution on a phone is claimed.
xcrun --sdk iphoneos clang++ -std=c++17 -O2 -target arm64-apple-ios26.0 \
    -isysroot "$device_sdk" -I "$device_framework/onnxruntime.framework/Headers" \
    -F "$device_framework" tools/ocr-ios-ascii-runtime-parity/runner.cpp \
    "${framework_args[@]}" -o "$parity_dir/iphone-probe"
xcrun --sdk iphonesimulator clang++ -std=c++17 -O2 -target "$(uname -m)-apple-ios26.0-simulator" \
    -isysroot "$sim_sdk" -I "$sim_framework/onnxruntime.framework/Headers" \
    -F "$sim_framework" tools/ocr-ios-ascii-runtime-parity/runner.cpp \
    "${framework_args[@]}" -o "$parity_dir/simulator-probe"
codesign --force --sign - --timestamp=none "$parity_dir/simulator-probe"
xcrun vtool -show-build "$parity_dir/iphone-probe"
xcrun vtool -show-build "$parity_dir/simulator-probe"
# Verify real C API code is linked in BOTH targets, including the unexecuted
# iPhone binary; a dead-code-only SDK build is insufficient.
for probe_target in iphone simulator; do
    xcrun nm "$parity_dir/$probe_target-probe" > "$parity_dir/$probe_target-symbols.txt"
    "$parity_python" -B - "$parity_dir/$probe_target-symbols.txt" <<'PY'
from pathlib import Path
import re,sys
if not re.search(rb'\b[Tt]\s+_OrtGetApiBase$',Path(sys.argv[1]).read_bytes(),re.M):
    raise ValueError('The real C API is not linked in this Apple target')
print('ORT_IOS_LINKED_C_API '+Path(sys.argv[1]).name,flush=True)
PY
done
# Native Swift preprocessing receives original RGB8, never reference tensors.
# No app sources or entry points are compiled into either research executable.
for tensor_platform in iphoneos iphonesimulator; do
    tensor_sdk="$(xcrun --sdk "$tensor_platform" --show-sdk-path)"
    if [[ "$tensor_platform" = iphoneos ]]; then
        tensor_target=arm64-apple-ios26.0
    else
        tensor_target="$(uname -m)-apple-ios26.0-simulator"
    fi
    xcrun --sdk "$tensor_platform" swiftc -parse-as-library -O -sdk "$tensor_sdk" \
        -target "$tensor_target" -module-cache-path "$parity_dir/modules" \
        tools/ocr-ios-runtime-parity/tensor.swift tools/ocr-ios-runtime-parity/tensor-main.swift \
        -o "$parity_dir/tensor-$tensor_platform"
    codesign --force --sign - --timestamp=none "$parity_dir/tensor-$tensor_platform"
    xcrun vtool -show-build "$parity_dir/tensor-$tensor_platform"
done
"$parity_python" -B tools/ocr-ios-ascii-runtime-parity/compare.py --assets "$parity_dir/assets" \
    --study "$parity_dir/inputs" --runner "$parity_dir/simulator-probe" --ios "$TKPK_PARITY_IOS" \
    --transform-runner "$parity_dir/tensor-iphonesimulator"
"$parity_python" -B tools/ocr-research-receipt.py native --receipt "$parity_dir/inputs/runtime-receipt.json"
