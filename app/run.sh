#!/usr/bin/env bash
# Compile (debug) and run DiskLens straight from source — no .app bundle.
# The AppDelegate promotes the process to a regular GUI app, so a window and
# Dock icon appear even when launched this way.
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"
BIN="$(mktemp -d)/DiskLens"

echo "==> Compiling…"
swiftc \
    -parse-as-library \
    -swift-version 5 \
    -sdk "$SDK" \
    -target "$TARGET" \
    $(find Sources -name '*.swift') \
    -o "$BIN"

echo "==> Launching…"
exec "$BIN"
