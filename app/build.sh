#!/bin/bash
# Builds build/MacVibe.app, a universal app (Apple silicon + Intel). Needs Xcode or the
# Command Line Tools with the macOS 26+ SDK. MACVIBE_SOURCE_DIR= (empty) builds a release app
# that doesn't remember where its source folder was.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(cd .. && pwd)
BUILD="$ROOT/build"
APP="$BUILD/MacVibe.app"
SOURCE_DIR=${MACVIBE_SOURCE_DIR-$ROOT}
VERSION=$(cat "$ROOT/VERSION")

rm -rf "$APP" "$BUILD/arch"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/arch"

for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 6 -parse-as-library \
    -target "$arch-apple-macos26.0" \
    -o "$BUILD/arch/MacVibe-$arch" Sources/*.swift
done
lipo -create -output "$APP/Contents/MacOS/MacVibe" "$BUILD/arch/MacVibe-arm64" "$BUILD/arch/MacVibe-x86_64"

sed -e "s|__SOURCE_DIR__|$SOURCE_DIR|" -e "s|__VERSION__|$VERSION|" Info.plist > "$APP/Contents/Info.plist"

if [ ! -f "$BUILD/AppIcon.icns" ] || [ make-icon.swift -nt "$BUILD/AppIcon.icns" ]; then
  rm -rf "$BUILD/AppIcon.iconset"
  xcrun swift make-icon.swift "$BUILD/AppIcon.iconset"
  iconutil -c icns -o "$BUILD/AppIcon.icns" "$BUILD/AppIcon.iconset"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" 2>/dev/null
echo "Built $APP ($VERSION)"
