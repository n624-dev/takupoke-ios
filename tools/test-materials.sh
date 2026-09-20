#!/usr/bin/env bash
set -euo pipefail

scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-material-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Compile the actual persistence implementation, using only synthetic data.
# All modules, executable and test copies belong to this temporary directory.
swiftc -swift-version 5 -parse-as-library \
    -module-cache-path "$scratch_dir/modules" \
    Takupoke/ChangeNormalizer.swift Takupoke/TimetableLessonNames.swift Takupoke/PDFSchoolParser.swift Takupoke/PDFDiagnostics.swift Takupoke/MaterialLibrary.swift Takupoke/WebPDFDownloader.swift \
    tests/MaterialLibraryChecks.swift tests/WebPDFChecks.swift \
    -o "$scratch_dir/checks"
"$scratch_dir/checks" "$scratch_dir/data"
