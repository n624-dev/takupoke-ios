# Sourced by UI runners. This observer owns only its process and device log stream.
simulator_ci_trace_pid=""
simulator_ci_failure_screen_attempted=0

capture_failed_simulator_screen() {
    local status="$1" device="$2" scratch="$3" test_log="${4:-}"
    if [[ "$status" != 0 && -n "$device" && "$simulator_ci_failure_screen_attempted" == 0 ]]; then
        simulator_ci_failure_screen_attempted=1
        if [[ -f "$test_log" ]] && grep -Eq '^TAKUPOKE_UI_IMAGE END simulator-failure [1-9][0-9]*$' "$test_log"; then
            return 0
        fi
        python3 -B tools/simulator_failure_screenshot.py "$device" "$scratch" || true
    fi
}

start_simulator_ci_trace() {
    python3 -B tools/simulator_ci_trace.py "$1" &
    simulator_ci_trace_pid=$!
}

stop_simulator_ci_trace() {
    if [[ -n "$simulator_ci_trace_pid" ]]; then
        kill -TERM "$simulator_ci_trace_pid" 2>/dev/null || true
        wait "$simulator_ci_trace_pid" || true
        simulator_ci_trace_pid=""
    fi
}
