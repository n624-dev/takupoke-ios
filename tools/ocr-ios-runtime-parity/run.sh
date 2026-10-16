#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
: "${TKPK_PARITY_IOS:?Require an explicit supported iOS major}"
parity_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/takupoke-ios-onnx.XXXXXX")"
trap 'rm -rf "$parity_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -m venv "$parity_dir/python"
parity_python="$parity_dir/python/bin/python"
"$parity_python" -m pip install --no-cache-dir --disable-pip-version-check -r tools/ocr-windows-transfer/requirements.txt
"$parity_python" -B -m unittest discover -s tests -p test_ocr_ios_runtime_parity.py -v
"$parity_python" -B tools/ocr-ios-runtime-parity/prepare.py "$parity_dir/assets"
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
    -F "$device_framework" tools/ocr-ios-runtime-parity/runner.cpp \
    "${framework_args[@]}" -o "$parity_dir/iphone-probe"
xcrun --sdk iphonesimulator clang++ -std=c++17 -O2 -target "$(uname -m)-apple-ios26.0-simulator" \
    -isysroot "$sim_sdk" -I "$sim_framework/onnxruntime.framework/Headers" \
    -F "$sim_framework" tools/ocr-ios-runtime-parity/runner.cpp \
    "${framework_args[@]}" -o "$parity_dir/simulator-probe"
codesign --force --sign - --timestamp=none "$parity_dir/simulator-probe"
xcrun vtool -show-build "$parity_dir/iphone-probe"
xcrun vtool -show-build "$parity_dir/simulator-probe"
"$parity_python" -B tools/ocr-ios-runtime-parity/compare.py --assets "$parity_dir/assets" \
    --study "$parity_dir/inputs" --runner "$parity_dir/simulator-probe" --ios "$TKPK_PARITY_IOS"
