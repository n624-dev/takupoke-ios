#!/usr/bin/env bash
set -euo pipefail

# Only our scratch directory is removed. The caller owns the final output directory.
: "${TKPK_VERSION:?Set TKPK_VERSION}"
: "${TKPK_BUILD:?Set TKPK_BUILD}"
: "${TKPK_COMMIT:?Set TKPK_COMMIT}"
output_dir="${1:?Pass an output directory}"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-build.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$output_dir" "$scratch_dir/Payload"
output_dir="$(cd "$output_dir" && pwd)"

xcodebuild -version
python3 -B tools/parallel_build.py "$scratch_dir"

app_path="$scratch_dir/DerivedData/Build/Products/Release-iphoneos/Takupoke.app"
test -f "$app_path/Info.plist"
test -x "$app_path/Takupoke"
python3 - "$app_path" <<'PYICON'
import plistlib
import sys
from pathlib import Path
app = Path(sys.argv[1])
with (app / "Info.plist").open("rb") as file:
    info = plistlib.load(file)
assert info["MinimumOSVersion"] == "26.0"
assert info["UISupportedInterfaceOrientations"] == ["UIInterfaceOrientationPortrait"]
assert info["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconName"] == "AppIcon"
assert (app / "Assets.car").is_file()
print("Verified compiled portrait setting and app icon resources.")
PYICON
# This initial app has no entitlements. Stop if capabilities are introduced
# without updating the source generation and permission checks.
if [[ -e "$app_path/embedded.mobileprovision" ]]; then
    echo 'Unexpected signing profile in unsigned app.' >&2
    exit 1
fi
/usr/bin/ditto "$app_path" "$scratch_dir/Payload/Takupoke.app"
/usr/bin/ditto -c -k --keepParent "$scratch_dir/Payload" "$output_dir/takupoke.ipa"
python3 -B tools/release.py generate \
    --ipa "$output_dir/takupoke.ipa" \
    --output "$output_dir" \
    --version "$TKPK_VERSION" \
    --build "$TKPK_BUILD" \
    --commit "$TKPK_COMMIT"
