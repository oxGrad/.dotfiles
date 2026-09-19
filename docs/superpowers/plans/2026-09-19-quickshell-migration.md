# QuickShell Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the waybar bar with a QuickShell bar that is visually and
functionally identical (same Monokai floating-islands look, same modules,
same click behavior), using QuickShell's native service singletons where
one exists and shelling out only where it doesn't.

**Architecture:** A `quickshell/` Knotfile package (target
`~/.config/quickshell`) containing a `shell.qml` entry point, a `Theme.qml`
singleton porting the Monokai palette, two shared components
(`Pill`, `PopupPanel`), and one QML file per bar module under `modules/`.
Modules source their state from QuickShell's built-in services
(SystemTray, UPower, Pipewire, Bluetooth) where available, and from
long-running or one-shot `Quickshell.Io.Process` calls (`swaymsg`,
`brightnessctl`, `nmcli`) where QuickShell has no native singleton.

**Tech Stack:** QML (Qt Quick), QuickShell (`quickshell.org`), Sway IPC
(`swaymsg`), `nmcli`, `brightnessctl`.

**Spec:** `docs/superpowers/specs/2026-09-19-quickshell-migration-design.md`

## Global Constraints

- Palette: use these exact hex values (from `waybar/colors.css`), no
  substitutions — `base #272822`, `mantle/crust #1e1f1c`, `text #f8f8f2`,
  `subtext0 #90908a`, `subtext1 #c2c2bf`, `surface0 #3e3d32`,
  `surface1 #414339`, `surface2 #464741`, `overlay0 #75715e`,
  `overlay1 #90908a`, `overlay2 #cccccc`, `bonewhite #faf9f6`,
  `blue #6a7ec8`, `lavender #819aff`, `sapphire #56adbc`,
  `sky/teal #66d9ef`, `green #a6e22e`, `yellow #e2e22e`,
  `peach #ffd56c`, `maroon #ff6583`, `red/pink #f92672`,
  `mauve #ae81ff`, `flamingo #ff9767`, `rosewater #f8f8f0`.
- Every pill: background `alpha(base, 0.92)`, `border-radius: 13px`.
- Bar: `height: 26`, outer margin `4 8 2 8` (top, right, bottom, left).
- Font: `JetBrainsMono Nerd Font`, `12px`, weight `600` — except the
  window-title module, which is weight `400` (ported from
  `waybar/style.css`).
- Text color rule: neutral `bonewhite` everywhere; color appears ONLY to
  signal state (charging → green, warning → yellow, critical → pink
  blinking, muted/disabled → overlay0, disconnected → red, bluetooth
  connected → sky).
- Do not port `custom/swap`, `sway/mode`, `custom/cava-internal`, `mpd`,
  `custom/launcher`, `custom/power`, `custom/keyboard-layout` — none
  render in the current bar.
- Do not modify `swaync/`, `wofi/`, `wlogout/`, or the `bt-toggle.sh`
  sway keybinding — out of scope.
- Use a QuickShell service singleton when one exists for the data;
  shell out (`Process`) only when it doesn't (Sway IPC, backlight,
  NetworkManager have no singleton).
- QuickShell's exact QML API (import paths, property/method names on
  `Quickshell.Services.*`) can differ by installed version. Treat `qs`'s
  own QML compile/runtime errors as authoritative over this plan's code
  samples — if a property or import doesn't exist on your install, check
  `qs`'s own docs/examples (`qs docs`, or https://quickshell.org) and
  adjust; the shapes here are the commonly-documented API, not a
  version-pinned guarantee.

---

## File Structure

```
quickshell/
  shell.qml                  # entry point: ShellRoot, one PanelWindow per screen
  Theme.qml                  # pragma Singleton — Monokai palette
  qmldir                     # registers Theme as a singleton for the package
  components/
    qmldir                   # registers Pill, PopupPanel
    Pill.qml                 # rounded alpha(base,0.92) island container
    PopupPanel.qml           # shared popup chrome, same pill styling
  modules/
    Workspaces.qml
    WindowTitle.qml
    Tray.qml
    Backlight.qml
    Volume.qml
    Battery.qml
    Bluetooth.qml
    BluetoothPopup.qml
    Network.qml
    NetworkPopup.qml
    Clock.qml
    CalendarPopup.qml
```

Knotfile gets one new package entry (Task 1). `sway/config` gets one line
changed (Task 13), after everything else is verified working.

---

### Task 1: Package scaffold — Knotfile entry + empty shell

**Files:**
- Create: `quickshell/shell.qml`
- Modify: `Knotfile`

**Interfaces:**
- Produces: a `quickshell` Knotfile package symlinking `quickshell/` →
  `~/.config/quickshell`; a `shell.qml` that launches an empty
  layer-shell panel per screen, proving the QuickShell toolchain and
  Knotfile wiring both work before any module logic is written.

- [ ] **Step 1: Confirm QuickShell is installed**

