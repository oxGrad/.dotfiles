# QuickShell migration — design spec

Date: 2026-09-19
Status: approved (pending implementation plan)

## Goal

Replace waybar with a QuickShell bar that is visually and functionally
identical to the current Monokai "floating islands" bar, using QuickShell's
native Qt-backed services instead of shell-script polling where a service
exists.

## Non-goals

- Porting dormant/commented waybar modules: `custom/swap`, `sway/mode`,
  `custom/cava-internal`, `mpd`/`mpd#2-4`, `custom/launcher`,
  `custom/power`, `custom/keyboard-layout`. None of these render today
  (either commented out of `config`'s module lists, or listed but never
  defined in the `modules-*.jsonc` files). Add them individually later if
  revived.
- Touching `swaync`, `wofi` (app launcher use), `wlogout`, or the
  `bt-toggle.sh` hardware-key binding. None are bar modules; they stay as
  they are.
- Redesigning the visual language. Colors, radii, spacing, and the
  state-only-color rule all carry over unchanged from `waybar/colors.css`
  and `waybar/style.css`.

## Scope: modules to port

Left island: `sway/workspaces`.
Center island: `sway/window` (window title).
Right islands: `tray` (own pill), then a grouped pill of `backlight`,
`pulseaudio` (volume), `bluetooth`, `network`, `battery`, `clock` — matching
the existing `group/system` pill in `waybar/modules-right.jsonc`.

