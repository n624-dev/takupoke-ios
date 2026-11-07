#!/bin/bash
set -euo pipefail
[[ $# == 3 ]] || exit 2
simulator_id="$1"
runtime="$2"
label="$3"
[[ "$simulator_id" =~ ^[0-9A-Fa-f-]{36}$ && "$runtime" =~ ^com\.apple\.CoreSimulator\.SimRuntime\.iOS-(26|27)-[0-9]{1,2}$ ]] || exit 2
frontend_mode="${TKPK_SIMULATOR_FRONTEND:-gui}"
case "$frontend_mode" in gui|headless) ;; *) exit 2 ;; esac
stage() { printf 'TAKUPOKE_SIMULATOR_UI stage=%s\n' "$1"; }
stage boot-enter
xcrun simctl boot "$simulator_id"
device_hub=""
if [[ "$frontend_mode" == gui ]]; then
    stage frontend-enter
    selected_developer="${DEVELOPER_DIR:-$(xcode-select -p)}"
    if [[ -d "$selected_developer/Applications/Simulator.app" ]]; then
        open -a "$selected_developer/Applications/Simulator.app" --args -CurrentDeviceUDID "$simulator_id"
    elif [[ -d "$selected_developer/../Applications/DeviceHub.app" ]]; then
        device_hub="${selected_developer%/*}/Applications/DeviceHub.app"
        open -a "$device_hub"
    else
        printf '%s\n' 'No supported simulator frontend in the selected Xcode' >&2
        exit 1
    fi
else
    # XCTest drives the guest display directly; the desktop viewer is optional.
    # The same native proof and every actual UI test are still required.
    stage frontend-headless
fi
python3 -B tools/timed_command.py "$label" xcrun simctl bootstatus "$simulator_id" -b
if [[ -n "$device_hub" ]]; then
    stage window-enter
    open -a "$device_hub" "devices://device/open?id=$simulator_id"
fi
# Each required XCTest case records its actual guest Runner identity. The caller
# verifies all of those records against this owned UUID/runtime and case list.
stage bootstatus-complete
