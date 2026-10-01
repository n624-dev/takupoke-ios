#!/usr/bin/env bash
set -euo pipefail
# Scratch directory belongs to build-ios.sh.
scratch_dir="${1:?Pass the build scratch directory}"
python3 -B tools/timed_command.py "Material tests" bash tools/test-materials.sh
python3 -B tools/timed_command.py "Parsing tests" bash tools/test-parsing.sh
python3 -B tools/timed_command.py "iPhone Release build" xcodebuild \
    -project Takupoke.xcodeproj \
    -scheme Takupoke \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$scratch_dir/DerivedData" \
    -clonedSourcePackagesDirPath "$scratch_dir/SourcePackages" \
    -packageCachePath "$scratch_dir/PackageCache" \
    -disablePackageRepositoryCache \
    -onlyUsePackageVersionsFromResolvedFile \
    -showBuildTimingSummary \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    MARKETING_VERSION="$TKPK_VERSION" \
    CURRENT_PROJECT_VERSION="$TKPK_BUILD" \
    TAKUPOKE_COMMIT="$TKPK_COMMIT" \
    build
