#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/photolite_flutter/build/macos/Build/Products/Release/PhotoLite.app"
RELEASE_DIR="$ROOT_DIR/release"
DMG_PATH="$RELEASE_DIR/PhotoLite-macOS-release.dmg"
DMG_STAGE="$(mktemp -d /tmp/photolite-dmg.XXXXXX)"
trap 'rm -rf "$DMG_STAGE"' EXIT

mkdir -p "$RELEASE_DIR"
(cd "$ROOT_DIR/photolite_flutter" && flutter build macos --release)

cp -R "$APP_DIR" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "PhotoLite" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
echo "$DMG_PATH"
