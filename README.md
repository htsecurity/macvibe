# MacVibe

Close your MacBook's lid and keep your AI agents (Claude Code, Codex, Gemini, opencode, aider…) working, without cooking the battery.

A native menu bar app with Liquid Glass, a `macvibe` command, and a small root helper that enforces the safety rules.

## Why this exists

Closing the lid forces a Mac to sleep, even while Claude Code holds a `caffeinate` assertion. The only way around it without an external display is `pmset disablesleep 1`, which needs admin rights. Left on by accident, it would keep a Mac awake inside a bag. MacVibe turns it on only when you ask and turns it off by itself when that's safer.

## Modes

| Mode | What happens with the lid closed |
|---|---|
| **While agents work** (`macvibe on`) | Stays awake while an agent is busy. After *N* minutes with the lid closed and no agent activity, it stops and the Mac sleeps. |
| **Until I turn it off** (`macvibe on --forever`) | Stays awake until `macvibe off`. |

"Busy" means Claude Code is holding its `caffeinate` child process, or an agent's process tree used at least 3% CPU since the last check. With the lid open, the idle timer doesn't run.

## Battery care (always on)

MacVibe stops, and puts the Mac to sleep if the lid is closed, when:

- the battery reaches **20%** on battery power,
- the battery is at **42°C** or above, or macOS reports **heavy** thermal pressure, on two checks in a row (about a minute),
- the agents have been idle for **15 min** with the lid closed ("While agents work" only),
- the Mac restarts (requests don't survive a reboot).

While it keeps the Mac awake with the lid closed, it turns on **Low Power Mode** (battery profile) and restores your own setting afterwards. Any automatic stop ends the session: a brief wake inside a bag can never switch it back on. You turn it on again yourself.

All thresholds can be changed in the app or with `macvibe set`.

**Still:** don't run it inside a closed bag. Cooling with the lid closed is weaker, and the safety stops react within about a minute, not instantly. While MacVibe is on, Apple menu > Sleep is blocked too; turn MacVibe off first.

## How it works

```
 MacVibe.app / macvibe CLI ──write──▶ /Library/Application Support/macvibe/{request,settings}   (yours)
                                               │ launchd WatchPaths + every 30 s
                                               ▼
                         /Library/PrivilegedHelperTools/macvibe/reconcile   (root)
                         reads battery, temperature, thermal pressure, lid, agents
                         decides (lib/core.sh) ─▶ pmset disablesleep / lowpowermode / sleepnow
                                               │
                                               ▼
                         /var/db/macvibe/status ──read──▶ app & CLI      /var/log/macvibe.log
```

- `lib/core.sh`: pure decision logic (tested).
- `libexec/macvibe-reconcile`: the root helper. One short run per tick; there's no daemon state to crash. When nothing is requested it always forces `disablesleep 0`, so the Mac can't get stuck awake.
- `bin/macvibe`: the CLI.
- `app/`: the SwiftUI menu bar app (macOS 26+, Liquid Glass). It's built with `swiftc`; no Xcode project needed.
- `install.sh`: installer and `--uninstall`.

See [RUN.md](RUN.md) for the commands.
