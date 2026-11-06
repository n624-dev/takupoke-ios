#!/bin/bash
set -euo pipefail
[[ $# == 3 ]] || exit 2
simulator_id="$1"
runtime="$2"
label="$3"
[[ "$simulator_id" =~ ^[0-9A-Fa-f-]{36}$ && "$runtime" =~ ^com\.apple\.CoreSimulator\.SimRuntime\.iOS-(26|27)-[0-9]{1,2}$ ]] || exit 2
stage() { printf 'TAKUPOKE_SIMULATOR_UI stage=%s\n' "$1"; }
identity_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-ui-identity.XXXXXX")"
trap 'rm -rf "$identity_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
stage identity-build-enter
sim_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
python3 -B tools/timed_command.py --timeout 120 --cleanup-grace 3 'Simulator identity build' \
    xcrun --sdk iphonesimulator swiftc -sdk "$sim_sdk" \
    -target "$(uname -m)-apple-ios26.0-simulator" -module-cache-path "$identity_dir/modules" \
    tools/simulator-ui-identity.swift -o "$identity_dir/identity"
codesign --force --sign - --timestamp=none "$identity_dir/identity"
stage identity-build-complete
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
# Prove the exact owned device by one real native process, independently of the
# all-device inventory API. Never reboot or resend an input to rescue readiness.
stage readiness-enter
python3 -B tools/notification_service_trace.py --require-booted "$simulator_id" "$runtime" "$identity_dir/identity"
stage ready
