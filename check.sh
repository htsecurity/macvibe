#!/bin/bash
# All quality gates: syntax, plists, tests, and the app build.  ./check.sh [--no-app]
set -u
cd "$(dirname "$0")"
fail=0

for f in bin/macvibe libexec/macvibe-reconcile lib/core.sh install.sh app/build.sh tests/*.sh; do
  /bin/bash -n "$f" || { echo "syntax error: $f"; fail=1; }
done
if command -v shellcheck >/dev/null; then
  shellcheck -s bash bin/macvibe libexec/macvibe-reconcile lib/core.sh install.sh app/build.sh || fail=1
fi
plutil -lint -s launchd/*.plist app/Info.plist || fail=1

for t in tests/test_*.sh; do
  [ "$t" = tests/test_app.sh ] && [ "${1:-}" = --no-app ] && continue # needs the macOS 26 SDK
  /bin/bash "$t" || fail=1
done

if [ "${1:-}" != --no-app ]; then
  app/build.sh >/dev/null && echo "ok   app build" || { echo "FAIL app build"; fail=1; }
fi

[ "$fail" = 0 ] && echo "All checks passed." || echo "Some checks FAILED."
exit "$fail"
