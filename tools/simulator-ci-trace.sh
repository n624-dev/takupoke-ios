# Sourced by UI runners. This observer owns only its process and device log stream.
simulator_ci_trace_pid=""

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
