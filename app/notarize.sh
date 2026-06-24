#!/usr/bin/env bash
# Sign + notarize + staple DiskLens so it opens with no Gatekeeper warning.
#
# PREREQUISITES (one-time):
#   1. Apple Developer Program membership ($99/yr).
#   2. A "Developer ID Application" certificate installed in your login keychain.
#      (Keychain Access → Certificate Assistant → request a CSR → upload at
#       developer.apple.com → download the cert → double-click to install.)
#   3. Stored notary credentials:
#        xcrun notarytool store-credentials "disklens-notary" \
#          --apple-id "you@example.com" --team-id "TEAMID" \
#          --password "app-specific-password"
#
# Find your signing identity name with:  security find-identity -v -p codesigning
set -euo pipefail
cd "$(dirname "$0")"

# ---- CONFIG: fill these in ----
DEV_ID="Developer ID Application: YOUR NAME (TEAMID)"   # exact string from find-identity
KEYCHAIN_PROFILE="disklens-notary"                       # the name you used above
APP="DiskLens.app"
ZIP="DiskLens-macOS-arm64.zip"
# --------------------------------

[ -d "$APP" ] || { echo "Build the app first: ./build-app.sh"; exit 1; }

echo "==> Signing with Hardened Runtime + secure timestamp…"
# Sign inner binary first, then the bundle (inside-out).
codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP/Contents/MacOS/DiskLens"
codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP"

echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Zipping for notarization…"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service (waits for result)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "==> Stapling the ticket to the app…"
xcrun stapler staple "$APP"

echo "==> Final Gatekeeper check (should say: accepted / Notarized Developer ID)…"
spctl -a -vvv -t install "$APP" || true

echo "==> Re-zipping the stapled app for distribution…"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Done. Ship $ZIP — it now opens with no warning, even offline."
