#!/bin/bash
# End-to-end run of the root helper against fake pmset/ioreg/ps (no root needed).
cd "$(dirname "$0")/.." || exit 1
. tests/helpers.sh

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/share" "$T/state"
BOOT=1790280433
export MACVIBE_FAKEBIN="$T/bin" MACVIBE_SHARE="$T/share" MACVIBE_STATE="$T/state" MACVIBE_LOG="$T/log"
export FAKE="$T"

. tests/fakes.sh
make_fakes "$T" "$BOOT"

battery() { # ac(Yes/No) percent temp_cc
  printf '  |   "ExternalConnected" = %s\n  |   "MaxCapacity" = 100\n  |   "CurrentCapacity" = %s\n  |   "IsCharging" = No\n  |   "Temperature" = %s\n' "$1" "$2" "$3" > "$T/battery"
}
request() { # mode since [boot]
  printf 'mode=%s\nsince=%s\nboot=%s\n' "$1" "$2" "${3:-$BOOT}" > "$T/share/request"
}
run() { : > "$T/calls"; libexec/macvibe-reconcile; }
status() { kv "$1" "$(cat "$T/state/status")"; }
calls() { cat "$T/calls"; }

battery Yes 80 3300
echo Yes > "$T/lid"
echo 0 > "$T/thermal"
printf '  100     1   0:10.00 claude\n  101   100   0:00.01 caffeinate\n' > "$T/ps"

# 1. Nothing requested: stays normal, touches nothing.
run
assert_eq "no request: mode off" off "$(status mode)"
assert_eq "no request: not active" 0 "$(status active)"
assert_eq "no request: no pmset writes" "" "$(calls | grep -E 'disablesleep|lowpowermode [01]|sleepnow')"

# 2. Auto mode with a working agent and the lid closed: stay awake.
request auto 1000
run
assert_contains "engages: disables sleep" "pmset -a disablesleep 1" "$(calls)"
assert_contains "engages: low power on battery profile" "pmset -b lowpowermode 1" "$(calls)"
assert_eq "engaged: status active" 1 "$(status active)"
assert_eq "engaged: status mode" auto "$(status mode)"
assert_eq "engaged: agents working" 1 "$(status agents_busy)"
assert_eq "engaged: lid" closed "$(status lid)"
assert_eq "engaged: battery temp" 33.0 "$(status temp)"

run
assert_eq "steady state: no repeated writes" "" "$(calls | grep -E 'disablesleep|lowpowermode [01]')"

# 3. Battery runs low: automatic stop, restore, notify, sleep.
battery No 15 3300
run
assert_contains "low battery: re-enables sleep" "pmset -a disablesleep 0" "$(calls)"
assert_contains "low battery: restores low power setting" "pmset -b lowpowermode 0" "$(calls)"
assert_contains "low battery: sleeps now (lid closed)" "pmset sleepnow" "$(calls)"
assert_contains "low battery: notifies" "display notification" "$(calls)"
assert_eq "low battery: mode off" off "$(status mode)"
assert_eq "low battery: event" "Battery at 15%" "$(status event)"
assert_contains "low battery: logged" "Battery at 15%" "$(cat "$T/log")"

# 4. Same session after a wake with a full battery: must not re-engage.
battery Yes 90 3300
run
assert_eq "ended session stays off" "" "$(calls | grep 'disablesleep 1')"

# 5. A new `macvibe on` starts a new session.
request auto 2000
run
assert_contains "new session engages" "pmset -a disablesleep 1" "$(calls)"

# 6. Turning it off by hand with the lid open: restore, no forced sleep.
echo No > "$T/lid"
run
request off 0
run
assert_contains "off: re-enables sleep" "pmset -a disablesleep 0" "$(calls)"
assert_eq "off with lid open: no forced sleep" "" "$(calls | grep sleepnow)"
assert_eq "manual off: no notification" "" "$(calls | grep notification)"

# 7. A request from before a reboot is ignored.
request forever 3000 111
run
assert_eq "stale boot: stays off" "" "$(calls | grep 'disablesleep 1')"

# 8. Self-heal: sleep left disabled with nothing requested gets fixed.
echo 1 > "$T/sleepdisabled"
run
assert_contains "self-heal re-enables sleep" "pmset -a disablesleep 0" "$(calls)"

# 9. Newer Macs (M5, macOS 27) only report temperature inside the BatteryData dictionary.
printf '  |   "ExternalConnected" = Yes\n  |   "MaxCapacity" = 100\n  |   "CurrentCapacity" = 72\n  | |   "BatteryData" = {"DesignCapacity"=6249,"Temperature"=4310,"VirtualTemperature"=4310}\n' > "$T/battery"
run
assert_eq "nested battery temperature" 43.1 "$(status temp)"

finish
