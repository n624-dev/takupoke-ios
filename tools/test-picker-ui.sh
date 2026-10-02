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
python3 -B tools/picker_test_project.py "$scratch_dir"
xcrun simctl boot "$simulator_id"
python3 -B tools/timed_command.py "Picker simulator boot" xcrun simctl bootstatus "$simulator_id" -b
set +e
python3 -B tools/timed_command.py "Picker UI" xcodebuild -project "$scratch_dir/PickerChecks.xcodeproj" -scheme PickerChecks \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$scratch_dir/DerivedData" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -collect-test-diagnostics never \
    CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
ui_status=$?
set -e
app_data="$(xcrun simctl get_app_container "$simulator_id" jp.n624.takupoke.picker-checks data)"
for trace_path in "$app_data"/Documents/trace-*.txt; do
    if [[ -f "$trace_path" ]]; then cat "$trace_path"; fi
done
if [[ "$ui_status" != 0 ]]; then exit "$ui_status"; fi
# Retain the existing transition and geometry checks, then remove everything.
xcrun simctl terminate "$simulator_id" jp.n624.takupoke.picker-checks >/dev/null 2>&1 || true
rm -f "$app_data/Documents/result.txt"
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
