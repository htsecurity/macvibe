#!/bin/bash
# Builds build/MacVibe.app (no Xcode project needed, just the command line tools).
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(cd .. && pwd)
BUILD="$ROOT/build"
APP="$BUILD/MacVibe.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -swift-version 6 -parse-as-library \
  -target "$(uname -m)-apple-macos26.0" \
  -o "$APP/Contents/MacOS/MacVibe" Sources/*.swift

sed "s|__SOURCE_DIR__|$ROOT|" Info.plist > "$APP/Contents/Info.plist"

if [ ! -f "$BUILD/AppIcon.icns" ] || [ make-icon.swift -nt "$BUILD/AppIcon.icns" ]; then
  rm -rf "$BUILD/AppIcon.iconset"
  xcrun swift make-icon.swift "$BUILD/AppIcon.iconset"
  iconutil -c icns -o "$BUILD/AppIcon.icns" "$BUILD/AppIcon.iconset"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" 2>/dev/null
echo "Built $APP"
