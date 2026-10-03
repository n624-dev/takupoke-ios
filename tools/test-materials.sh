#!/usr/bin/env bash
set -euo pipefail

scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/takupoke-material-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Compile the actual persistence implementation, using only synthetic data.
# All modules, executable and test copies belong to this temporary directory.
python3 -B tools/timed_command.py "Material compilation" swiftc -swift-version 5 -parse-as-library \
    -module-cache-path "$scratch_dir/modules" \
    Takupoke/SchoolDate.swift \
    Takupoke/SchoolDataRetention.swift \
    Takupoke/ChangeNormalizer.swift \
    Takupoke/ChangeNormalizer+Dates.swift \
    Takupoke/ChangeAnalysis.swift \
    Takupoke/TimetableLessonNames.swift \
    Takupoke/PDFSchoolParser.swift \
    Takupoke/RecoveryModels.swift \
    Takupoke/RecoveryValidator.swift \
    Takupoke/PDFAnalysis.swift \
    Takupoke/PDFParseError.swift \
    Takupoke/PDFGrid.swift \
    Takupoke/PDFSchoolParser+Timetable.swift \
    Takupoke/PDFSchoolParser+Events.swift \
    Takupoke/PDFDiagnostics.swift \
    Takupoke/PDFFullReadDiagnostic.swift \
    Takupoke/MaterialLibrary.swift \
    Takupoke/MaterialLibrary+Analysis.swift \
    Takupoke/MaterialModels.swift \
    Takupoke/MaterialLibrary+Validation.swift \
    Takupoke/WebPDFDownloader.swift \
    tests/MaterialLibraryChecks.swift tests/WebPDFChecks.swift \
    -o "$scratch_dir/checks"
python3 -B tools/timed_command.py "Material execution" "$scratch_dir/checks" "$scratch_dir/data"
