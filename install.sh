#!/bin/bash
# Install or update MacVibe:   sudo ./install.sh
# Remove it completely:        sudo ./install.sh --uninstall
set -euo pipefail
cd "$(dirname "$0")"

LABEL=com.macvibe.reconcile
PLIST=/Library/LaunchDaemons/$LABEL.plist
HELPER=/Library/PrivilegedHelperTools/macvibe
BIN=/usr/local/bin/macvibe
SHARE="/Library/Application Support/macvibe"
STATE=/var/db/macvibe
LOG=/var/log/macvibe.log
APP=/Applications/MacVibe.app

say() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "Run it with sudo:  sudo ./install.sh"
USER_NAME=${SUDO_USER:-}
[ -n "$USER_NAME" ] && [ "$USER_NAME" != root ] || die "Run it from your own account with sudo, not as root."
USER_UID=$(id -u "$USER_NAME")

is_our_app() {
  [ "$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null)" = com.macvibe.app ]
}

uninstall() {
  say "Removing MacVibe"
  launchctl bootout system/$LABEL 2>/dev/null || true
  pmset -a disablesleep 0
  saved=$(awk -F= '$1 == "lpm_saved" { print $2 }' "$STATE/state" 2>/dev/null || true)
  if [ -n "$saved" ]; then pmset -b lowpowermode "$saved"; fi
  pkill -x MacVibe 2>/dev/null || true
  if is_our_app; then rm -rf "$APP"; fi
  rm -rf "$PLIST" "$HELPER" "$BIN" "$SHARE" "$STATE"
  say "Done. Your Mac sleeps normally again (log kept at $LOG)."
}

if [ "${1:-}" = --uninstall ]; then uninstall; exit 0; fi
[ -z "${1:-}" ] || die "Unknown option: $1"
if [ -e "$APP" ] && ! is_our_app; then die "$APP exists and isn't MacVibe; not touching it."; fi

# The menu bar app needs macOS 26 (Liquid Glass). The helper and CLI work on older versions.
MACOS=$(sw_vers -productVersion)
APP_SRC=""
if [ "${MACOS%%.*}" -lt 26 ]; then
  say "macOS $MACOS: the menu bar app needs macOS 26 or later; installing the helper and the macvibe command"
elif [ -d MacVibe.app ]; then
  APP_SRC=MacVibe.app # release download: prebuilt
elif xcode-select -p >/dev/null 2>&1 && xcrun --find swiftc >/dev/null 2>&1; then
  say "Building the MacVibe app (as $USER_NAME)"
  sudo -H -u "$USER_NAME" ./app/build.sh
  APP_SRC=build/MacVibe.app
else
  die "Building from source needs Xcode or the Command Line Tools (run: xcode-select --install).
       Or download the ready-made release: https://github.com/htsecurity/macvibe/releases/latest"
fi

say "Installing the background helper"
install -d -o root -g wheel -m 755 "$HELPER" "$STATE" "$SHARE"
[ -d /usr/local/bin ] || install -d -o root -g wheel -m 755 /usr/local/bin
install -o root -g wheel -m 755 libexec/macvibe-reconcile "$HELPER/reconcile"
install -o root -g wheel -m 644 lib/core.sh "$HELPER/core.sh"
install -o root -g wheel -m 755 bin/macvibe "$BIN"
for f in request settings; do
  # Only regular files you own: the helper reads them as root.
  if [ -L "$SHARE/$f" ] || { [ -e "$SHARE/$f" ] && [ ! -f "$SHARE/$f" ]; }; then rm -f "$SHARE/$f"; fi
  [ -f "$SHARE/$f" ] || : > "$SHARE/$f"
  chown "$USER_NAME":staff "$SHARE/$f"
  chmod 644 "$SHARE/$f"
done
touch "$LOG" && chown root:wheel "$LOG" && chmod 644 "$LOG"
install -o root -g wheel -m 644 launchd/$LABEL.plist "$PLIST"

launchctl bootout system/$LABEL 2>/dev/null || true
for _ in 1 2 3 4 5; do # bootout finishes asynchronously
  if launchctl bootstrap system "$PLIST" 2>/dev/null; then break; fi
  sleep 1
done
launchctl print system/$LABEL >/dev/null 2>&1 || die "The helper did not start. See: launchctl print system/$LABEL"

if [ -n "$APP_SRC" ]; then
  say "Installing the app"
  pkill -x MacVibe 2>/dev/null || true
  rm -rf "$APP"
  ditto "$APP_SRC" "$APP"
  # Downloaded releases are ad-hoc signed, not notarized: clear the download flag so it opens.
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  chown -R "$USER_NAME":staff "$APP"
  launchctl asuser "$USER_UID" sudo -u "$USER_NAME" open "$APP" || true
fi

for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$STATE/status" ] && break; sleep 0.5; done
[ -f "$STATE/status" ] || die "The helper is installed but hasn't reported. See: macvibe log"

cat <<EOF

$(say "MacVibe is installed")
  • Menu bar: click the cup icon (top right of your screen).
  • Terminal:  macvibe on    (stay awake with the lid closed while agents work)
               macvibe status
               macvibe off
  • Remove:    sudo ./install.sh --uninstall

EOF
