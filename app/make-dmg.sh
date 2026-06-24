#!/usr/bin/env bash
# Package DiskLens.app into a distributable .dmg with a drag-to-Applications layout.
set -euo pipefail
cd "$(dirname "$0")"

APP="DiskLens.app"
DMG="DiskLens.dmg"
VOL="DiskLens"

if [ ! -d "${APP}" ]; then echo "Build the app first: ./build-app.sh"; exit 1; fi

echo "==> Staging..."
STAGING="$(mktemp -d)"
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"   # drag target

echo "==> Creating ${DMG} ..."
rm -f "${DMG}"
hdiutil create -volname "${VOL}" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}" >/dev/null

rm -rf "${STAGING}"
echo "==> Done: $(pwd)/${DMG} ($(du -h "${DMG}" | cut -f1))"