Two of these modules get a native popup instead of shelling out to the
existing wofi-based picker scripts:
- **Bluetooth** — a device list popup (replaces `bt-menu.sh`'s wofi menu)
  with connect/disconnect/pair actions.
- **Network** — a wifi network list popup (replaces `wifi-menu.sh`'s wofi
  menu) with connect/disconnect and a password prompt for secured networks.

Clock gets a native calendar popup (replaces the waybar tooltip-based
calendar) on right-click, matching the current `mode`/`tz_up`/`tz_down`
interactions.

## Package structure

```
quickshell/
  shell.qml              # entry point: PanelWindow per screen, assembles left/center/right
  Theme.qml               # singleton; ports waybar/colors.css (Monokai palette)
  components/
    Pill.qml               # rounded alpha(base, 0.92) island container, reused by every module
    PopupPanel.qml          # shared popup chrome (same pill styling) for bt/wifi/calendar popups
  modules/
    Workspaces.qml
    WindowTitle.qml
    Tray.qml
    Backlight.qml
    Volume.qml
    Bluetooth.qml
    BluetoothPopup.qml
    Network.qml
    NetworkPopup.qml
    Battery.qml
    Clock.qml
    CalendarPopup.qml
```

One file = one concern, matching the split already used in `waybar/`
(`colors.css` / `style.css` / `modules-{left,center,right}.jsonc`).

## Theme

`Theme.qml` is a QML singleton (`pragma Singleton`) exposing every color
from `waybar/colors.css` as a `readonly property color`, using the same
names (`base`, `bonewhite`, `subtext0`, `green`, `pink`, etc.) so the
mapping from the CSS file is 1:1 and stays easy to diff against it if the
palette changes.

`Pill.qml` centralizes the repeated waybar CSS pattern
(`background-color: alpha(@base, 0.92); border-radius: 13px;`) as a
reusable `Rectangle`-based component taking `color`/`radius`/`padding`
overrides, so individual modules don't restate it.

## Data sources

Per-module state source, using a QuickShell service singleton where one
exists, falling back to shelling out (`Quickshell.Io.Process`) only where
QuickShell has no native equivalent:

| Module | Source | Notes |
|---|---|---|
| Tray | `Quickshell.Services.SystemTray` | native, event-driven |
| Battery | `Quickshell.Services.UPower` | native, replaces `battery` module polling |
| Volume | `Quickshell.Services.Pipewire` | native, replaces `pulseaudio` module + `pactl` calls |
| Bluetooth | `Quickshell.Services.Bluetooth` | native: device list, connect/disconnect/pair, adapter power toggle |
| Backlight | `brightnessctl` via `Process` | no QuickShell singleton for backlight; same tool waybar's `on-scroll` already calls |
| Network/wifi | `nmcli` via `Process` | no QuickShell singleton for NetworkManager; `NetworkPopup` re-implements `wifi-menu.sh`'s parsing (signal bars, security lock icon, in-use marker) directly in QML/JS instead of invoking the script |
| Workspaces | `swaymsg -t subscribe -m '["workspace"]'` via long-running `Process`, parsing newline-delimited JSON events; initial state from `swaymsg -t get_workspaces` | QuickShell's built-ins target Hyprland's IPC; Sway has no native singleton, so this is the Sway-equivalent "shell exec" path |
| Window title | `swaymsg -t subscribe -m '["window"]'` via the same long-running `Process` (can share one subscription with Workspaces, filtering by event type) | same reasoning as Workspaces |
| Clock | native QML `Date` on a `Timer` | no exec needed |

## Layout

One `PanelWindow` per screen (`Quickshell.screens`), giving the
`all-outputs: true` behavior waybar has today. Height and margins are
ported directly from `waybar/config`: `height: 26`, `margin: "4 8 2 8"`.
Three `RowLayout`s anchored left/center/right inside the panel, mirroring
`modules-left`/`modules-center`/`modules-right`.

## Visual/state parity

- Base rule: neutral `bonewhite` text everywhere; color only signals state
  (charging → green, warning → yellow, critical → pink blinking,
  muted/disabled → overlay0, disconnected → red), ported 1:1 from the
  `#battery.charging`, `#battery.critical`, `#network.disconnected`, etc.
  rules in `waybar/style.css`.
- Tray gets its own separate pill (not merged into the system group),
  matching the current `#tray` vs `#system` CSS split.
- The right-side group (backlight → clock) renders as one continuous pill
  regardless of which modules are currently shown, same as
  `group/system` today — achieved by giving the pill background to the
  `RowLayout` container itself, not to individual modules.

## Popups

`PopupPanel.qml` is a `PopupWindow` styled with the same
`alpha(base, 0.92)` / 13px-radius pill look as the bar itself, positioned
anchored below its trigger module.

- `BluetoothPopup`: lists paired/discoverable devices (via the Bluetooth
  singleton's device model), connect/disconnect/pair on click, a
  power-toggle row, and a rescan action — functional parity with
  `bt-menu.sh`.
- `NetworkPopup`: lists nearby SSIDs (parsed from `nmcli -t -f
  IN-USE,SIGNAL,SECURITY,SSID dev wifi list`, deduplicated, sorted by
  signal, in-use pinned to top — same logic `wifi-menu.sh` uses today),
  connect/disconnect, password prompt for secured networks, wifi
  radio toggle, rescan — functional parity with `wifi-menu.sh`.
- `CalendarPopup`: month-grid calendar with the same color-coded
  months/days/weeks/today styling as the current waybar tooltip
  (`waybar/modules-right.jsonc`'s `clock.calendar.format`), plus the
  existing timezone shift (`tz_up`/`tz_down`) and mode-toggle
  interactions.

## Sway integration

`sway/config:247` (`swaybar_command waybar`) is swapped for the QuickShell
launch command once the bar is working. No other sway config changes —
the `wifi-menu.sh`/`bt-toggle.sh` keybindings at lines 97/238 are
untouched since they're independent hardware-key/menu bindings, not bar
modules.

## Knotfile

New package, same pattern as `waybar`:

```yaml
  quickshell:
    target: ~/.config/quickshell
    tags: [sway]
    condition:
      os: linux
    # quickshell isn't in Fedora's default repos — install via COPR
    # (or the appropriate source for your distro) before `knot tie`.
```

No `install:` block, since — unlike `waybar`/`k9s` — there's no single
package-manager name that resolves it out of the box on Fedora.

## Testing

QML has no unit-test story worth building for a personal bar config.
Verification is manual: `qs -c quickshell` (or equivalent QuickShell run
command) rendered against the running Sway session, checked against the
current waybar bar side-by-side for each module (visual match + click
behavior), before flipping `swaybar_command`.

## Migration order

1. Build `Theme.qml`, `Pill.qml`, `shell.qml` skeleton — empty bar with
   correct pill geometry, running standalone (not yet wired into sway).
2. Add modules one at a time (Workspaces → WindowTitle → Tray → Backlight
   → Volume → Battery → Bluetooth+popup → Network+popup → Clock+popup),
   checking each against the live waybar bar before moving to the next.
3. Flip `sway/config`'s `swaybar_command` to quickshell.
4. Once confirmed stable over normal use, remove the `waybar` package
   (`Knotfile` entry + `waybar/` directory) and its now-unused
   `bt-menu.sh`/`wifi-menu.sh` scripts (`bt-toggle.sh` stays — it's the
   hardware-key binding, unrelated to the bar).
