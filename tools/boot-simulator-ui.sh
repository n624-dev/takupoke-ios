#!/bin/bash
set -euo pipefail
[[ $# == 3 ]] || exit 2
simulator_id="$1"
runtime="$2"
label="$3"
[[ "$simulator_id" =~ ^[0-9A-Fa-f-]{36}$ && "$runtime" =~ ^com\.apple\.CoreSimulator\.SimRuntime\.iOS-(26|27)-[0-9]{1,2}$ ]] || exit 2
stage() { printf 'TAKUPOKE_SIMULATOR_UI stage=%s\n' "$1"; }
stage boot-enter
xcrun simctl boot "$simulator_id"
stage frontend-enter
selected_developer="${DEVELOPER_DIR:-$(xcode-select -p)}"
device_hub=""
if [[ -d "$selected_developer/Applications/Simulator.app" ]]; then
    open -a "$selected_developer/Applications/Simulator.app" --args -CurrentDeviceUDID "$simulator_id"
elif [[ -d "$selected_developer/../Applications/DeviceHub.app" ]]; then
    device_hub="${selected_developer%/*}/Applications/DeviceHub.app"
    open -a "$device_hub"
else
    printf '%s\n' 'No supported simulator frontend in the selected Xcode' >&2
    exit 1
fi
python3 -B tools/timed_command.py "$label" xcrun simctl bootstatus "$simulator_id" -b
if [[ -n "$device_hub" ]]; then
    stage window-enter
    open -a "$device_hub" "devices://device/open?id=$simulator_id"
fi
# Opening the display host is asynchronous. Observe the exact owned device;
# never issue another boot or resend a failed UI operation to rescue readiness.
stage readiness-enter
python3 -B tools/notification_service_trace.py --require-booted "$simulator_id" "$runtime"
stage ready
