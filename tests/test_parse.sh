#!/bin/bash
# Parsing the user-writable request/settings files (read by the root helper, so strict).
cd "$(dirname "$0")/.." || exit 1
. tests/helpers.sh
. lib/core.sh

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
BOOT=1790280433

printf 'mode=auto\nsince=1790300000\nboot=%s\n' $BOOT > "$T/req"
assert_eq "valid request" "auto 1790300000" "$(mv_read_request "$T/req" $BOOT)"

printf 'mode=forever\nsince=5\nboot=%s\n' $BOOT > "$T/req"
assert_eq "forever request" "forever 5" "$(mv_read_request "$T/req" $BOOT)"

printf 'mode=auto\nsince=1790300000\nboot=111\n' > "$T/req"
assert_eq "request from before reboot is off" "off 0" "$(mv_read_request "$T/req" $BOOT)"

printf 'mode=turbo\nsince=1\nboot=%s\n' $BOOT > "$T/req"
assert_eq "unknown mode is off" "off 0" "$(mv_read_request "$T/req" $BOOT)"

printf 'mode=auto; rm -rf /\nsince=1\nboot=%s\n' $BOOT > "$T/req"
assert_eq "junk after mode is off" "off 0" "$(mv_read_request "$T/req" $BOOT)"

printf 'mode=auto\nsince=$(id)\nboot=%s\n' $BOOT > "$T/req"
assert_eq "non-numeric since is off" "off 0" "$(mv_read_request "$T/req" $BOOT)"

assert_eq "missing request is off" "off 0" "$(mv_read_request "$T/nope" $BOOT)"

printf 'mode=auto\nsince=1\nboot=%s\n' $BOOT > "$T/real"
ln -s "$T/real" "$T/link"
assert_eq "symlinked request is off" "off 0" "$(mv_read_request "$T/link" $BOOT)"

printf 'min_battery=25\nmax_temp=99\nidle_minutes=abc\n' > "$T/set"
assert_eq "setting in range" 25 "$(mv_read_setting "$T/set" min_battery 20 5 60)"
assert_eq "setting clamped to max" 50 "$(mv_read_setting "$T/set" max_temp 42 35 50)"
assert_eq "non-numeric setting uses default" 15 "$(mv_read_setting "$T/set" idle_minutes 15 1 240)"
assert_eq "missing key uses default" 1 "$(mv_read_setting "$T/set" low_power 1 0 1)"
assert_eq "missing file uses default" 20 "$(mv_read_setting "$T/none" min_battery 20 5 60)"
printf 'min_battery=2\n' > "$T/set"
assert_eq "setting clamped to min" 5 "$(mv_read_setting "$T/set" min_battery 20 5 60)"

finish
