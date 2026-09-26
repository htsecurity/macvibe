#!/bin/bash
# The `macvibe` command: writes requests/settings, reads status.
cd "$(dirname "$0")/.." || exit 1
. tests/helpers.sh

T=$(mktemp -d)
trap 'chmod -R u+w "$T"; rm -rf "$T"' EXIT
mkdir -p "$T/share" "$T/state"
: > "$T/share/request"; : > "$T/share/settings"
chmod 555 "$T/share" # like the real install: your files inside a folder you can't write to
export MACVIBE_SHARE="$T/share" MACVIBE_STATE="$T/state" MACVIBE_WAIT=0
BOOT=$(sysctl -n kern.boottime | sed -n 's/^{ sec = \([0-9]*\),.*/\1/p')
cli() { bin/macvibe "$@" 2>&1; }
req() { kv "$1" "$(cat "$T/share/request")"; }
set_() { kv "$1" "$(cat "$T/share/settings")"; }

cli on >/dev/null
assert_eq "on: auto mode" auto "$(req mode)"
assert_eq "on: current boot" "$BOOT" "$(req boot)"
assert_contains "on: since is a timestamp" "17" "$(req since)"

cli on --forever >/dev/null
assert_eq "on --forever" forever "$(req mode)"

cli off >/dev/null
assert_eq "off" off "$(req mode)"

printf 'max_temp=40\n' > "$T/share/settings"
cli set min-battery 30 >/dev/null
assert_eq "set min-battery" 30 "$(set_ min_battery)"
assert_eq "set keeps other settings" 40 "$(set_ max_temp)"
cli set idle 25 >/dev/null
assert_eq "set idle" 25 "$(set_ idle_minutes)"
cli set low-power off >/dev/null
assert_eq "set low-power off" 0 "$(set_ low_power)"

out=$(cli set max-temp 99); code=$?
assert_eq "out of range is rejected" 2 "$code"
assert_contains "range is explained" "35" "$out"
assert_eq "rejected value not saved" 40 "$(set_ max_temp)"

out=$(cli set colour blue); code=$?
assert_eq "unknown setting is rejected" 2 "$code"

out=$(cli status)
assert_contains "status without helper says how to install" "sudo ./install.sh" "$out"

now=$(date +%s)
cat > "$T/state/status" <<EOF
updated=$now
session=1
mode=auto
requested=auto
active=1
lid=closed
power=battery
charging=0
battery=81
temp=33.9
thermal=nominal
agents_busy=2
agents_total=6
idle_left=-1
lowpower_active=1
min_battery=20
max_temp=42
idle_minutes=15
low_power=1
event=Battery at 20%
event_time=$now
EOF
out=$(cli status)
assert_contains "status headline" "Awake with lid closed" "$out"
assert_contains "status agents" "2 of 6 working" "$out"
assert_contains "status battery" "81%" "$out"
assert_contains "status last stop" "Battery at 20%" "$out"

sed -i '' "s/^updated=.*/updated=$((now - 600))/" "$T/state/status"
assert_contains "stale status warns" "not reported" "$(cli status)"

out=$(cli bogus); code=$?
assert_eq "unknown command fails" 2 "$code"
assert_contains "unknown command shows usage" "macvibe on" "$out"

chmod u+w "$T/share"; rm -rf "$T/share"
out=$(cli on); code=$?
assert_eq "on without install fails" 1 "$code"
assert_contains "on without install explains" "sudo ./install.sh" "$out"

finish