Run: `which qs || which quickshell`
Expected: one of them resolves. If neither does, install it first —
check the current install instructions for your distro from QuickShell's
own docs/README (the exact package/COPR name changes over time, so look
it up rather than trusting a hardcoded command here).

- [ ] **Step 2: Add the Knotfile package entry**

Add to `Knotfile`, alongside the other `tags: [sway]` Linux packages
(next to the `waybar:` entry):

```yaml
  quickshell:
    target: ~/.config/quickshell
    tags: [sway]
    condition:
      os: linux
    # quickshell isn't in Fedora's default repos — install via COPR
    # (or the appropriate source for your distro) before `knot tie`.
```

- [ ] **Step 3: Write a minimal `shell.qml`**

```qml
// quickshell/shell.qml
import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 26
            margins {
                top: 4
                right: 8
                bottom: 2
                left: 8
            }
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "quickshell alive"
                color: "#faf9f6"
            }
        }
    }
}
```

- [ ] **Step 4: Symlink and run it**

Run: `knot tie quickshell`
Run: `qs -c quickshell` (or `quickshell -c quickshell`, matching whichever
binary Step 1 found)
Expected: a bar-shaped bonewhite-text panel appears at the top of each
screen reading "quickshell alive", with no QML errors in the terminal.

- [ ] **Step 5: Commit**

```bash
git add Knotfile quickshell/shell.qml
git commit -m "feat(quickshell): scaffold empty panel + Knotfile package"
```

---

### Task 2: Theme singleton + Pill component

**Files:**
- Create: `quickshell/Theme.qml`
- Create: `quickshell/qmldir`
- Create: `quickshell/components/Pill.qml`
- Create: `quickshell/components/qmldir`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: nothing (first component task).
- Produces: `Theme` singleton with one `readonly property color` per
  palette entry (exact names below); `Pill { property color bg:
  Theme.base; property real bgAlpha: 0.92; default property alias
  content: inner.data }` — every later module wraps its content in a
  `Pill { ... }` instead of restating the background/radius rules.

- [ ] **Step 1: Write `Theme.qml`**

```qml
// quickshell/Theme.qml
pragma Singleton
import QtQuick

QtObject {
    readonly property color base: "#272822"
    readonly property color mantle: "#1e1f1c"
    readonly property color crust: "#1e1f1c"

    readonly property color text: "#f8f8f2"
    readonly property color subtext0: "#90908a"
    readonly property color subtext1: "#c2c2bf"

    readonly property color surface0: "#3e3d32"
    readonly property color surface1: "#414339"
    readonly property color surface2: "#464741"

    readonly property color overlay0: "#75715e"
    readonly property color overlay1: "#90908a"
    readonly property color overlay2: "#cccccc"

    readonly property color bonewhite: "#faf9f6"
    readonly property color blue: "#6a7ec8"
    readonly property color lavender: "#819aff"
    readonly property color sapphire: "#56adbc"
    readonly property color sky: "#66d9ef"
    readonly property color teal: "#66d9ef"
    readonly property color green: "#a6e22e"
    readonly property color yellow: "#e2e22e"
    readonly property color peach: "#ffd56c"
    readonly property color maroon: "#ff6583"
    readonly property color red: "#f92672"
    readonly property color mauve: "#ae81ff"
    readonly property color pink: "#f92672"
    readonly property color flamingo: "#ff9767"
    readonly property color rosewater: "#f8f8f0"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int pillRadius: 13
    readonly property real pillAlpha: 0.92
}
```

- [ ] **Step 2: Register it as a singleton**

```
# quickshell/qmldir
singleton Theme 1.0 Theme.qml
```

- [ ] **Step 3: Write `Pill.qml`**

```qml
// quickshell/components/Pill.qml
import QtQuick
import ".."

Rectangle {
    id: root
    default property alias content: inner.data
    property real horizontalPadding: 12

    color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, Theme.pillAlpha)
    radius: Theme.pillRadius
    implicitHeight: 22
    implicitWidth: inner.implicitWidth + horizontalPadding * 2

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 6
    }
}
```

- [ ] **Step 4: Register the components package**

```
# quickshell/components/qmldir
Pill 1.0 Pill.qml
```

- [ ] **Step 5: Prove both compile — swap the placeholder text for a Pill**

Edit `quickshell/shell.qml`, replacing the `Text` block with:

```qml
            import "components" as Components

            Components.Pill {
                anchors.centerIn: parent
                content: Text {
                    text: "themed pill"
                    color: Theme.bonewhite
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }
            }
```

(QML requires imports at the top of the file — move the `import
"components" as Components` line up next to the existing `import
Quickshell` / `import QtQuick` lines rather than inline.)

- [ ] **Step 6: Run it**

Run: `qs -c quickshell`
Expected: a single rounded, semi-transparent dark pill reading "themed
pill" in bonewhite text, centered on the bar — no QML errors.

- [ ] **Step 7: Commit**

```bash
git add quickshell/Theme.qml quickshell/qmldir quickshell/components quickshell/shell.qml
git commit -m "feat(quickshell): add Theme singleton and Pill component"
```

