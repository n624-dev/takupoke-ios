#!/usr/bin/env bash
set -euo pipefail
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-app-tests.XXXXXX")"
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
python3 -B tools/timed_command.py "App test project" python3 -B tools/app_test_project.py "$scratch_dir"
python3 - "$scratch_dir/simulators.json" "${TKPK_TEST_IOS:-}" > "$scratch_dir/destinations" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
runtimes = [r for r in s['runtimes'] if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and int(r['version'].split('.')[0]) in (26,27)]
if not runtimes: raise SystemExit('No supported iOS simulator runtime installed')
for major in ([int(sys.argv[2])] if sys.argv[2] else (27,26)):
    candidates=[r for r in runtimes if int(r['version'].split('.')[0])==major]
    if not candidates:
        if sys.argv[2]: raise SystemExit(f'Required iOS {major} runtime not installed')
        print(f'iOS {major} runtime not installed', file=sys.stderr)
        continue
    runtime=max(candidates,key=lambda r:tuple(map(int,r['version'].split('.'))))
    device=next(d for d in s['devicetypes'] if d['name']=='iPhone 16')
    print(device['identifier'],runtime['identifier'])
PY
while read -r device_type runtime; do
    simulator_id="$(xcrun simctl create 'Takupoke App Checks' "$device_type" "$runtime")"
    xcrun simctl boot "$simulator_id"
    python3 -B tools/timed_command.py "App simulator boot" xcrun simctl bootstatus "$simulator_id" -b
    xcrun simctl ui "$simulator_id" content_size large
    xcode_args=(-project "$scratch_dir/AppChecks.xcodeproj" -scheme AppChecks
        -destination "platform=iOS Simulator,id=$simulator_id"
        -derivedDataPath "$scratch_dir/DerivedData"
        -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
        -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES)
    check_ui() {
        python3 -B tools/timed_command.py "App UI $runtime" xcodebuild "${xcode_args[@]}" "$@" || {
            # Only the synthetic app runs on this isolated simulator.
            xcrun simctl spawn "$simulator_id" log show --last 10m --style compact \
                --predicate 'process == "Takupoke" AND eventMessage CONTAINS "Synthetic fixture initialization"' || true
            exit 1
        }
    }
    dynamic_checks=(TimetableCommonClocksAndEventOnlyWeekScale
        TimetableDynamicTypeScalesAndRestoresStandardLayout TimetableUsesSystemTextSize)
    only_checks=()
    skip_checks=()
    for check in "${dynamic_checks[@]}"; do
        only_checks+=("-only-testing:PickerTapChecks/ApplicationChecks/test$check")
        skip_checks+=("-skip-testing:PickerTapChecks/ApplicationChecks/test$check")
    done
    # Run the changed layout first, then the rest of the suite with the same build.
    check_ui "${only_checks[@]}" test
    check_ui "${skip_checks[@]}" test-without-building
    # Exercise the actual Simulator OS setting as well as live SwiftUI changes.
    for content_size in extra-small extra-extra-extra-large accessibility-extra-extra-extra-large; do
        xcrun simctl ui "$simulator_id" content_size "$content_size"
        app_container="$(xcrun simctl get_app_container "$simulator_id" jp.n624.takupoke.app-checks data)"
        mkdir -p "$app_container/Documents"
        printf '%s' "$content_size" > "$app_container/Documents/expected-text-size.txt"
        check_ui -only-testing:PickerTapChecks/ApplicationChecks/testTimetableUsesSystemTextSize test-without-building
    done
    xcrun simctl shutdown "$simulator_id"
    xcrun simctl delete "$simulator_id"
    simulator_id=""
done < "$scratch_dir/destinations"
