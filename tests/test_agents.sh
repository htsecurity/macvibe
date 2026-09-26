#!/bin/bash
# Detecting whether AI coding agents are actually working.
cd "$(dirname "$0")/.." || exit 1
. tests/helpers.sh
. lib/core.sh

# Fixture shaped like `ps -axo pid=,ppid=,time=,comm=` on macOS.
PS='    1     0   5:00.00 /sbin/launchd
  100     1   0:10.00 claude
  101   100   0:00.01 caffeinate
  200     1   1:02:03.45 claude
  300     1   0:03.39 /Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex
  301   300   0:20.00 /bin/zsh
  302   301   0:05.50 cargo
  400     1   9:00.00 /Applications/Claude.app/Contents/MacOS/Claude
  500     1   1:00.00 /Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Helpers/Codex (Service).app/Contents/MacOS/Codex (Service)'

scan=$(printf '%s\n' "$PS" | mv_scan_agents)
assert_eq "finds exactly the CLI agents" 3 "$(printf '%s\n' "$scan" | grep -c .)"
assert_eq "claude with caffeinate child" "100 1001 1" "$(printf '%s\n' "$scan" | awk '$1==100')"
assert_eq "hours:min:sec cpu time" "200 372345 0" "$(printf '%s\n' "$scan" | awk '$1==200')"
assert_eq "codex tree includes grandchildren" "300 2889 0" "$(printf '%s\n' "$scan" | awk '$1==300')"

# mv_busy: current scan + previous samples (pid centiseconds) + seconds elapsed
cur='100 1001 1
200 372345 0
300 2889 0'
prev='100 1000
200 372300
300 2789'
# 30s elapsed: 3% threshold = 90cs. pid 200 used 45cs (idle), 300 used 100cs (busy), 100 has caffeinate.
assert_eq "busy count and total" "2 3" "$(mv_busy "$cur" "$prev" 30)"
assert_eq "without samples only caffeinate counts" "1 3" "$(mv_busy "$cur" "" 30)"
assert_eq "new agent without sample is not busy by cpu" "1 3" "$(mv_busy "$cur" "999 1" 30)"
assert_eq "no agents" "0 0" "$(mv_busy "" "" 30)"

finish