---

### Task 3: Bar layout skeleton (left/center/right sections)

**Files:**
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme` (Task 2), `Components.Pill` (Task 2).
- Produces: three `Row`s (`leftSection`, `centerSection`,
  `rightSection`) inside each `PanelWindow`, anchored the way
  `waybar/config`'s `modules-left`/`modules-center`/`modules-right` are.
  Later tasks each add exactly one child to one of these three rows —
  this is the slot every module task plugs into.

- [ ] **Step 1: Replace the placeholder Pill with the three-section layout**

```qml
// quickshell/shell.qml
import Quickshell
import QtQuick
import "components" as Components

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 26
            margins {
                top: 4
                right: 8
                bottom: 2
                left: 8
            }
            color: "transparent"

            Row {
                id: leftSection
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
            }

            Row {
                id: centerSection
                anchors.centerIn: parent
                spacing: 6
            }

            Row {
                id: rightSection
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
            }
        }
    }
}
```

- [ ] **Step 2: Run it**

Run: `qs -c quickshell`
Expected: bar renders with no visible content (all three rows empty) and
no QML errors — this proves the anchoring compiles before any module
logic is added on top of it.

- [ ] **Step 3: Commit**

```bash
git add quickshell/shell.qml
git commit -m "feat(quickshell): add left/center/right layout sections"
```

---

### Task 4: Workspaces module (Sway IPC)

**Files:**
- Create: `quickshell/modules/Workspaces.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.Pill`, a running `swaymsg` binary.
- Produces: `Workspaces` component with a `signal focusedChanged` unused
  externally for now, but exposes `property var workspaces: []` (list of
  `{num, name, focused}`) that Task 5 (WindowTitle) reuses the same
  subscription pattern from — copy the `Process` block, don't share a
  literal instance (each module owns its own subscription; simplicity
  over premature sharing).

- [ ] **Step 1: Write `Workspaces.qml`**

```qml
// quickshell/modules/Workspaces.qml
import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components

Components.Pill {
    id: root
    property var workspaces: []

    content: Row {
        spacing: 4
        Repeater {
            model: root.workspaces
            delegate: Text {
                required property var modelData
                text: {
                    const icons = { "1": "", "2": "", "3": "", "4": "", "5": "", "6": "" }
                    return icons[modelData.name] ?? modelData.name
                }
                color: modelData.focused ? Root.Theme.bonewhite : Root.Theme.subtext0
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
            }
        }
    }

    function refresh() {
        getWorkspaces.running = true
    }

    Process {
        id: getWorkspaces
        command: ["swaymsg", "-t", "get_workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.workspaces = JSON.parse(text)
        }
    }

    Process {
        id: subscribe
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"workspace\"]"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
        subscribe.running = true
    }
}
```

- [ ] **Step 2: Wire it into the bar's left section**

In `quickshell/shell.qml`: add `import "modules" as Modules` to the
imports, and inside `leftSection`, add:

```qml
                Modules.Workspaces {}
```

- [ ] **Step 3: Run it against the live Sway session**

Run: `qs -c quickshell`
Expected: the left pill shows one icon per real Sway workspace, the
focused one in bonewhite and the rest in subtext0/dimmed. Switch
workspaces (`$mod+1`, etc.) and confirm the highlighted icon updates
live.

- [ ] **Step 4: Commit**

```bash
git add quickshell/modules/Workspaces.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Workspaces module via Sway IPC"
```

---

### Task 5: Window title module

**Files:**
- Create: `quickshell/modules/WindowTitle.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.Pill`, `swaymsg` (own subscription,
  same pattern as Task 4's `Workspaces.qml`).
- Produces: `WindowTitle` component, mounted in `centerSection`.

- [ ] **Step 1: Write `WindowTitle.qml`**

```qml
// quickshell/modules/WindowTitle.qml
import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components

Components.Pill {
    id: root
    property string title: ""
    visible: root.title.length > 0

    content: Text {
        text: root.title
        color: Root.Theme.subtext1
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.Normal
        elide: Text.ElideRight
    }

    function refresh() {
        getTree.running = true
    }

    Process {
        id: getTree
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                const tree = JSON.parse(text)
                root.title = findFocusedTitle(tree) ?? ""
            }
        }
    }

    function findFocusedTitle(node) {
        if (node.focused && node.name) return node.name
        for (const child of (node.nodes ?? []).concat(node.floating_nodes ?? [])) {
            const found = findFocusedTitle(child)
            if (found) return found
        }
        return null
    }

    Process {
        id: subscribe
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"window\"]"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
        subscribe.running = true
    }
}
```

- [ ] **Step 2: Wire it into the bar's center section**

In `quickshell/shell.qml`, inside `centerSection`, add:

```qml
                Modules.WindowTitle {}
```

- [ ] **Step 3: Run it**

Run: `qs -c quickshell`
Expected: center pill shows the focused window's title, updates when
you switch focus, and disappears (matching `window#waybar.empty
#window` going transparent) when no window is focused.

