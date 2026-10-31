#!/usr/bin/env bash
# Wraps build/Pico.app in a drag-to-Applications DMG: build/Pico-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/make-dmg.sh <version>}"
APP="build/Pico.app"
DMG="build/Pico-$VERSION.dmg"
STAGE="build/dmg"

[[ -d "$APP" ]] || { echo "Run scripts/build-app.sh $VERSION first"; exit 1; }

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Pico" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

shasum -a 256 "$DMG"
