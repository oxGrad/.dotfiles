# Morphing Center Clock Island (Calendar phase) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static center clock pill in the quickshell bar with a
single `Rectangle` that morphs downward into a calendar panel on click, per
`center-island.md`. Media view is explicitly out of scope for this plan (see
Deferred section).

**Architecture:** Two layer-shell windows, per the spec. `shell.qml`'s
existing bar `PanelWindow` keeps only the left/right segments. A new
fullscreen, transparent, `exclusiveZone: 0` `PanelWindow`
(`modules/island/CenterIsland.qml`) renders the pill/panel and toggles its
input mask between "just the pill" (collapsed/peek) and "whole screen"
(open, so an outside click can close it) — the same overlay-window shape
already proven in this repo by `modules/LauncherPopup.qml`.

**Tech Stack:** Quickshell (QML/Qt6), sway (wlroots layer-shell), no new
dependencies.

**Spec:** `center-island.md` (repo root)

## Global Constraints

- No color literals in new components — everything through `Theme.qml`
  (already a `pragma Singleton` at `quickshell/Theme.qml`, registered in
  `quickshell/qmldir`).
- Every size and duration named in the spec goes in a new `Config.qml`
  singleton, not inline in components.
- `implicitWidth`/`implicitHeight` of the morph `Rectangle` are bound to
  explicit per-state sizes from `Config.qml`, never to content's own
  `implicitWidth`/`implicitHeight` (causes jitter — called out explicitly in
  the spec).
- `clip: true` on the morph `Rectangle`.
- The clock digits are ONE `Text` item that lives for the lifetime of the
  window and is never destroyed/recreated across state changes (spec calls
  this out as the detail that "makes it read as a morph").
- Never set exclusive/blocking keyboard focus while collapsed.
- No `HyprlandFocusGrab` or any Hyprland-only API — this is sway.

## Deviations from the literal spec (and why)

- **File layout:** spec suggests `config/Theme.qml` + `config/Config.qml`.
  `Theme.qml` already lives at `quickshell/Theme.qml` (repo root of the
  package) and every existing module imports it as `import ".." as Root` →
  `Root.Theme.x`. Moving it into a `config/` folder means touching every
  existing module's import path for no behavioral gain. `Config.qml` is
  added next to `Theme.qml` instead, same pattern, zero churn to existing
  files.
