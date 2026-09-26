#!/bin/bash
# Builds dist/MacVibe.zip: the prebuilt universal app plus installer and helper, so users
# can install without Xcode.   scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

./check.sh
MACVIBE_SOURCE_DIR= app/build.sh # relocatable: no path from this Mac inside the app

rm -rf dist
mkdir -p dist/MacVibe
ditto build/MacVibe.app dist/MacVibe/MacVibe.app
cp -R bin lib libexec launchd install.sh README.md LICENSE VERSION dist/MacVibe/
(cd dist && ditto -c -k --keepParent MacVibe MacVibe.zip && shasum -a 256 MacVibe.zip > MacVibe.zip.sha256)

echo "Release $(cat VERSION):"
ls -l dist/MacVibe.zip
cat dist/MacVibe.zip.sha256
