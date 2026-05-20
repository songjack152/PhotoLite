#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/photolite_flutter"
RELEASE_DIR="$ROOT_DIR/release"
APK_SOURCE="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
APK_TARGET="$RELEASE_DIR/PhotoLite-Android-debug.apk"

mkdir -p "$RELEASE_DIR"
cd "$APP_DIR"
flutter build apk --debug
cp "$APK_SOURCE" "$APK_TARGET"
echo "$APK_TARGET"