- **Keyboard focus:** ~~originally deviated from the spec's suggested
  `WlrLayershell.keyboardFocus`~~ **retracted during Task 7's live testing.**
  The plan initially reused `LauncherPopup.qml`'s plain `focusable: bool`
  property, reasoning it already solved "focus only while open" on this
  compositor. Live testing during Task 7 disproved this for a
  keybind-triggered open specifically: `focusable` alone only grants
  keyboard focus when sway's focus-follows-mouse (default `yes`, not
  overridden in this repo's `sway/config`) already has the cursor over the
  surface. An IPC-triggered open (`qs ipc call island toggle calendar`,
  which Task 8's `$mod+c` binding also does) doesn't move the cursor, so
  Escape was confirmed live to be delivered to whatever window the cursor
  actually sat over, not the island — reproducing `LauncherPopup.qml`'s own
  documented caveat ("real keyboard delivery... confirmed live by hovering
  the mouse over the window"), which is fine for a launcher a user clicks
  into but not for a keybind meant to work without touching the mouse. The
  spec's original suggestion was right for this specific interaction:
  `Quickshell.Wayland`'s `WlrLayershell.keyboardFocus` (`Exclusive` while
  open, `None` while collapsed) requests real seat keyboard focus from the
  compositor regardless of cursor position. `LauncherPopup.qml` is left
  exactly as-is (out of scope, still works for its own click-driven flow).
- **Multi-monitor focused-output routing:** spec wants the IPC toggle to hit
  only the island on sway's currently-focused output, via the I3 module
  (this repo doesn't use `Quickshell.I3` anywhere — `Workspaces.qml` shells
  out to `swaymsg -t subscribe` instead, which is the established pattern
  here). This machine currently has exactly one output. Building and
  live-testing focused-output routing with no second monitor to verify it
  against is exactly the kind of speculative complexity to skip. The single
  `IpcHandler` lives in `shell.qml` and drives one shared `mode`/`open`
  state consumed by every per-screen `CenterIsland` instance (there's only
  ever one instance today, so this is indistinguishable from "correct"
  multi-monitor routing right now).
  `ponytail: shared single state across all screens, not per-focused-output — add swaymsg-based output-focus tracking (mirroring Workspaces.qml's subscribe pattern) if/when a second monitor is in play.`
- **`Theme.accent`:** spec references `Theme.accent` for "today" in the
  calendar and for the selected/highlight state; no such property exists.
  The existing `CalendarPopup.qml` (being replaced) already highlights
  "today" with `Theme.pink` — reused as-is rather than inventing a new
  theme property for one use site.
- **Existing app launcher:** `Clock.qml` currently also hosts an unrelated
  feature — an IPC-triggered app launcher (`IpcHandler { target: "launcher" }`
  + `LauncherPopup.qml`), anchored to the clock pill only for convenience.
  It has no calendar/clock overlap. Task 2 relocates it to `shell.qml`
  unchanged before `Clock.qml` is deleted in Task 3, so that feature (built
  in the last two commits before this session) doesn't silently regress.

## Deferred (not in this plan)

- `media` mode / `MediaView.qml` / `Quickshell.Services.Mpris` — "start with
  the calendar first" per the user. Tracked for a follow-up plan.
- `Tab` cycling between calendar/media (nothing to cycle to yet).
- Right-click / middle-click → media toggle on the island (no media mode to
  toggle to yet — left unbound rather than wired to a no-op).
- matugen live palette watching (`FileView { watchChanges: true }`) — spec
  itself says "if matugen is already generating a palette"; it isn't, in
  this repo. `Theme.qml` stays a static singleton like every other module
  already assumes.
- SwayFX `layer_effects` blur/shadow — spec marks this optional and
  compositor-specific; skip until confirmed SwayFX is actually in use.

## File Layout

```
quickshell/
  Config.qml                      # NEW singleton: sizes, durations, easings
  qmldir                          # MODIFY: register Config as a singleton
  shell.qml                       # MODIFY: remove Modules.Clock from bar,
                                   #   add CenterIsland per screen, host the
                                   #   relocated launcher IpcHandler+popup
  modules/
    Clock.qml                     # DELETE (superseded)
    CalendarPopup.qml             # DELETE (superseded)
    LauncherPopup.qml             # unchanged, just re-hosted from shell.qml
    island/
      CenterIsland.qml            # NEW: overlay PanelWindow, state machine,
                                   #   mask, click-catcher, IPC target "island"
      ClockLabel.qml               # NEW: persistent morphing clock Text
      CalendarView.qml             # NEW: month grid + header + key nav
```

---

### Task 1: `Config.qml` — sizes and durations singleton

**Files:**
- Create: `quickshell/Config.qml`
- Modify: `quickshell/qmldir`

**Interfaces:**
- Produces: singleton `Config` (import via `import ".." as Root` from any
  module, referenced as `Root.Config.<name>`, exactly like `Root.Theme`
  today) with:
  - `property size collapsedSize` — `Qt.size(110, 26)`
  - `property size peekSize` — `Qt.size(240, 26)`
  - `property size calendarSize` — `Qt.size(360, 400)`
  - `property int barTopMargin` — `4` (must match `shell.qml`'s bar
    `margins.top`, so the collapsed pill lines up exactly with the old one)
  - `property int expandDuration` — `400`
  - `property int collapseDuration` — `300`
  - `property int radiusDuration` — `300`
  - `property int colorDuration` — `300`
  - `property int contentFadeOutDuration` — `120`
  - `property int contentFadeInDuration` — `200`
  - `property int contentFadeInDelay` — `150`
  - `property int contentSlideOffset` — `8`
  - `property int hoverDebounce` — `150`
  - `property int clockCollapsedPixelSize` — `13`
  - `property int clockOpenPixelSize` — `34`

- [ ] **Step 1: Write `Config.qml`**

```qml
// quickshell/Config.qml
pragma Singleton
import QtQuick

QtObject {
    readonly property size collapsedSize: Qt.size(110, 26)
    readonly property size peekSize: Qt.size(240, 26)
    readonly property size calendarSize: Qt.size(360, 400)

    // Must match shell.qml's bar `margins.top` so the collapsed island
    // lines up exactly where the old clock pill sat.
    readonly property int barTopMargin: 4

    readonly property int expandDuration: 400
    readonly property int collapseDuration: 300
    readonly property int radiusDuration: 300
    readonly property int colorDuration: 300

    readonly property int contentFadeOutDuration: 120
    readonly property int contentFadeInDuration: 200
    readonly property int contentFadeInDelay: 150
    readonly property int contentSlideOffset: 8

    readonly property int hoverDebounce: 150

    readonly property int clockCollapsedPixelSize: 13
    readonly property int clockOpenPixelSize: 34
}
```

- [ ] **Step 2: Register it in `qmldir`**

Current `quickshell/qmldir`:
```
singleton Theme 1.0 Theme.qml
```

New:
```
singleton Theme 1.0 Theme.qml
singleton Config 1.0 Config.qml
```

- [ ] **Step 3: Verify quickshell still starts cleanly**

```bash
pkill -x qs; sleep 1; swaymsg reload; sleep 2
pgrep -x qs
journalctl --user -b --no-pager | tail -15
```
Expected: `qs` PID printed, no new `ERROR`/`WARN` lines about `Config` or
QML parse errors. `Config` isn't referenced anywhere yet, so this only
proves the singleton registration itself is valid.

- [ ] **Step 4: Commit**

```bash
git add quickshell/Config.qml quickshell/qmldir
git commit -m "feat(quickshell): add Config singleton for island sizes/durations"
```

---

### Task 2: Relocate the app launcher out of `Clock.qml`

**Files:**
- Modify: `quickshell/shell.qml`
- Modify: `quickshell/modules/Clock.qml` (only to remove what moved, ahead
  of full deletion in Task 3)

**Interfaces:**
- Consumes: `Modules.LauncherPopup` (unchanged component,
  `quickshell/modules/LauncherPopup.qml`), `Quickshell.Io.IpcHandler`.
- Produces: nothing new — same `qs ipc call launcher toggle` behavior,
  just hosted from `shell.qml` instead of `Clock.qml`.

- [ ] **Step 1: Move the launcher block into `shell.qml`**

In `quickshell/shell.qml`, inside each per-screen `PanelWindow`, after the
existing `rightSection` `Row`, add:

```qml
            property bool launcherOpen: false

            Modules.LauncherPopup {
                id: launcher
                anchorItem: centerSection
                open: launcherOpen
                onDismissed: launcherOpen = false
            }

            IpcHandler {
                target: "launcher"
                function toggle() {
                    launcherOpen = !launcherOpen
                }
            }
```

`anchorItem: centerSection` (the existing `Row` holding `Modules.Clock {}`)
replaces the old `anchorItem: root` (Clock.qml's own root `Item`) — same
role (something with a sensible collapsed width/height for the popup's
initial size), just a different, still-valid anchor now that the launcher
no longer lives inside Clock.qml itself. `centerSection` keeps its current
size (holds `Modules.Clock {}` still, until Task 3) at this point in the
plan, so this step alone changes no visible behavior.

Add `import Quickshell.Io` to `shell.qml`'s imports (needed for
`IpcHandler`; not currently imported there since the bar didn't have any
IPC before).

- [ ] **Step 2: Remove the moved block from `Clock.qml`**

In `quickshell/modules/Clock.qml`, delete:
```qml
    property bool launcherOpen: false
```
```qml
    LauncherPopup {
        id: launcher
        anchorItem: root
        open: root.launcherOpen
        onDismissed: root.launcherOpen = false
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            root.launcherOpen = !root.launcherOpen
        }
    }
```
Leave everything else in `Clock.qml` untouched for now (it's deleted
wholesale in Task 3; this step only proves the launcher survives the move
before that happens).

`Clock.qml`'s `import Quickshell.Io` stays (still used by the `Timer`... no
— `Timer` is QtQuick core, not `Quickshell.Io`. Check: if nothing else in
`Clock.qml` uses `Quickshell.Io` after this removal, remove that import
line too, to avoid an unused-import lint warning.

- [ ] **Step 3: Verify the launcher still works from its new home**

```bash
pkill -x qs; sleep 1; swaymsg reload; sleep 2
qs ipc call launcher toggle
sleep 1
grim -g "$(swaymsg -t get_outputs | python3 -c 'import json,sys; o=json.load(sys.stdin)[0]["rect"]; print(f"{o[\"x\"]},{o[\"y\"]} {o[\"width\"]}x{o[\"height\"]}")')" /tmp/claude-1000/-home-graditya--dotfiles/*/scratchpad/launcher-open.png
qs ipc call launcher toggle
journalctl --user -b --no-pager | tail -15
```
Expected: screenshot shows the launcher panel open under the bar's center;
second `toggle` call closes it; no new `ERROR` lines in the journal.

- [ ] **Step 4: Commit**

```bash
git add quickshell/shell.qml quickshell/modules/Clock.qml
git commit -m "refactor(quickshell): host the launcher popup from shell.qml, not Clock.qml"
```

---

### Task 3: Delete `Clock.qml` and `CalendarPopup.qml`

**Files:**
- Delete: `quickshell/modules/Clock.qml`
- Delete: `quickshell/modules/CalendarPopup.qml`
- Modify: `quickshell/shell.qml` (remove the now-dead `centerSection` Row
  and its `Modules.Clock {}` child — the new `CenterIsland`, added in
  Task 7, takes over rendering the center pill from its own overlay window)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. Purely subtractive — both files are fully superseded:
  `Clock.qml`'s clock+calendar-popup role by `CenterIsland`/`ClockLabel`/
  `CalendarView` (Tasks 4-6), and its launcher-hosting role already moved
  out in Task 2.

- [ ] **Step 1: Delete the files**

```bash
git rm quickshell/modules/Clock.qml quickshell/modules/CalendarPopup.qml
```

- [ ] **Step 2: Remove the dead center section from `shell.qml`**

Remove:
```qml
            Row {
                id: centerSection
                anchors.centerIn: parent
                spacing: 6

                Modules.Clock {}
            }
```

The bar will render with an empty gap where the clock was until Task 7
adds `CenterIsland` back (from the separate overlay window) — that's
expected and temporary within this plan's own task sequence.

- [ ] **Step 3: Verify quickshell still starts cleanly**

```bash
pkill -x qs; sleep 1; swaymsg reload; sleep 2
pgrep -x qs
journalctl --user -b --no-pager | tail -15
```
Expected: `qs` running, no errors. (No screenshot check here — an empty bar
center is the expected, temporary intermediate state.)

- [ ] **Step 4: Commit**

```bash
git add -A quickshell/
git commit -m "refactor(quickshell): remove clock pill, superseded by CenterIsland"
```

---

### Task 4: `ClockLabel.qml` — the persistent morphing clock text

**Files:**
- Create: `quickshell/modules/island/ClockLabel.qml`

**Interfaces:**
- Consumes: `Root.Theme.bonewhite`, `Root.Theme.fontFamily`,
  `Root.Config.clockCollapsedPixelSize`, `Root.Config.clockOpenPixelSize`
  (from `Task 1`/existing `Theme.qml`).
- Produces: component `ClockLabel` with `property bool open` (external
  binding drives collapsed-vs-open sizing/position; consumed by
  `CenterIsland.qml` in Task 6). Exposes `readonly property date now` in
  case a consumer wants the raw value, but the component renders its own
  text.

This is the ONE clock `Text` per the spec — it must never be destroyed by
the mode `Loader` in `CenterIsland.qml`. It lives as a direct, permanent
child of the island `Rectangle`, sized/positioned by its own `open`
property, while `CalendarView` (loaded/unloaded by the `Loader`) reads time
from nowhere — it only needs the date for the month grid, which it computes
itself.

- [ ] **Step 1: Write `ClockLabel.qml`**

```qml
// quickshell/modules/island/ClockLabel.qml
import QtQuick
import "../.." as Root

Text {
    id: root
    property bool open: false
    readonly property date now: clock.now

    text: Qt.formatDateTime(now, "HH:mm:ss")
    color: Root.Theme.bonewhite
    font.family: Root.Theme.fontFamily
    font.weight: Font.DemiBold
    font.pixelSize: open ? Root.Config.clockOpenPixelSize : Root.Config.clockCollapsedPixelSize

    Behavior on font.pixelSize {
        NumberAnimation { duration: Root.Config.expandDuration; easing.type: Easing.OutExpo }
    }
    Behavior on x {
        NumberAnimation { duration: Root.Config.expandDuration; easing.type: Easing.OutExpo }
    }
    Behavior on y {
        NumberAnimation { duration: Root.Config.expandDuration; easing.type: Easing.OutExpo }
    }

    QtObject {
        id: clock
        property date now: new Date()
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }
}
```

Positioning (`x`/`y` anchors vs. explicit coordinates for the
collapsed-centered / open-top-left placement) is set from the parent in
Task 6, since it depends on the island `Rectangle`'s current size — this
component only owns its own font size and animates whatever `x`/`y` its
parent assigns it.

- [ ] **Step 2: Verify it's syntactically valid**

Not wired into anything yet. Confirm QML parses:
```bash
qs -p quickshell/modules/island/ClockLabel.qml 2>&1 | head -20
```
(`qs -p` type-checks/previews a single file without needing the full shell
running — if this flag doesn't exist in the installed `qs` version, skip
straight to Task 6's live verification instead, where this component is
actually instantiated.)

- [ ] **Step 3: Commit**

```bash
git add quickshell/modules/island/ClockLabel.qml
git commit -m "feat(quickshell): add persistent morphing ClockLabel for the island"
```

---

### Task 5: `CalendarView.qml` — month grid content

**Files:**
- Create: `quickshell/modules/island/CalendarView.qml`

**Interfaces:**
- Consumes: `Root.Theme.bonewhite`, `Root.Theme.subtext0`,
  `Root.Theme.pink` (today highlight, see Deviations), `Root.Theme.fontFamily`.
- Produces: component `CalendarView` with:
  - `property date viewDate` (defaults to today; read/write — `CenterIsland`
    doesn't need to touch it directly, but exposing it keeps the component
    testable in isolation and matches the "Home returns to today" key
    needing an external reset path if ever driven from outside)
  - Handles its own `Left`/`Right`/`Home` keys via `Keys.onPressed` — but
    only receives key events at all when it has active focus, which
    `CenterIsland.qml` grants in Task 6 by giving it `focus: true` while
    loaded.

This is the existing `CalendarPopup.qml` month-grid logic (dropped in
Task 3), lifted out of the `Components.PopupPanel` wrapper it no longer
needs (no longer its own popup window — it's `Loader`-ed content inside
`CenterIsland`'s panel), given a header to match the spec's "big clock
header, full date underneath" requirement (the big clock itself is
`ClockLabel`, owned by `CenterIsland`; this component only adds the full
date line under it), and given `Left`/`Right`/`Home` key equivalents of the
existing click-driven prev/next.

- [ ] **Step 1: Write `CalendarView.qml`**

```qml
// quickshell/modules/island/CalendarView.qml
import QtQuick
import "../.." as Root

Column {
    id: root
    property date viewDate: new Date()
    spacing: 8
    focus: true

    function monthGrid() {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        const startOffset = first.getDay()
        const daysInMonth = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < startOffset; i++) cells.push(null)
        for (let d = 1; d <= daysInMonth; d++) cells.push(d)
        return cells
    }

    function shiftMonth(delta) {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1)
    }

    function goToday() {
        viewDate = new Date()
    }

    Keys.onLeftPressed: root.shiftMonth(-1)
    Keys.onRightPressed: root.shiftMonth(1)
    // `Keys.onHomePressed` isn't a real Qt Quick Keys convenience signal
    // (no dedicated handler exists for Home — confirmed live during Task 7,
    // the first time this file was actually instantiated: "Cannot assign
    // to non-existent property"). Generic Keys.onPressed + a key check is
    // the correct form for a key with no dedicated handler.
    Keys.onPressed: (event) => { if (event.key === Qt.Key_Home) root.goToday() }

    Text {
        text: Qt.formatDate(root.viewDate, "dddd, d MMMM yyyy")
        color: Root.Theme.subtext0
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    Row {
        spacing: 10
        Text {
            text: "‹"
            color: Root.Theme.subtext0
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(-1) }
        }
        Text {
            text: Qt.formatDate(root.viewDate, "MMMM yyyy")
            color: Root.Theme.bonewhite
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
        }
        Text {
            text: "›"
            color: Root.Theme.subtext0
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(1) }
        }
    }

    Grid {
        columns: 7
        spacing: 4
        Repeater {
            model: root.monthGrid()
            delegate: Text {
                required property var modelData
                width: 32
                horizontalAlignment: Text.AlignHCenter
                text: modelData ? modelData.toString() : ""
                color: {
                    if (!modelData) return "transparent"
                    const today = new Date()
                    const isToday = modelData === today.getDate()
                        && root.viewDate.getMonth() === today.getMonth()
                        && root.viewDate.getFullYear() === today.getFullYear()
                    return isToday ? Root.Theme.pink : Root.Theme.bonewhite
                }
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add quickshell/modules/island/CalendarView.qml
git commit -m "feat(quickshell): add CalendarView month grid for the island"
```

(Verified live as part of Task 6 — this component only renders meaningfully
once loaded inside the island panel.)

---

### Task 6: `CenterIsland.qml` — the overlay window and state machine

**Files:**
- Create: `quickshell/modules/island/CenterIsland.qml`

**Interfaces:**
- Consumes: `ClockLabel` (Task 4), `CalendarView` (Task 5), `Root.Theme.*`,
  `Root.Config.*` (Task 1).
- Produces: component `CenterIsland` with `required property var screen`
  (assigned by `shell.qml`'s `Variants` in Task 7) and externally-driven
  shared state consumed the same way from every screen instance:
  `property string mode` (`"collapsed" | "peek" | "calendar"`) and
  `property bool open`, both expected to be bound from `shell.qml`'s shared
  state (see Task 7) rather than owned locally — this is what makes the
  single `IpcHandler` in `shell.qml` control every screen's island (see
  the multi-monitor deviation note).

- [ ] **Step 1: Write `CenterIsland.qml`**

```qml
// quickshell/modules/island/CenterIsland.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.." as Root

PanelWindow {
    id: root
    required property var screen
    // `mode`/`open` are meant to be bound from shell.qml's shared state
    // (Task 7: `mode: islandMode; open: islandOpen`), the same one-way-down
    // direction shell.qml already uses for `Modules.LauncherPopup.open` in
    // Task 2. Writing to a property from inside the component that also has
    // an external binding on it permanently severs that binding on first
    // write — this file's own LauncherPopup.qml documents this exact
    // footgun (see its `dismissed()` signal and the comment at its top).
    // So every user-initiated close/open in here goes out through a signal
    // instead of assigning to `open`/`mode` directly; shell.qml's handlers
    // for these signals own the actual writes to its shared state.
    property string mode: "collapsed"     // "collapsed" | "peek" | "calendar"
    property bool open: false

    signal openRequested(string requestedMode)
    signal closeRequested()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    focusable: open
    // `focusable` alone only grants keyboard focus if the compositor's own
    // focus-follows-mouse routing happens to already point at this surface
    // (sway's default is `focus_follows_mouse yes` — confirmed live: an
    // IPC-triggered open with the cursor elsewhere sent Escape to whatever
    // window the cursor was actually over, not the island). Exclusive mode
    // requests real seat keyboard focus from the compositor regardless of
    // cursor position, which a keybind-triggered open (Task 8) needs.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Collapsed/peek: only the pill itself is clickable, the rest of this
    // fullscreen window is click-through to whatever is behind it (same
    // technique LauncherPopup.qml uses). Open: the whole window becomes
    // clickable so clickCatcher below can see, and close on, outside clicks.
    // A `Type {}` object declaration cannot be a ternary branch (invalid
    // QML — confirmed live during Task 7, the first time this file was
    // actually instantiated: "Expected token ','" at the `{`). A named
    // object referenced by id is the correct form here.
    mask: root.open ? null : maskRegion
    Region { id: maskRegion; item: island }

    Keys.onEscapePressed: root.closeRequested()

    function toggle(requestedMode) {
        if (root.open && root.mode === requestedMode) {
            root.closeRequested()
        } else {
            root.openRequested(requestedMode)
        }
    }

    // Sits below `island` in z-order (declared first) so clicks on the
    // island itself are consumed by the island's own content first and
    // never reach this catcher.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: Root.Config.barTopMargin

        implicitWidth: root.mode === "calendar" ? Root.Config.calendarSize.width
                     : peeking && !root.open ? Root.Config.peekSize.width
                     : Root.Config.collapsedSize.width
        implicitHeight: root.mode === "calendar" ? Root.Config.calendarSize.height
                      : peeking && !root.open ? Root.Config.peekSize.height
                      : Root.Config.collapsedSize.height

        property bool peeking: false
        radius: root.open ? 20 : height / 2
        color: Qt.rgba(Root.Theme.base.r, Root.Theme.base.g, Root.Theme.base.b, Root.Theme.pillAlpha)
        clip: true

        Behavior on implicitWidth {
            NumberAnimation {
                duration: root.open ? Root.Config.expandDuration : Root.Config.collapseDuration
                easing.type: Easing.OutExpo
            }
        }
        Behavior on implicitHeight {
            NumberAnimation {
                duration: root.open ? Root.Config.expandDuration : Root.Config.collapseDuration
                easing.type: Easing.OutExpo
            }
        }
        Behavior on radius {
            NumberAnimation { duration: Root.Config.radiusDuration; easing.type: Easing.OutQuad }
        }
        Behavior on color {
            ColorAnimation { duration: Root.Config.colorDuration }
        }

        // Debounced: brushing the pointer past the pill shouldn't flicker
        // it into `peek` size. `peeking` only flips true after the pointer
        // has stayed 150ms; it drops immediately on hover-out.
        HoverHandler {
            id: hover
            enabled: !root.open
            onHoveredChanged: {
                if (hovered) hoverDebounce.restart()
                else { hoverDebounce.stop(); island.peeking = false }
            }
        }
        Timer {
            id: hoverDebounce
            interval: Root.Config.hoverDebounce
            onTriggered: island.peeking = true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle("calendar")
        }

        ClockLabel {
            id: clockLabel
            open: root.open
            x: root.open ? 16 : (island.width - width) / 2
            y: root.open ? 16 : (island.height - height) / 2
        }

        Loader {
            id: content
            anchors.fill: parent
            anchors.topMargin: root.open ? 70 : 0
            anchors.margins: root.open ? 16 : 0
            active: root.mode === "calendar"
            sourceComponent: CalendarView {}
            opacity: root.open ? 1 : 0

            // A raw `y:` binding would fight `anchors.fill` (the anchor
            // engine re-asserts position on every relayout, silently
            // killing a plain y animation) — a transform composes on top
            // of the anchored layout instead, so the slide survives.
            transform: Translate {
                y: root.open ? 0 : Root.Config.contentSlideOffset
                Behavior on y {
                    NumberAnimation { duration: Root.Config.contentFadeInDuration; easing.type: Easing.OutQuad }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.open ? Root.Config.contentFadeInDelay : 0 }
                    NumberAnimation {
                        duration: root.open ? Root.Config.contentFadeInDuration : Root.Config.contentFadeOutDuration
                    }
                }
            }

            onLoaded: if (item) item.forceActiveFocus()
        }
    }
}
```

Notes for whoever implements this task:
- `peeking && !root.open` drives the `peek` size only while collapsed (per
  spec: "`peek` is hover only"), and `peeking` itself only flips true 150ms
  after the pointer enters (see the debounce `Timer` above — the spec calls
  out "a 150ms debounce so brushing past does not flicker it" explicitly).
  Once `open` is true the size is governed by `mode` instead, so hovering
  the open calendar panel doesn't fight its size.
- The `Behavior on opacity` uses a `SequentialAnimation` (pause, then fade)
  to get the spec's "fade out fast, geometry starts, THEN fade content in"
  sequencing without a second animation the `Loader`'s `active` flag would
  otherwise fight (`active: false` immediately destroys the item — there is
  intentionally no fade-out-then-unload for the calendar content itself
  beyond the opacity animation; unlike the fixed persistent `ClockLabel`,
  `CalendarView` is fine to destroy/recreate since it holds no animation
  state worth preserving across a full close).
- `island`'s own `MouseArea` (left-click → toggle calendar) is declared
  after `ClockLabel`/`Loader` in source order but doesn't need to be above
  them in z-order for hit-testing here since neither child currently
  installs a competing `MouseArea` over the same area — if a later task
  adds click targets inside `CalendarView` (e.g. the month arrows), Qt's
  normal "topmost/child gets it first" rule already lets those work,
  because `CalendarView`'s own arrow `MouseArea`s are declared inside a
  deeper child than `island`'s catch-all one.

- [ ] **Step 2: Verify collapsed state matches the old clock pill**

```bash
pkill -x qs; sleep 1; swaymsg reload; sleep 2
pgrep -x qs
journalctl --user -b --no-pager | tail -20
```
(No screenshot yet — `CenterIsland` isn't wired into `shell.qml` until
Task 7, so nothing new renders. This step only proves the file itself is
syntactically valid and doesn't error when nothing references it... which
it won't catch, since an unreferenced QML file is never parsed. Skip
straight to Task 7's live verification for anything meaningful — keep this
step only as a "did I break the existing bar" smoke check.)

- [ ] **Step 3: Commit**

```bash
git add quickshell/modules/island/CenterIsland.qml
git commit -m "feat(quickshell): add CenterIsland overlay window and morph state machine"
```

---

### Task 7: Wire `CenterIsland` into `shell.qml`

**Files:**
- Modify: `quickshell/shell.qml`

**Interfaces:**
- Consumes: `Island.CenterIsland` (Task 6) — bound properties `screen`/
  `mode`/`open`, and its two signals `openRequested(string requestedMode)`
  / `closeRequested()`. Task 6's `mode`/`open` are one-way-down bindings
  from shell.qml's shared state; CenterIsland never writes to them itself
  (see Task 6's file comment) — every user-initiated open/close reaches
  shell.qml only through these two signals, which is why this task's
  `Island.CenterIsland { ... }` block below must handle both, not just bind
  `mode`/`open` and stop there.
- Produces: the shared `islandMode`/`islandOpen` properties (and the
  `openIsland(mode)`/`closeIsland()` functions that are the only writers of
  them) that other future triggers (sway keybindings via IPC, Task 8)
  target.

- [ ] **Step 1: Add the import and shared state**

At the top of `shell.qml`, add:
```qml
import "modules/island" as Island
```

Inside `ShellRoot { Variants { ... } }`, but OUTSIDE the per-screen
`PanelWindow` (so it's shared across every screen instance, not
per-screen), add:
```qml
    property string islandMode: "collapsed"
    property bool islandOpen: false

    // The only two places that write islandMode/islandOpen — both the
    // IpcHandler below and every CenterIsland instance's signals (Step 2)
    // funnel through these, so "closed" always means the same thing
    // (mode reset to collapsed) regardless of which path triggered it.
    function openIsland(mode) {
        islandOpen = true
        islandMode = mode
    }
    function closeIsland() {
        islandOpen = false
        islandMode = "collapsed"
    }

    IpcHandler {
        target: "island"
        function toggle(mode: string): void {
            if (islandOpen && islandMode === mode) closeIsland()
            else openIsland(mode)
        }
        function close(): void {
            closeIsland()
        }
    }
```

(`ShellRoot` is a plain `Item`-like root Quickshell provides specifically
to hold cross-screen state and per-screen `Variants` side by side — this
mirrors how `shell.qml` already puts `Variants` directly under `ShellRoot`.)

- [ ] **Step 2: Instantiate the island per screen**

Add, as a sibling of the existing `Variants { PanelWindow { ... } }` block
(same `model: Quickshell.screens` pattern):
```qml
    Variants {
        model: Quickshell.screens

        Island.CenterIsland {
            required property var modelData
            screen: modelData
            mode: islandMode
            open: islandOpen
            onOpenRequested: (requestedMode) => openIsland(requestedMode)
            onCloseRequested: closeIsland()
        }
    }
```

This is the reason Task 6's `CenterIsland.qml` cannot write to its own
`open`/`mode` properties directly (see that task's file comment): they're
bound here (`mode: islandMode`, `open: islandOpen`), a one-way-down QML
property binding. If `CenterIsland.qml` ever assigned to `root.open` or
`root.mode` internally, that specific assignment would permanently sever
this binding from that point on — the next `qs ipc call island toggle ...`
would update `islandOpen`/`islandMode` in `shell.qml` but the island
actually on screen would no longer be listening, silently getting stuck at
whatever state it was in when the binding broke. `Island.CenterIsland`'s
`onOpenRequested`/`onCloseRequested` handlers above are what let a click
inside the island (or Escape) reach back out to the one shared state
`shell.qml` owns, instead of the island trying to mutate that state
directly.

Binding `mode`/`open` directly (not `Connections`) means every screen's
island mirrors the same shared state — see the multi-monitor deviation
note in the plan header.

- [ ] **Step 3: Verify against the full acceptance checklist subset that applies to calendar-only**

```bash
pkill -x qs; sleep 1; swaymsg reload; sleep 2
pgrep -x qs

# collapsed state should look like the old clock pill
grim /tmp/claude-1000/-home-graditya--dotfiles/*/scratchpad/island-collapsed.png

# open calendar
qs ipc call island toggle calendar
sleep 1
grim /tmp/claude-1000/-home-graditya--dotfiles/*/scratchpad/island-calendar.png

# outside click closes it — click somewhere clearly off the panel
swaymsg seat seat0 cursor set 50 50
# (a real click needs `wtype`/`ydotool` or a manual click; if neither tool
#  is installed, verify this one by hand and note it in the task's review)

# close via IPC either way, confirm re-toggle closes
qs ipc call island toggle calendar
sleep 1
grim /tmp/claude-1000/-home-graditya--dotfiles/*/scratchpad/island-closed.png

journalctl --user -b --no-pager | tail -30
```
Expected:
- `island-collapsed.png` visually matches the old center clock pill
  (position, size, font).
- `island-calendar.png` shows the panel expanded downward from the bar
  line with the big clock header and month grid.
- `island-closed.png` matches `island-collapsed.png` again.
- No new `ERROR` lines.
- Manually (can't be scripted without an input-injection tool): click on
  an empty desktop area while the calendar is open → it closes; press
  `Escape` while open → it closes; the digits never blink/reset during
  either transition.

- [ ] **Step 4: Commit**

```bash
git add quickshell/shell.qml
git commit -m "feat(quickshell): wire CenterIsland into the bar, replacing the static clock"
```

---

### Task 8: sway keybinding for calendar toggle

**Files:**
- Modify: `sway/config`

**Interfaces:**
- Consumes: `qs ipc call island toggle calendar` (Task 7's `IpcHandler`).

- [ ] **Step 1: Add the binding**

`$mod` is `Mod1` (`sway/config:12`). Confirmed free: neither `$mod+c` nor
`$mod+Shift+c` (already `reload`) collide. Add near the other `$mod+`
single-letter bindings (e.g. next to `$mod+d` at `sway/config:91`):
```
bindsym $mod+c exec qs ipc call island toggle calendar
```

- [ ] **Step 2: Verify**

```bash
swaymsg reload
sleep 1
swaymsg -t get_binding_state 2>/dev/null || true
```
Then manually press `$mod+c` (Alt+c) and confirm the island opens; press it
again and confirm it closes. (Same input-injection limitation as Task 7 —
this is a manual check.)

- [ ] **Step 3: Commit**

```bash
git add sway/config
git commit -m "feat(sway): bind \$mod+c to toggle the calendar island"
```

---

## Acceptance checklist coverage (calendar-only scope)

- [x] Collapsed island visually identical to the old center pill — Task 7.
- [x] Clicking through empty screen area while collapsed reaches the window
      below — `mask: null` only while `open`, per `CenterIsland.qml`.
- [x] Expanding does not resize/move tiled windows — overlay has
      `exclusiveZone: 0`, bar's own exclusive zone is untouched (Task 3
      only removes the bar's *content*, not its `implicitHeight`/margins).
- [x] Clock digits never disappear/restart — `ClockLabel` lives outside the
      `Loader`, Task 4/6.
- [ ] Escape closes it — confirmed BROKEN live during Task 7 despite two
      independently-correct fixes (`WlrLayershell.keyboardFocus`; moving
      `Keys.onEscapePressed` off the non-Item `PanelWindow` onto `island`).
      Root cause narrowed to the Qt/Wayland window-activation layer, beyond
      a QML-level fix's reach without `WAYLAND_DEBUG` tracing or a
      different Quickshell build. Parked (see ledger) — mitigated by two
      working close paths: re-invoking the same toggle IPC/keybind, and
      clicking the pill again. Outside click closes it — click-catcher
      `MouseArea`, Task 6 (manual verification only, no input-injection
      tool confirmed installed — genuinely unverified, not just untested
      by convention).
- [x] No exclusive keyboard focus while collapsed — `focusable: open` and
      `WlrLayershell.keyboardFocus: root.open ? Exclusive : None` (see
      Deviations) both gate on `open`, so `None`/non-focusable is the
      collapsed state in both.
- [ ] "Opening/closing 20 times leaks no Loader items / memory growth" —
      not verified in this plan (no automated memory-profiling step
      defined; flagged here rather than silently skipped).
- [ ] "Works on a fractionally scaled output without blurry text" — this
      machine has one output at what scale? not checked; flagged rather
      than silently assumed fine.
- N/A `media` state, `Tab` cycling, matugen live theming, SwayFX blur — all
  explicitly deferred, see Deferred section above.
