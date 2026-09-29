#!/usr/bin/env bash
set -euo pipefail
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-picker-tests.XXXXXX")"
simulator_id=""
cleanup() {
    if [[ -n "$simulator_id" ]]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
    fi
    rm -rf "$scratch_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun simctl list -j > "$scratch_dir/simulators.json"
read -r device_type runtime < <(python3 - "$scratch_dir/simulators.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
runtimes = [r for r in s['runtimes'] if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
runtime = max(runtimes, key=lambda r: tuple(map(int, r['version'].split('.'))))
devices = [d for d in s['devicetypes'] if d['name'] == 'iPhone 16']
print(devices[0]['identifier'], runtime['identifier'])
PY
)
simulator_id="$(xcrun simctl create "Takupoke Picker Checks" "$device_type" "$runtime")"
app_dir="$scratch_dir/PickerChecks.app"
mkdir -p "$app_dir"
cat > "$app_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>jp.n624.takupoke.picker-checks</string>
<key>CFBundleExecutable</key><string>PickerChecks</string>
<key>CFBundleName</key><string>PickerChecks</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>16.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>
</dict></plist>
PLIST
xcrun --sdk iphonesimulator swiftc -swift-version 5 -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -target "$(uname -m)-apple-ios16.0-simulator" \
    -module-cache-path "$scratch_dir/modules" \
    Takupoke/GuidedDocumentPicker.swift Takupoke/MaterialPickerLayout.swift Takupoke/MaterialDocumentPicker.swift Takupoke/ScopedMaterialSelection.swift tests/ui/MaterialPickerUIChecks.swift \
    -o "$app_dir/PickerChecks"
codesign --force --sign - "$app_dir"
xcrun simctl boot "$simulator_id"
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" "$app_dir"
xcrun simctl launch --stdout="$scratch_dir/stdout.log" --stderr="$scratch_dir/stderr.log" "$simulator_id" jp.n624.takupoke.picker-checks
app_data="$(xcrun simctl get_app_container "$simulator_id" jp.n624.takupoke.picker-checks data)"
for ((attempt = 0; attempt < 180; attempt++)); do
    if [[ -f "$app_data/Documents/result.txt" ]]; then
        cat "$app_data/Documents/result.txt"
        if [[ -f "$scratch_dir/stdout.log" ]]; then cat "$scratch_dir/stdout.log"; fi
        if [[ "$(cat "$app_data/Documents/result.txt")" == PASS:* ]]; then exit 0; fi
        if [[ -f "$scratch_dir/stderr.log" ]]; then tail -30 "$scratch_dir/stderr.log"; fi
        exit 1
    fi
    sleep 1
done
echo "Picker UI checks timed out" >&2
if [[ -f "$app_data/Documents/progress.txt" ]]; then cat "$app_data/Documents/progress.txt"; fi
if [[ -f "$scratch_dir/stderr.log" ]]; then tail -50 "$scratch_dir/stderr.log"; fi
xcrun simctl spawn "$simulator_id" log show --last 5m --style compact --predicate 'process == "PickerChecks"' | tail -50
exit 1
