#!/usr/bin/env bash
# Retry dependency acquisition only. UI tests/build assertions are never retried.
set -euo pipefail
project="${1:?Pass an owned test project}"
scheme="${2:?Pass its scheme}"
scratch_dir="${3:?Pass the caller-owned scratch directory}"
status=1
for attempt in 1 2 3; do
    printf 'Resolve pinned Xcode packages: attempt %s/3\n' "$attempt"
    if xcodebuild -resolvePackageDependencies -project "$project" -scheme "$scheme" \
        -derivedDataPath "$scratch_dir/DerivedData" \
        -clonedSourcePackagesDirPath "$scratch_dir/SourcePackages" \
        -packageCachePath "$scratch_dir/PackageCache" \
        -disablePackageRepositoryCache -onlyUsePackageVersionsFromResolvedFile; then
        exit 0
    else
        status=$?
    fi
    if [[ "$status" == 130 || "$status" == 143 ]]; then exit "$status"; fi
done
exit "$status"
