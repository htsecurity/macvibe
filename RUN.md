# Run

## First time (install)
```bash
cd ~/macvibe
sudo ./install.sh          # type your Mac password (nothing shows while typing)
```
This builds the app, installs the background helper, and opens MacVibe (cup icon, top right of the menu bar).

## Use
- Menu bar: click the cup, flip the switch.
- Terminal:
  ```bash
  macvibe on              # awake with the lid closed while agents work
  macvibe on --forever    # awake until you turn it off
  macvibe status
  macvibe off
  macvibe log
  macvibe set min-battery 25     # also: max-temp 42, idle 15, low-power on|off
  ```

## Checks
```bash
./check.sh                 # syntax, plists, all tests, app build
./check.sh --no-app        # skip the Swift build
```

## Preview the app without installing
```bash
app/build.sh && open build/MacVibe.app --args --preview
```

## Update after changing code
```bash
sudo ./install.sh
```

## Stop / remove
```bash
macvibe off                     # back to normal sleep
sudo ./install.sh --uninstall   # remove everything, restore sleep and Low Power settings
```
