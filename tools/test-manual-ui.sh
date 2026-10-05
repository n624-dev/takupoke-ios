#!/usr/bin/env bash
# Opt-in focused checks; root chooses when to add this to existing CI batching.
set -euo pipefail
# Exact allowlist only; the unset default still requires all three completions.
manual_case="${TKPK_MANUAL_CASE:-}"
case "$manual_case" in
    "") only_testing="-only-testing:PickerTapChecks/ManualAssistanceChecks" ;;
    testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground|testChangedOriginalCannotSubmitOrReplaceLastGood|testThreeFieldsRequireEachAcknowledgementAndFourRefuses)
        only_testing="-only-testing:PickerTapChecks/ManualAssistanceChecks/$manual_case" ;;
    *) printf '%s\n' 'Invalid manual UI case selection' >&2; exit 2 ;;
esac
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-manual-ui.XXXXXX")"
simulator_id=""
diagnostic_started="$(python3 -c 'import time; print(time.time())')"
cleanup() {
    local original_exit=$?
    # Capture before shutdown/delete, including test failure or interrupted commands.
    # Diagnostics never turn a failed/cancelled run into success.
    if [[ "${TKPK_MANUAL_DIAGNOSTICS:-0}" == 1 ]]; then
        python3 -B tools/manual_ui_diagnostics.py "$scratch_dir" "$simulator_id" "$diagnostic_started" "$original_exit" || true
    fi
    if [[ -n "$simulator_id" ]]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
    fi
    rm -rf "$scratch_dir"
    return "$original_exit"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 -B tools/manual_ui_project.py "$scratch_dir/project"
xcrun simctl list -j > "$scratch_dir/simulators.json"
python3 - "$scratch_dir/simulators.json" "${TKPK_TEST_IOS:-26}" > "$scratch_dir/destination" <<'PY'
import json,sys
s=json.load(open(sys.argv[1],encoding='utf-8')); major=int(sys.argv[2])
runtimes=[r for r in s['runtimes'] if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and int(r['version'].split('.')[0])==major]
if major not in (26,27) or not runtimes:raise SystemExit('Required iOS runtime unavailable')
runtime=max(runtimes,key=lambda r:tuple(map(int,r['version'].split('.'))))
device=next(d for d in s['devicetypes'] if d['name']=='iPhone 16')
print(device['identifier'],runtime['identifier'])
PY
read -r device_type runtime < "$scratch_dir/destination"
simulator_id="$(xcrun simctl create 'Takupoke Manual Checks' "$device_type" "$runtime")"
xcrun simctl boot "$simulator_id"
python3 -B tools/timed_command.py 'Manual simulator boot' xcrun simctl bootstatus "$simulator_id" -b
diagnostic_args=(-collect-test-diagnostics never)
if [[ "${TKPK_MANUAL_DIAGNOSTICS:-0}" == 1 ]]; then
    diagnostic_args=(-collect-test-diagnostics on-failure -resultBundlePath "$scratch_dir/ManualResults.xcresult")
fi
python3 -B tools/timed_command.py 'Manual UI checks' xcodebuild \
    -project "$scratch_dir/project/AppChecks.xcodeproj" -scheme AppChecks \
    -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$scratch_dir/DerivedData" \
    -parallel-testing-enabled NO "${diagnostic_args[@]}" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES \
    "$only_testing" test 2>&1 | tee "$scratch_dir/manual-ui.log"
python3 - "$scratch_dir/manual-ui.log" "$manual_case" <<'PY'
from collections import Counter
import re,sys
log=open(sys.argv[1],encoding='utf-8').read()
expected={'testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground','testChangedOriginalCannotSubmitOrReplaceLastGood','testThreeFieldsRequireEachAcknowledgementAndFourRefuses'}
selected=sys.argv[2]
if selected:
    if selected not in expected:raise SystemExit('Invalid manual UI case selection')
    expected={selected}
rows=re.findall(r"Test Case '-\[PickerTapChecks\.ManualAssistanceChecks (test\w+)\]' (passed|failed|skipped) \([\d.]+ seconds\)\.",log)
if Counter(name for name,_ in rows)!=Counter(expected) or any(status!='passed' for _,status in rows):raise SystemExit('Manual UI completion mismatch')
print('Verified three manual UI XCTest completions.' if not selected else 'Verified selected manual UI XCTest completion: '+selected)
PY