- [ ] **Step 4: Commit**

```bash
git add quickshell/modules/WindowTitle.qml quickshell/shell.qml
git commit -m "feat(quickshell): add window title module via Sway IPC"
```

---

### Task 6: Tray module

**Files:**
- Create: `quickshell/modules/Tray.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.Pill`, `Quickshell.Services.SystemTray`.
- Produces: `Tray` component, mounted as its own pill in
  `rightSection` (matching `waybar/style.css`'s separate `#tray` pill,
  not merged into the system group).

- [ ] **Step 1: Write `Tray.qml`**

```qml
// quickshell/modules/Tray.qml
import QtQuick
import Quickshell.Services.SystemTray
import ".." as Root
import "../components" as Components

Components.Pill {
    id: root
    visible: SystemTray.items.values.length > 0

    content: Row {
        spacing: 5
        Repeater {
            model: SystemTray.items.values
            delegate: Image {
                required property var modelData
                source: modelData.icon
                width: 14
                height: 14
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) modelData.activate()
                        else modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Wire it into the bar's right section**

In `quickshell/shell.qml`, inside `rightSection`, add (before the system
group added in later tasks):

```qml
                Modules.Tray {}
```

- [ ] **Step 3: Run it**

Run: `qs -c quickshell`
Expected: a small pill appears showing icons for any app currently
publishing a `StatusNotifierItem` (e.g. an already-running tray app);
clicking an icon activates it the same as waybar's tray does.

- [ ] **Step 4: Commit**

```bash
git add quickshell/modules/Tray.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Tray module via SystemTray service"
```

---

### Task 7: Backlight module

**Files:**
- Create: `quickshell/modules/Backlight.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.Pill`, `brightnessctl` via `Process`.
- Produces: `Backlight` component, first module in the grouped
  right-side "system" pill (Tasks 7–12 all render inside one shared
  `Pill` added in this task, matching `group/system` in
  `waybar/modules-right.jsonc` rendering as one continuous capsule).

- [ ] **Step 1: Write `Backlight.qml`**

```qml
// quickshell/modules/Backlight.qml
import QtQuick
import Quickshell.Io
import ".." as Root

Item {
    id: root
    property int percent: 0
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: {
            const icons = ["󰋢", "󰋡", "󰋠"] // 󰃛 󰃞 󰃠
            const idx = Math.min(icons.length - 1, Math.floor(root.percent / (100 / icons.length)))
            return icons[idx] + " " + root.percent.toString().padStart(3, " ") + "%"
        }
        color: Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            const cmd = wheel.angleDelta.y > 0 ? "+5%" : "5%-"
            bump.command = ["brightnessctl", "set", cmd]
            bump.running = true
        }
    }

    Process {
        id: bump
        onExited: refresh.running = true
    }

    Process {
        id: refresh
        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // brightnessctl -m output: class,name,current,pct%,max
                const fields = text.trim().split(",")
                root.percent = parseInt(fields[3])
            }
        }
    }

    Component.onCompleted: refresh.running = true
}
```

Note: the scroll `MouseArea` above sets `acceptedButtons: Qt.NoButton`
because it only needs `onWheel`; QML delivers wheel events regardless of
`acceptedButtons`.

- [ ] **Step 2: Wire it into the bar's right section, starting the shared system pill**

In `quickshell/shell.qml`, add `import "components" as Components` (if
not already present from Task 2) and inside `rightSection`, after
`Modules.Tray {}`, add:

```qml
                Components.Pill {
                    horizontalPadding: 4
                    content: Row {
                        spacing: 10
                        Modules.Backlight {}
                    }
                }
```

- [ ] **Step 3: Run it**

Run: `qs -c quickshell`
Expected: right side shows a pill with a backlight icon + percentage;
scrolling up/down over it changes screen brightness by 5%, matching
waybar's `on-scroll-up`/`on-scroll-down` behavior.

- [ ] **Step 4: Commit**

```bash
git add quickshell/modules/Backlight.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Backlight module, start system pill group"
```

---

### Task 8: Volume module

**Files:**
- Create: `quickshell/modules/Volume.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Quickshell.Services.Pipewire`.
- Produces: `Volume` component, added to the shared system pill's `Row`
  (Task 7) as the second module, replacing `pulseaudio`.

- [ ] **Step 1: Write `Volume.qml`**

```qml
// quickshell/modules/Volume.qml
import QtQuick
import Quickshell.Services.Pipewire
import ".." as Root

Item {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int volumePct: Math.round((sink?.audio?.volume ?? 0) * 100)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.muted
            ? "󰌧 muted" // 
            : "󰌨 " + root.volumePct.toString().padStart(4, " ") + "%" // 
        color: root.muted ? Root.Theme.overlay0 : Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: openPavucontrol.running = true
        onWheel: (wheel) => {
            if (!root.sink) return
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1.5, root.sink.audio.volume + delta))
        }
    }

    Process {
        id: openPavucontrol
        command: ["pavucontrol"]
    }
}
```

- [ ] **Step 2: Add it to the system pill**

In `quickshell/shell.qml`'s system-pill `Row` (from Task 7), after
`Modules.Backlight {}`, add:

```qml
                        Modules.Volume {}
