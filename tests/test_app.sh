#!/bin/bash
# The menu bar app's data layer (Store.swift) against the real helper script.
cd "$(dirname "$0")/.." || exit 1
. tests/fakes.sh

T=$(mktemp -d)
trap 'chmod -R u+w "$T"; rm -rf "$T"' EXIT
mkdir -p "$T/share" "$T/state"
: > "$T/share/request"; : > "$T/share/settings"
chmod 555 "$T/share" # like the real install: your files inside a folder you can't write to
make_fakes "$T"
export FAKE="$T" MACVIBE_FAKEBIN="$T/bin" MACVIBE_SHARE="$T/share" MACVIBE_STATE="$T/state" MACVIBE_LOG="$T/log"
export MACVIBE_HELPER="$PWD/libexec/macvibe-reconcile"

if ! xcrun swiftc -swift-version 6 -target "$(uname -m)-apple-macos26.0" \
  app/Sources/Store.swift tests/app/main.swift -o "$T/storetest" 2> "$T/build.log"; then
  cat "$T/build.log"; echo "FAIL test_app.sh (build)"; exit 1
fi
out=$("$T/storetest")
if [ "$out" = ok ]; then
  echo "ok   test_app.sh (app store against the helper)"
else
  printf '%s\nFAIL test_app.sh\n' "$out"; exit 1
fi
