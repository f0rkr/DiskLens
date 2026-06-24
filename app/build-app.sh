#!/usr/bin/env bash
# Build DiskLens into a double-clickable .app bundle.
#
# DiskLens has no external dependencies — only Apple system frameworks — so we
# compile directly with swiftc and assemble the .app bundle by hand (no SwiftPM).
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"
APP="DiskLens.app"
BIN="$APP/Contents/MacOS/DiskLens"

echo "==> Compiling (optimized)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc \
    -parse-as-library \
    -swift-version 5 \
    -O \
    -sdk "$SDK" \
    -target "$TARGET" \
    $(find Sources -name '*.swift') \
    -o "$BIN"

cp Info.plist "$APP/Contents/Info.plist"
cp DiskLens.icns "$APP/Contents/Resources/DiskLens.icns"

# Ad-hoc signature so macOS will launch it without a developer certificate.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Done: $(pwd)/$APP"
echo "    Launch with:  open \"$APP\"   (or double-click it in Finder)"
