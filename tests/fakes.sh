# Fake system commands for running the root helper without root.
# Sensors come from files in DIR; commands that change the Mac are recorded in DIR/calls.
# Export FAKE=DIR so the fakes can find their files.

make_fakes() { # DIR [BOOT]  (without BOOT the real sysctl is used)
  mkdir -p "$1/bin"
  cat > "$1/bin/pmset" <<'EOF'
#!/bin/bash
echo "pmset $*" >> "$FAKE/calls"
case "$*" in
  "-g") echo " SleepDisabled		$(cat "$FAKE/sleepdisabled" 2>/dev/null || echo 0)" ;;
  "-g custom") printf 'Battery Power:\n lowpowermode         %s\nAC Power:\n lowpowermode         0\n' "$(cat "$FAKE/lpm" 2>/dev/null || echo 0)" ;;
  "-a disablesleep "*) echo "$3" > "$FAKE/sleepdisabled" ;;
  "-b lowpowermode "*) echo "$3" > "$FAKE/lpm" ;;
esac
EOF
  cat > "$1/bin/ioreg" <<'EOF'
#!/bin/bash
case "$*" in
  *AppleSmartBattery*) cat "$FAKE/battery" ;;
  *AppleClamshellState*) echo "  |   \"AppleClamshellState\" = $(cat "$FAKE/lid")" ;;
esac
EOF
  cat > "$1/bin/ps" <<'EOF'
#!/bin/bash
cat "$FAKE/ps"
EOF
  cat > "$1/bin/notifyutil" <<'EOF'
#!/bin/bash
echo "com.apple.system.thermalpressurelevel $(cat "$FAKE/thermal")"
EOF
  if [ -n "${2:-}" ]; then
    cat > "$1/bin/sysctl" <<EOF
#!/bin/bash
echo "{ sec = $2, usec = 1 } Thu Sep 24 22:07:13 2026"
EOF
  fi
  cat > "$1/bin/system_profiler" <<'EOF'
#!/bin/bash
echo "          Connection Type: Internal"
EOF
  cat > "$1/bin/launchctl" <<'EOF'
#!/bin/bash
echo "launchctl $*" >> "$FAKE/calls"
EOF
  chmod +x "$1/bin/"*
  printf '  |   "ExternalConnected" = Yes\n  |   "MaxCapacity" = 100\n  |   "CurrentCapacity" = 80\n  |   "Temperature" = 3300\n' > "$1/battery"
  echo No > "$1/lid"
  echo 0 > "$1/thermal"
  : > "$1/ps"
}
