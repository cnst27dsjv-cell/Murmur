#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-cache/swiftpm"
APP_DIR="$ROOT_DIR/dist/Murmur.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

HOME="$ROOT_DIR/.build-cache/home" \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build-cache/clang" \
swift build --disable-sandbox --scratch-path "$BUILD_DIR"

cp "$BUILD_DIR/debug/MurmurApp" "$MACOS_DIR/MurmurApp"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$RESOURCES_DIR/Pets"
cp -R "$ROOT_DIR/Resources/Pets" "$RESOURCES_DIR/Pets"
rm -rf "$RESOURCES_DIR/Animations"
cp -R "$ROOT_DIR/Resources/Animations" "$RESOURCES_DIR/Animations"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/MurmurApp"
xattr -cr "$APP_DIR" >/dev/null 2>&1 || true

echo "Created $APP_DIR"
