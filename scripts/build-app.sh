#!/usr/bin/env bash
# Builds Pico.app from the Swift package. No Xcode needed, only the Command Line Tools.
#
#   scripts/build-app.sh            # debug build, current architecture → build/Pico.app
#   scripts/build-app.sh 0.1.0      # release build, universal (arm64 + x86_64), version 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
APP="build/Pico.app"

if [[ -n "$VERSION" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN=".build/apple/Products/Release/Pico"
else
  VERSION="0.0.0"
  swift build
  BIN=".build/debug/Pico"
fi
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pico"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Ad-hoc signature: enough for Apple Silicon to run the app. Replace `-` with a Developer ID
# identity (and notarize) once there is an Apple Developer account.
codesign --force --sign "${CODESIGN_IDENTITY:--}" --options runtime --timestamp=none "$APP"

echo "Built $APP (version $VERSION, build $BUILD_NUMBER)"
