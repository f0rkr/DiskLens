#!/usr/bin/env bash
#
# Run the DiskLens test suite (swift-testing).
#
# On a full Xcode install, `swift test` already finds the Testing framework.
# On a Command Line Tools–only setup it ships in a non-default location, so we
# point the compiler & linker at it. This script auto-detects which case you're
# in, so the same command works everywhere — locally and in CI.
#
#   ./run-tests.sh                 # run everything
#   ./run-tests.sh --filter Squarify
#
set -euo pipefail
cd "$(dirname "$0")"

DEV="$(xcode-select -p)"
FW="$DEV/Library/Developer/Frameworks"
INTEROP="$DEV/Library/Developer/usr/lib"

if [[ "$DEV" == *CommandLineTools* && -d "$FW/Testing.framework" ]]; then
  echo "▸ Command Line Tools detected — injecting swift-testing framework path"
  exec swift test \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$INTEROP" \
    "$@"
else
  exec swift test "$@"
fi