```

- [ ] **Step 3: Run it**

Run: `qs -c quickshell`
Expected: shows current sink volume percentage; scrolling changes
volume in ~5% steps; clicking opens pavucontrol; muting the sink
elsewhere (e.g. `pactl set-sink-mute @DEFAULT_SINK@ toggle`) turns the
text dimmed and shows "muted", matching `#pulseaudio.muted`.

- [ ] **Step 4: Commit**

```bash
git add quickshell/modules/Volume.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Volume module via Pipewire service"
```

---

### Task 9: Battery module

**Files:**
- Create: `quickshell/modules/Battery.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Quickshell.Services.UPower`.
- Produces: `Battery` component, added to the shared system pill's `Row`
  as the last module (matching `group/system`'s module order ending in
  `clock`, with `battery` immediately before it).

- [ ] **Step 1: Write `Battery.qml`**

```qml
// quickshell/modules/Battery.qml
import QtQuick
import Quickshell.Services.UPower
import ".." as Root

Item {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property int pct: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool plugged: device?.state === UPowerDeviceState.PendingCharge
    readonly property bool critical: root.pct <= 15 && !root.charging
    readonly property bool warning: root.pct <= 30 && !root.charging

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: {
            const icons = ["󰍾", "󰍽", "󰍼", "󰍻", "󰍺"] // 
            const idx = Math.min(icons.length - 1, Math.floor(root.pct / (100 / icons.length)))
            const icon = (root.charging || root.plugged) ? "󰎄" : icons[idx] // 
            return icon + " " + root.pct.toString().padStart(3, " ") + "%"
        }
        color: {
            if (root.critical) return Root.Theme.pink
            if (root.warning) return Root.Theme.yellow
            if (root.charging || root.plugged) return Root.Theme.green
            return Root.Theme.bonewhite
        }
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold

        SequentialAnimation on opacity {
            running: root.critical
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.3; duration: 500 }
            NumberAnimation { from: 0.3; to: 1.0; duration: 500 }
        }
    }
}
```

- [ ] **Step 2: Add it to the system pill**

In `quickshell/shell.qml`'s system-pill `Row`, after `Modules.Volume
{}`, add (before Bluetooth/Network from Tasks 10–11, before Clock from
Task 12):

```qml
                        Modules.Battery {}
```

- [ ] **Step 3: Run it**

Run: `qs -c quickshell`
Expected: shows charge percentage with a level-appropriate icon; green
while charging/plugged; yellow at ≤30% unplugged; blinking pink at
≤15% unplugged — matching the `#battery.warning`/`#battery.critical`
rules in `waybar/style.css`.

- [ ] **Step 4: Commit**

```bash
git add quickshell/modules/Battery.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Battery module via UPower service"
```

---

### Task 10: Bluetooth module + popup

**Files:**
- Create: `quickshell/modules/Bluetooth.qml`
- Create: `quickshell/modules/BluetoothPopup.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.PopupPanel`,
  `Quickshell.Services.Bluetooth`.
- Produces: `Bluetooth` component (added to the system pill),
  `BluetoothPopup` component (a `PopupWindow`, toggled by clicking
  `Bluetooth`) — this task also writes `PopupPanel.qml`, since it's the
  first popup-using task.

- [ ] **Step 1: Write `PopupPanel.qml`**

```qml
// quickshell/components/PopupPanel.qml
import QtQuick
import Quickshell
import ".."

PopupWindow {
    id: root
    default property alias content: inner.data
    implicitWidth: 260
    implicitHeight: inner.implicitHeight + 16
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, Theme.pillAlpha)
        radius: Theme.pillRadius

        Column {
            id: inner
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
        }
    }
}
```

- [ ] **Step 2: Register it**

```
# quickshell/components/qmldir
Pill 1.0 Pill.qml
PopupPanel 1.0 PopupPanel.qml
```

(This replaces the `qmldir` file from Task 2 — add the new line, keep
the existing `Pill` line.)

- [ ] **Step 3: Write `BluetoothPopup.qml`**

```qml
// quickshell/modules/BluetoothPopup.qml
import QtQuick
import Quickshell.Services.Bluetooth
import ".." as Root
import "../components" as Components

Components.PopupPanel {
    id: root
    property var anchorItem: null
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    visible: false

    content: [
        Row {
            width: parent.width
            Text {
                text: Bluetooth.defaultAdapter?.enabled ? "Bluetooth: on" : "Bluetooth: off"
                color: Root.Theme.bonewhite
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
            }
            MouseArea {
                width: parent.width; height: parent.height
                onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
        },
        Repeater {
            model: Bluetooth.defaultAdapter?.devices ?? []
            delegate: Rectangle {
                required property var modelData
                width: root.implicitWidth - 16
                height: 22
                color: "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.connected ? "󰃡 " : "󰃢 ") + modelData.name // 󰂱 / 󰂯
                    color: modelData.connected ? Root.Theme.sky : Root.Theme.bonewhite
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
        },
        Text {
            text: "󱖐 Scan"  // 󰑐
            color: Root.Theme.subtext1
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            MouseArea {
                anchors.fill: parent
                onClicked: Bluetooth.defaultAdapter.discovering = true
            }
        }
    ]
}
```

