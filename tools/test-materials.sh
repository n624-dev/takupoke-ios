#!/usr/bin/env bash
set -euo pipefail

exec bash tools/test-parsing.sh --filter MaterialLibraryChecks
