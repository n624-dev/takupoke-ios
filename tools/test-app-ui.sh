#!/usr/bin/env bash
set -euo pipefail
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-app-tests.XXXXXX")"
simulator_id=""
collect_launch_trace() {
    python3 -B - "$simulator_id" <<'PY_TRACE'
from pathlib import Path
import re, subprocess, sys
try:
    result = subprocess.run(["xcrun", "simctl", "get_app_container", sys.argv[1], "jp.n624.takupoke.app-checks", "data"],
                            capture_output=True, text=True, timeout=10)
    if result.returncode == 0:
        owned = Path(result.stdout.strip()) / "tmp/takupoke-fictional-launch-owned.log"
        if not owned.is_symlink() and owned.is_file() and owned.stat().st_size <= 65536:
            pattern = re.compile(r"TAKUPOKE_LIFECYCLE pid=\d+ time=\d+(?:\.\d+)? stage=(?:init-enter|seed-enter|seed-complete|scene-construction|content-appeared|root-task-enter|application-ready|fixture-ready|fixture-ready-timeout|notification-settings-enter|notification-settings-complete|notification-settings-cancelled|notification-on-binding|notification-off-binding|notification-settings-request|notification-settings-callback|notification-reconcile-request|notification-reconcile-callback)")
            switch = re.compile(r"TAKUPOKE_AI_SWITCH pid=\d+ time=\d+(?:\.\d+)? phase=(?:before|after) requested=[01] stored=[01]")
            for line in owned.read_text(encoding="utf-8").splitlines():
                if pattern.fullmatch(line) or switch.fullmatch(line): print(line)
        else:
            print("TAKUPOKE_LIFECYCLE capture-missing-or-limited")
    else:
        print("TAKUPOKE_LIFECYCLE capture-unavailable")
except (OSError, ValueError, subprocess.TimeoutExpired):
    print("TAKUPOKE_LIFECYCLE capture-unavailable")
PY_TRACE
}
cleanup() {
    local task_exit_status=$?
    if [[ -n "$simulator_id" ]]; then
        collect_launch_trace || true
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
    fi
    rm -rf "$scratch_dir"
    return "$task_exit_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun simctl list -j > "$scratch_dir/simulators.json"
shard="${TKPK_UI_SHARD:-all}"
selection_args=(--shard "$shard")
case "${TKPK_UI_RELAUNCH_PROBE:-0}" in
    0) ;;
    1) selection_args+=(--relaunch-probe) ;;
    *) exit 2 ;;
esac
if [[ "${TKPK_UI_PROBE_CASE:-all}" != "all" ]]; then
    selection_args+=(--probe-case "$TKPK_UI_PROBE_CASE")
fi
python3 -B tools/ui_test_manifest.py "${selection_args[@]}" --mode selectors > "$scratch_dir/selectors"
system_size_check="$(python3 -B tools/ui_test_manifest.py "${selection_args[@]}" --mode system-size)"
selected_checks=()
while IFS= read -r selector; do selected_checks+=("$selector"); done < "$scratch_dir/selectors"
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
    ios_major="${runtime##*.iOS-}"
    ios_major="${ios_major%%-*}"
    project_dir="$scratch_dir/ios-$ios_major"
    mkdir -p "$project_dir"
    voiceover="0"
    if [[ "$ios_major" == "27" ]]; then voiceover="1"; fi
    TKPK_VOICEOVER_AUTOMATION="$voiceover" python3 -B tools/timed_command.py "App test project iOS $ios_major" \
        python3 -B tools/app_test_project.py "$project_dir"
    bash tools/resolve-xcode-packages.sh "$project_dir/AppChecks.xcodeproj" AppChecks "$scratch_dir"
    simulator_id="$(xcrun simctl create 'Takupoke App Checks' "$device_type" "$runtime")"
    xcrun simctl boot "$simulator_id"
    python3 -B tools/timed_command.py "App simulator boot" xcrun simctl bootstatus "$simulator_id" -b
    xcrun simctl ui "$simulator_id" content_size large
    xcode_args=(-project "$project_dir/AppChecks.xcodeproj" -scheme AppChecks
        -destination "platform=iOS Simulator,id=$simulator_id"
        -derivedDataPath "$scratch_dir/DerivedData"
        -clonedSourcePackagesDirPath "$scratch_dir/SourcePackages" -packageCachePath "$scratch_dir/PackageCache"
        -disablePackageRepositoryCache -onlyUsePackageVersionsFromResolvedFile -disableAutomaticPackageResolution
        -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
        -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES)
    check_ui() {
        local log_path="$1"
        shift
        python3 -B tools/timed_command.py "App UI $runtime shard $shard" xcodebuild "${xcode_args[@]}" "$@" 2>&1 | tee "$log_path" || {
            # Only the synthetic app runs on this isolated simulator.
            xcrun simctl spawn "$simulator_id" log show --last 10m --style compact \
                --predicate 'process == "Takupoke" AND eventMessage CONTAINS "Synthetic fixture initialization"' || true
            exit 1
        }
    }
    check_ui "$scratch_dir/suite.log" "${selected_checks[@]}" test
    python3 -B tools/ui_test_manifest.py "${selection_args[@]}" --mode verify --ios "$ios_major" --log "$scratch_dir/suite.log"
    # Exercise the actual Simulator OS setting as well as live SwiftUI changes.
    if [[ "$system_size_check" == "1" ]]; then
        for content_size in extra-small extra-extra-extra-large accessibility-extra-extra-extra-large; do
            xcrun simctl ui "$simulator_id" content_size "$content_size"
            app_container="$(xcrun simctl get_app_container "$simulator_id" jp.n624.takupoke.app-checks data)"
            mkdir -p "$app_container/Documents"
            printf '%s' "$content_size" > "$app_container/Documents/expected-text-size.txt"
            check_ui "$scratch_dir/os-size.log" -only-testing:PickerTapChecks/ApplicationChecks/testTimetableUsesSystemTextSize test-without-building
            python3 -B tools/ui_test_manifest.py --shard "$shard" --mode verify --ios "$ios_major" --log "$scratch_dir/os-size.log" --system-size-only
        done
    fi
    collect_launch_trace
    xcrun simctl shutdown "$simulator_id"
    xcrun simctl delete "$simulator_id"
    simulator_id=""
done < "$scratch_dir/destinations"
