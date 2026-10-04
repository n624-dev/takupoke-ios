#!/usr/bin/env bash
set -euo pipefail
probe_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
span_compiler=${SWIFTC:-swiftc}
span_scratch=$(mktemp -d "${TMPDIR:-/tmp}/takupoke-evidence-span.XXXXXXXX")
trap 'rm -rf -- "$span_scratch"' EXIT
export SPAN_SWIFT_VERSION
SPAN_SWIFT_VERSION=$("$span_compiler" --version)
"$span_compiler" "$probe_dir/EvidenceSpans.swift" "$probe_dir/main.swift" -o "$span_scratch/probe"
"$span_scratch/probe" "$probe_dir/shared-fixtures.json"