- [ ] **Step 4: Write `Bluetooth.qml`**

```qml
// quickshell/modules/Bluetooth.qml
import QtQuick
import Quickshell.Services.Bluetooth
import ".." as Root

Item {
    id: root
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool connected: (Bluetooth.defaultAdapter?.devices ?? []).some(d => d.connected)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.enabled ? (root.connected ? "󰃡" : "󰃠") : "󰃣" // 󰂱 / 󰂯 / 󰂲
        color: !root.enabled ? Root.Theme.overlay0 : (root.connected ? Root.Theme.sky : Root.Theme.bonewhite)
        font.family: Root.Theme.fontFamily
        font.pixelSize: 15
    }

    BluetoothPopup {
        id: popup
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = !popup.visible
    }
}
```

- [ ] **Step 5: Add it to the system pill**

In `quickshell/shell.qml`'s system-pill `Row`, after `Modules.Battery
{}` (order doesn't affect functionality, but to mirror
`group/system`'s `["backlight", "pulseaudio", "bluetooth", "network",
"battery", "clock"]`, insert `Modules.Bluetooth {}` and `Modules.Network
{}` — from Task 11 — between Volume and Battery instead. Adjust the
ordering from Tasks 7–9 now: the final `Row` order should read
`Backlight, Volume, Bluetooth, Network, Battery, Clock`.):

```qml
                        Modules.Backlight {}
                        Modules.Volume {}
                        Modules.Bluetooth {}
                        Modules.Battery {}
```

(`Modules.Network {}` is added in Task 11, between Bluetooth and
Battery.)

- [ ] **Step 6: Run it**

Run: `qs -c quickshell`
Expected: bluetooth icon reflects adapter state (dim overlay0 = off,
bonewhite = on/disconnected, sky = connected); clicking opens a popup
pill below it listing paired devices with connect/disconnect on click,
matching `bt-menu.sh`'s behavior.

- [ ] **Step 7: Commit**

```bash
git add quickshell/components/PopupPanel.qml quickshell/components/qmldir quickshell/modules/Bluetooth.qml quickshell/modules/BluetoothPopup.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Bluetooth module with native device popup"
```

---

### Task 11: Network module + popup

**Files:**
- Create: `quickshell/modules/Network.qml`
- Create: `quickshell/modules/NetworkPopup.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.PopupPanel`, `nmcli` via `Process`
  (no QuickShell singleton for NetworkManager).
- Produces: `Network` component (added to the system pill between
  Bluetooth and Battery), `NetworkPopup` component reimplementing
  `wifi-menu.sh`'s parsing logic natively.

- [ ] **Step 1: Write `NetworkPopup.qml`**

```qml
// quickshell/modules/NetworkPopup.qml
import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components

Components.PopupPanel {
    id: root
    property var anchorItem: null
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    visible: false
    property var networks: []

    onVisibleChanged: if (visible) refresh()

    function refresh() {
        list.running = true
    }

    function bars(signal) {
        if (signal > 75) return "▰▰▰▰"
        if (signal > 50) return "▰▰▰▱"
        if (signal > 25) return "▰▰▱▱"
        return "▰▱▱▱"
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set()
                const rows = []
                for (const line of text.trim().split("\n")) {
                    if (!line) continue
                    const [inUse, signal, security, ...rest] = line.split(":")
                    const ssid = rest.join(":")
                    if (!ssid || seen.has(ssid)) continue
                    seen.add(ssid)
                    rows.push({ inUse: inUse === "*", signal: parseInt(signal), secured: security !== "" && security !== "--", ssid })
                }
                rows.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
                root.networks = rows
            }
        }
    }

    Process {
        id: connector
        property string ssid: ""
        property string password: ""
        command: password.length > 0
            ? ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", ssid]
        onExited: root.refresh()
    }

    content: [
        Repeater {
            model: root.networks
            delegate: Rectangle {
                required property var modelData
                width: root.implicitWidth - 16
                height: 22
                color: "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        text: modelData.ssid
                        color: modelData.inUse ? Root.Theme.sky : Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                    }
                    Text {
                        text: root.bars(modelData.signal) + (modelData.secured ? " 󰂼" : "") // 
                        color: Root.Theme.subtext1
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        connector.ssid = modelData.ssid
                        connector.password = ""
                        connector.running = true
                    }
                }
            }
        },
        Text {
            text: "󰖎 Rescan" // 
            color: Root.Theme.subtext1
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            MouseArea {
                anchors.fill: parent
                onClicked: root.refresh()
            }
        }
    ]
}
```

- [ ] **Step 2: Write `Network.qml`**

```qml
// quickshell/modules/Network.qml
import QtQuick
import Quickshell.Io
import ".." as Root

