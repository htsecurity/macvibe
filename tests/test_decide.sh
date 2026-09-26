#!/bin/bash
# Decision logic: when to keep the Mac awake with the lid closed, and when to stop.
cd "$(dirname "$0")/.." || exit 1
. tests/helpers.sh
. lib/core.sh

NOW=100000
# Baseline: cool, plugged in, lid closed, agents busy, default settings.
base() {
  mv_decide mode=forever ended=0 ac=1 pct=80 temp_cc=3300 thermal=0 lid=1 busy=0 \
    now=$NOW last_busy=$NOW hot=0 min_battery=20 max_temp=42 idle_minutes=15 low_power=1 "$@"
}

out=$(base mode=off)
assert_eq "off releases" release "$(kv action "$out")"
assert_eq "off is not an automatic stop" 0 "$(kv end "$out")"

out=$(base)
assert_eq "forever on AC stays awake" engage "$(kv action "$out")"

out=$(base ended=1)
assert_eq "ended session stays released" release "$(kv action "$out")"
assert_eq "ended session is not re-reported" 0 "$(kv end "$out")"

# Low battery
out=$(base ac=0 pct=20)
assert_eq "battery at limit stops" release "$(kv action "$out")"
assert_eq "battery stop is automatic" 1 "$(kv end "$out")"
assert_contains "battery reason" "Battery at 20%" "$(kv reason "$out")"

out=$(base ac=0 pct=21)
assert_eq "battery above limit keeps going" engage "$(kv action "$out")"

out=$(base ac=1 pct=5)
assert_eq "low battery on charger keeps going" engage "$(kv action "$out")"

# Heat needs two hot checks in a row
out=$(base temp_cc=4200)
assert_eq "first hot check keeps going" engage "$(kv action "$out")"
assert_eq "first hot check counts" 1 "$(kv hot "$out")"

out=$(base temp_cc=4250 hot=1)
assert_eq "second hot check stops" release "$(kv action "$out")"
assert_eq "heat stop is automatic" 1 "$(kv end "$out")"
assert_contains "heat reason shows temperature" "42.5°C" "$(kv reason "$out")"

out=$(base thermal=2 hot=1)
assert_eq "heavy thermal pressure counts as hot" release "$(kv action "$out")"
assert_contains "thermal reason" "heavy" "$(kv reason "$out")"

out=$(base thermal=1 hot=1)
assert_eq "moderate thermal pressure is fine" engage "$(kv action "$out")"
assert_eq "cool check resets hot count" 0 "$(kv hot "$out")"

# Auto mode: idle timer only runs while the lid is closed
out=$(base mode=auto busy=1 last_busy=1)
assert_eq "busy agents keep auto awake" engage "$(kv action "$out")"
assert_eq "busy agents refresh timer" $NOW "$(kv last_busy "$out")"

out=$(base mode=auto last_busy=$((NOW - 15 * 60)))
assert_eq "idle 15 min with lid closed stops" release "$(kv action "$out")"
assert_eq "idle stop is automatic" 1 "$(kv end "$out")"
assert_contains "idle reason" "idle for 15 min" "$(kv reason "$out")"

out=$(base mode=auto last_busy=$((NOW - 14 * 60)))
assert_eq "idle 14 min keeps going" engage "$(kv action "$out")"
assert_eq "idle countdown" 60 "$(kv idle_left "$out")"

out=$(base mode=auto lid=0 last_busy=1)
assert_eq "lid open never idles out" engage "$(kv action "$out")"
assert_eq "lid open refreshes timer" $NOW "$(kv last_busy "$out")"

out=$(base mode=forever last_busy=1)
assert_eq "forever ignores idle" engage "$(kv action "$out")"
assert_eq "forever has no countdown" -1 "$(kv idle_left "$out")"

# Low Power Mode only while awake with the lid closed
assert_eq "low power when engaged and lid closed" 1 "$(kv lowpower "$(base)")"
assert_eq "no low power with lid open" 0 "$(kv lowpower "$(base lid=0)")"
assert_eq "no low power when setting off" 0 "$(kv lowpower "$(base low_power=0)")"
assert_eq "no low power when released" 0 "$(kv lowpower "$(base mode=off)")"

finish
