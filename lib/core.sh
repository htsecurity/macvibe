# macvibe core: pure functions shared by the CLI and the root helper.
# bash 3.2 compatible (the version macOS ships). No side effects here.

MV_MODES="off auto forever"
# Command names of AI coding agents whose work should keep the Mac awake.
MV_AGENTS="${MV_AGENTS:-claude codex gemini opencode aider cursor-agent}"
# An agent is "working" if its process tree used at least this % of one core.
MV_BUSY_CPU_PCT=3

# Prints the value of KEY from a key=value file, or nothing.
_mv_get() { # file key
  awk -F= -v k="$2" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$1" 2>/dev/null
}

_mv_is_uint() {
  case "$1" in '' | *[!0-9]*) return 1 ;; esac
  return 0
}

# The request file is user-writable and read by root: accept only exact values.
# Prints "MODE SINCE"; anything invalid, missing or from an earlier boot is "off 0".
mv_read_request() { # file current_boot
  local f="$1" mode since boot
  if [ -L "$f" ] || [ ! -f "$f" ]; then echo "off 0"; return; fi
  mode=$(_mv_get "$f" mode)
  since=$(_mv_get "$f" since)
  boot=$(_mv_get "$f" boot)
  case " $MV_MODES " in *" $mode "*) ;; *) echo "off 0"; return ;; esac
  if ! _mv_is_uint "$since" || [ "$boot" != "$2" ] || [ "$mode" = off ]; then
    echo "off 0"; return
  fi
  echo "$mode $since"
}

# Prints the integer setting KEY clamped to [MIN, MAX], or DEFAULT if unusable.
mv_read_setting() { # file key default min max
  local v=""
  if [ ! -L "$1" ] && [ -f "$1" ]; then v=$(_mv_get "$1" "$2"); fi
  if ! _mv_is_uint "$v" || [ ${#v} -gt 6 ]; then echo "$3"; return; fi
  if [ "$v" -lt "$4" ]; then v=$4; fi
  if [ "$v" -gt "$5" ]; then v=$5; fi
  echo "$v"
}

# stdin: `ps -axo pid=,ppid=,time=,args=`
# stdout: one line per agent: "PID TREE_CPU_CENTISECONDS HAS_CAFFEINATE"
# Claude Code runs `caffeinate` as a child while it is working.
# Script-based agents (gemini, aider…) run as node/python: their script name counts.
mv_scan_agents() {
  awk -v agents=" $MV_AGENTS " '
    function cs(t,  a, n) {
      n = split(t, a, ":")
      if (n == 3) return int((a[1] * 3600 + a[2] * 60 + a[3]) * 100 + 0.5)
      return int((a[1] * 60 + a[2]) * 100 + 0.5)
    }
    function base(p) { sub(".*/", "", p); return p }
    {
      pid = $1; cpu[pid] = cs($3)
      n = base($4)
      if (n ~ /^(node|bun|deno|python[0-9.]*)$/) {
        for (i = 5; i <= NF; i++) if ($i !~ /^-/) { n = base($i); break }
      }
      name[pid] = n
      kids[$2] = kids[$2] " " pid
    }
    END {
      for (p in name) {
        if (index(agents, " " name[p] " ") == 0) continue
        total = 0; caff = 0; todo = p
        while (todo != "") {
          n = split(todo, q, " "); cur = q[1]; todo = ""
          for (i = 2; i <= n; i++) todo = todo " " q[i]
          total += cpu[cur]
          if (cur != p && name[cur] == "caffeinate") caff = 1
          todo = todo kids[cur]
          sub(/^ +/, "", todo)
        }
        print p, total, caff
      }
    }' | sort -n
}

# Prints "BUSY_COUNT TOTAL_AGENTS".
mv_busy() { # current_scan previous_samples("PID CS" lines) elapsed_seconds
  # macOS awk rejects newlines in -v values, so the scan travels via ENVIRON.
  printf '%s\n' "$2" | MV_SCAN="$1" awk -v el="$3" -v pct="$MV_BUSY_CPU_PCT" '
    NF == 2 { prev[$1] = $2 }
    END {
      n = split(ENVIRON["MV_SCAN"], lines, "\n"); busy = 0; total = 0
      for (i = 1; i <= n; i++) {
        if (split(lines[i], f, " ") != 3) continue
        total++
        if (f[3] == 1 || (f[1] in prev && el > 0 && f[2] - prev[f[1]] >= pct * el)) busy++
      }
      print busy, total
    }'
}

# The decision. Takes key=value arguments, prints key=value lines:
#   action=engage|release  end=1 if this is an automatic stop  reason=text
#   last_busy, hot (consecutive hot checks), lowpower=0|1, idle_left (seconds or -1)
mv_decide() {
  local mode=off ended=0 ac=1 pct=100 temp_cc=0 thermal=0 lid=0 busy=0 now=0
  local last_busy=0 hot=0 min_battery=20 max_temp=42 idle_minutes=15 low_power=1
  local arg action=engage end=0 reason="" idle_left=-1 lowpower=0
  for arg in "$@"; do
    case "${arg%%=*}" in
      mode | ended | ac | pct | temp_cc | thermal | lid | busy | now | last_busy | hot | \
        min_battery | max_temp | idle_minutes | low_power) printf -v "${arg%%=*}" '%s' "${arg#*=}" ;;
    esac
  done

  if [ "$mode" = off ] || [ "$ended" = 1 ]; then
    action=release; hot=0; last_busy=$now
  else
    if [ "$temp_cc" -ge $((max_temp * 100)) ] || [ "$thermal" -ge 2 ]; then
      hot=$((hot + 1))
    else
      hot=0
    fi
    if [ "$busy" = 1 ] || [ "$lid" = 0 ]; then last_busy=$now; fi

    if [ "$ac" = 0 ] && [ "$pct" -le "$min_battery" ]; then
      action=release; end=1; reason="Battery at ${pct}%"
    elif [ "$hot" -ge 2 ]; then
      action=release; end=1
      if [ "$thermal" -ge 2 ]; then
        reason="Mac running hot (thermal pressure $(mv_thermal_name "$thermal"))"
      else
        reason="Battery too warm ($(mv_celsius "$temp_cc")°C)"
      fi
    elif [ "$mode" = auto ]; then
      idle_left=$((idle_minutes * 60 - (now - last_busy)))
      if [ "$idle_left" -le 0 ]; then
        action=release; end=1; idle_left=-1
        reason="Agents idle for ${idle_minutes} min"
      fi
    fi
  fi

  if [ "$action" = engage ] && [ "$lid" = 1 ] && [ "$low_power" = 1 ]; then lowpower=1; fi
  printf 'action=%s\nend=%s\nreason=%s\nlast_busy=%s\nhot=%s\nlowpower=%s\nidle_left=%s\n' \
    "$action" "$end" "$reason" "$last_busy" "$hot" "$lowpower" "$idle_left"
}

mv_celsius() { # centi-degrees -> "42.5"
  printf '%d.%d' $(($1 / 100)) $((($1 % 100) / 10))
}

mv_thermal_name() {
  case "$1" in
    0) echo nominal ;; 1) echo moderate ;; 2) echo heavy ;; 3) echo trapping ;; *) echo sleeping ;;
  esac
}