Item {
    id: root
    property string state: "disconnected" // "wifi" | "ethernet" | "disconnected" | "disabled"
    property int signalPct: 0

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: {
            if (root.state === "wifi") return "󰤭 " + root.signalPct + "%" // 
            if (root.state === "ethernet") return "󰌿 Wired" // 
            if (root.state === "disabled") return "󰍮" // 
            return "󰍚" // 
        }
        color: root.state === "disconnected" ? Root.Theme.red
             : root.state === "disabled" ? Root.Theme.overlay0
             : Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    NetworkPopup {
        id: popup
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = !popup.visible
    }

    Process {
        id: status
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "dev", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const wifi = lines.find(l => l.startsWith("wifi:"))
                const eth = lines.find(l => l.startsWith("ethernet:"))
                if (eth && eth.endsWith(":connected")) root.state = "ethernet"
                else if (wifi && wifi.endsWith(":connected")) root.state = "wifi"
                else if (wifi && wifi.endsWith(":unavailable")) root.state = "disabled"
                else root.state = "disconnected"
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: status.running = true
    }
}
```

- [ ] **Step 3: Add it to the system pill**

In `quickshell/shell.qml`, add `import "modules" as Modules` reference
to `NetworkPopup`/`Network` is automatic via the `Modules` namespace
already imported in Task 4. Update the system-pill `Row` order from
Task 10 to:

```qml
                        Modules.Backlight {}
                        Modules.Volume {}
                        Modules.Bluetooth {}
                        Modules.Network {}
                        Modules.Battery {}
```

- [ ] **Step 4: Run it**

Run: `qs -c quickshell`
Expected: icon reflects current connection type/state (wifi % / wired /
disabled / disconnected-red, matching `#network.disabled`/
`#network.disconnected` styling); clicking opens a popup listing nearby
SSIDs sorted by signal with the in-use network pinned to the top,
matching `wifi-menu.sh`.

- [ ] **Step 5: Commit**

```bash
git add quickshell/modules/Network.qml quickshell/modules/NetworkPopup.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Network module with native wifi popup"
```

---

### Task 12: Clock module + calendar popup

**Files:**
- Create: `quickshell/modules/Clock.qml`
- Create: `quickshell/modules/CalendarPopup.qml`
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Components.PopupPanel`, native QML `Date`/`Timer`.
- Produces: `Clock` component (last module in the system pill),
  `CalendarPopup` component (right-click on `Clock`).

- [ ] **Step 1: Write `CalendarPopup.qml`**

```qml
// quickshell/modules/CalendarPopup.qml
import QtQuick
import ".." as Root
import "../components" as Components

Components.PopupPanel {
    id: root
    property var anchorItem: null
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    visible: false
    property date viewDate: new Date()

    function monthGrid() {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        const startOffset = first.getDay()
        const daysInMonth = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < startOffset; i++) cells.push(null)
        for (let d = 1; d <= daysInMonth; d++) cells.push(d)
        return cells
    }

    content: [
        Text {
            text: Qt.formatDate(root.viewDate, "MMMM yyyy")
            color: Root.Theme.mauve
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.bold: true
        },
        Grid {
            columns: 7
            spacing: 2
            Repeater {
                model: root.monthGrid()
                delegate: Text {
                    required property var modelData
                    required property int index
                    width: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData ? modelData.toString() : ""
                    color: {
                        if (!modelData) return "transparent"
                        const today = new Date()
                        const isToday = modelData === today.getDate()
                            && root.viewDate.getMonth() === today.getMonth()
                            && root.viewDate.getFullYear() === today.getFullYear()
                        return isToday ? Root.Theme.pink : Root.Theme.sky
                    }
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSize
                }
            }
        },
        Row {
            spacing: 10
            Text {
                text: "‹ prev"
                color: Root.Theme.subtext1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
                }
            }
            Text {
                text: "next ›"
                color: Root.Theme.subtext1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
                }
            }
        }
    ]
}
```

- [ ] **Step 2: Write `Clock.qml`**

```qml
// quickshell/modules/Clock.qml
import QtQuick
import ".." as Root

