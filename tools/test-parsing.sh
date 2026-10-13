#!/usr/bin/env bash
set -euo pipefail
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-parsing-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Keep package resolution, module caches and test-generated XLSX files temporary.
# Copy only public source/fixtures; no school documents are consulted.
mkdir -p "$scratch_dir/project" "$scratch_dir/tmp"
cp Package.swift "$scratch_dir/project/"
if [[ -f Package.resolved ]]; then cp Package.resolved "$scratch_dir/project/"; fi
cp -R Takupoke tests "$scratch_dir/project/"
if [[ "$(uname -s)" == Darwin ]]; then
    python3 -m venv "$scratch_dir/fixture-python"
    "$scratch_dir/fixture-python/bin/python" -m pip install --no-cache-dir --disable-pip-version-check \
        -r tools/independent-wide-timetable/requirements.txt
    "$scratch_dir/fixture-python/bin/python" -B tools/strict_pdf_compatibility_fixtures.py \
        --output "$scratch_dir/strict-fixtures"
    export TAKUPOKE_STRICT_COMPATIBILITY_FIXTURES="$scratch_dir/strict-fixtures"
fi
extra_flags=(--jobs 2 -Xswiftc -DTAKUPOKE_INTERNAL_DIAGNOSTICS)
if [[ -n "${TKPK_ZLIB_PREFIX:-}" ]]; then
    extra_flags+=( -Xcc "-I$TKPK_ZLIB_PREFIX/usr/include" -Xlinker "-L$TKPK_ZLIB_PREFIX/usr/lib/x86_64-linux-gnu" )
fi
if [[ -n "${TAKUPOKE_STRICT_BASELINE_REF:-}" ]]; then
    # A single immutable, known working source. The exact same generated PDFs
    # and assertion-only test run through both complete production entry points.
    test "$TAKUPOKE_STRICT_BASELINE_REF" = bfc599fd5a552ced0c140497c703199547c30fd4
    test "$(uname -s)" = Darwin
    mkdir -p "$scratch_dir/baseline"
    git archive "$TAKUPOKE_STRICT_BASELINE_REF" Package.swift Package.resolved Takupoke tests \
        | tar -x -C "$scratch_dir/baseline"
    cp tests/StrictPDFCompatibilityTests.swift "$scratch_dir/baseline/tests/"
    python3 -B - "$scratch_dir/baseline/Package.swift" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = '"PDFParsingTests.swift",'
if source.count(needle) != 1:
    raise SystemExit("Baseline package registration changed")
path.write_text(source.replace(needle, needle+' "StrictPDFCompatibilityTests.swift",'))
PY
    TMPDIR="$scratch_dir/tmp" CLANG_MODULE_CACHE_PATH="$scratch_dir/baseline-modules" \
    SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/baseline-modules" \
    python3 -B tools/timed_command.py "239.1 full Strict compatibility baseline" \
        swift test --package-path "$scratch_dir/baseline" --scratch-path "$scratch_dir/baseline-build" \
        --cache-path "$scratch_dir/baseline-cache" --config-path "$scratch_dir/baseline-config" \
        --security-path "$scratch_dir/baseline-security" --disable-dependency-cache --manifest-cache none \
        --filter StrictPDFCompatibilityTests "${extra_flags[@]}"
fi
TMPDIR="$scratch_dir/tmp" CLANG_MODULE_CACHE_PATH="$scratch_dir/modules" \
SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/modules" \
python3 -B tools/timed_command.py "Swift package build and tests" swift test --package-path "$scratch_dir/project" \
    --scratch-path "$scratch_dir/build" --cache-path "$scratch_dir/cache" \
    --config-path "$scratch_dir/config" --security-path "$scratch_dir/security" \
    --disable-dependency-cache --manifest-cache none "${extra_flags[@]}"
