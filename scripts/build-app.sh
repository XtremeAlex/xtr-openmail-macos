#!/usr/bin/env bash
# Crea build/openmail.app dal pacchetto SwiftPM: binario release, Info.plist con il tipo
# .msg, sandbox + hardened runtime. Firma ad-hoc per default; con SIGN_IDENTITY usa un
# certificato "Developer ID Application" (poi notarizza, vedi README).
#
#   scripts/build-app.sh                 # build + test + .app firmata ad-hoc + zip
#   SIGN_IDENTITY="Developer ID Application: Nome (TEAMID)" scripts/build-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${VERSION:-1.1.0}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="$ROOT/build/openmail.app"
IDENTITY="${SIGN_IDENTITY:--}"

echo "==> Test"
swift test

echo "==> Build release"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/xtr-openmail-macos"

echo "==> Bundle $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Firma ($IDENTITY) con hardened runtime"
codesign --force --options runtime --timestamp=none \
  --entitlements packaging/openmail.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

(cd "$ROOT/build" && rm -f openmail.zip && ditto -c -k --keepParent openmail.app openmail.zip)
echo "==> Fatto: $APP e build/openmail.zip"