Item {
    id: root
    property date now: new Date()
    property bool altFormat: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.altFormat
            ? Qt.formatDateTime(root.now, "ddd dd MMM | HH:mm:ss")
            : Qt.formatDateTime(root.now, "HH:mm:ss")
        color: Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    CalendarPopup {
        id: popup
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.altFormat = !root.altFormat
            else popup.visible = !popup.visible
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
```

- [ ] **Step 3: Add it to the system pill**

In `quickshell/shell.qml`'s system-pill `Row`, append after
`Modules.Battery {}`:

```qml
                        Modules.Clock {}
```

- [ ] **Step 4: Run it**

Run: `qs -c quickshell`
Expected: clock ticks every second in `HH:mm:ss`; left-click toggles to
the `ddd dd MMM | HH:mm:ss` alt format; right-click opens a calendar
popup showing the current month with today highlighted in pink and
prev/next navigation.

- [ ] **Step 5: Commit**

```bash
git add quickshell/modules/Clock.qml quickshell/modules/CalendarPopup.qml quickshell/shell.qml
git commit -m "feat(quickshell): add Clock module with native calendar popup"
```

---

### Task 13: Cut over Sway to QuickShell

**Files:**
- Modify: `sway/config:247`

**Interfaces:**
- Consumes: the fully working `quickshell/shell.qml` from Tasks 1–12.
- Produces: Sway launching QuickShell as the status bar instead of
  waybar.

- [ ] **Step 1: Side-by-side check before cutting over**

With waybar still running as the active `swaybar_command`, run
`qs -c quickshell` manually in a terminal and compare every module
against the live waybar bar one more time: workspaces, window title,
tray, backlight scroll, volume scroll/click, bluetooth popup connect,
network popup connect, battery color states, clock click/right-click.
Fix anything that doesn't match before proceeding.

- [ ] **Step 2: Read the current line**

Read `sway/config` around line 247 to confirm the exact surrounding
`bar { ... }` block hasn't shifted.

- [ ] **Step 3: Swap the bar command**

Edit `sway/config`, replacing:

```
    swaybar_command waybar
```

with:

```
    swaybar_command qs -c quickshell
```

(Use whichever binary name Task 1 confirmed — `qs` or `quickshell`.)

- [ ] **Step 4: Reload Sway**

Run: `swaymsg reload`
Expected: waybar disappears, the QuickShell bar takes its place with no
gap in bar coverage, all modules render and behave as verified in Step
1.

- [ ] **Step 5: Commit**

```bash
git add sway/config
git commit -m "feat(sway): switch status bar from waybar to quickshell"
```

---

### Task 14: Remove waybar

**Files:**
- Modify: `Knotfile`
- Delete: `waybar/` (entire directory)

**Interfaces:**
- Consumes: Task 13's confirmed-working QuickShell cutover.
- Produces: waybar fully removed from the repo and from the live
  system.

- [ ] **Step 1: Live with the QuickShell bar for normal daily use first**

Do not proceed with this task in the same sitting as Task 13 — this
step is a deliberate pause, not an automated wait. Come back to this
task only once you've used the QuickShell bar through normal daily
work (a full day is a reasonable bar) without issues.

- [ ] **Step 2: Unlink and remove the waybar package**

Run: `knot untie waybar` (or equivalent — check `knot --help` for the
exact unlink command if `untie` isn't it)
Remove the `waybar:` entry from `Knotfile`.

- [ ] **Step 3: Delete the waybar directory**

Run: `git rm -r waybar/`

This removes `waybar/config`, `waybar/colors.css`, `waybar/style.css`,
`waybar/modules-{left,center,right}.jsonc`, and
`waybar/scripts/{bt-menu,wifi-menu,bt-toggle,powermenu}.sh` — all four
scripts, since `bt-menu.sh`/`wifi-menu.sh` are now replaced by the
native popups and `bt-toggle.sh`/`powermenu.sh` are referenced only by
`sway/config`'s XF86Bluetooth keybinding and the (already-inactive)
power button. Before removing, grep `sway/config` for any remaining
reference to `waybar/scripts/` and update those keybindings to point at
a preserved copy of `bt-toggle.sh` if still needed — re-add just that
one script under a suitable location (e.g. a new small `scripts/`
Knotfile package, or inline the two-line rfkill logic directly into the
sway keybinding) rather than deleting a still-used script.

- [ ] **Step 4: Verify Sway config integrity**

Run: `grep -n "waybar" sway/config`
Expected: no output (or only the retained hardware-key binding if you
relocated `bt-toggle.sh` per Step 3 — in which case the path in that
grep result should point at its new location, not the deleted
`waybar/scripts/`).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove waybar now that quickshell is the active bar"
```

---

## Self-Review Notes

- **Spec coverage:** every module in the spec's scope table (Workspaces,
  WindowTitle, Tray, Backlight, Volume, Bluetooth+popup, Network+popup,
  Battery, Clock+popup) has a task. Package structure, Theme, layout,
  Knotfile entry, sway cutover, and waybar removal from the spec's
  "Migration order" are Tasks 1–3 and 13–14.
- **Non-goals respected:** no task touches `mpd`, `cava`, `custom/swap`,
  `sway/mode`, `custom/launcher`, `custom/power`,
  `custom/keyboard-layout`, `swaync`, `wofi`, or `wlogout`.
- **Type/name consistency:** `Theme` property names match
  `waybar/colors.css` 1:1 and are used identically across all module
  tasks (`Theme.bonewhite`, `Theme.pink`, etc.). `Components.Pill` and
  `Components.PopupPanel` signatures (`content` default alias,
  `horizontalPadding`) are defined once in Task 2/10 and reused
  identically in every later task. The `Modules` import alias
  established in Task 4 is reused, not redefined, in every subsequent
  task.
