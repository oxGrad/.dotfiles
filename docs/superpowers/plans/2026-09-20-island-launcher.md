# Island Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the wofi-based `$mod+d` app launcher with a native QuickShell popup that morphs out of the clock pill ("dynamic island" style) instead of appearing centered on screen.

**Architecture:** A new `LauncherPopup.qml` module — a `PopupWindow` anchored to the existing `Clock` module, sized via `Behavior`-animated `implicitWidth`/`implicitHeight` that starts matching the clock pill's own size and grows into a search box + app list. `Clock.qml` gains an `IpcHandler` (target `"launcher"`) so a Sway keybinding can toggle it externally, replacing the current `exec $menu --show drun`. App data comes from Quickshell's native `DesktopEntries` singleton — no shelling out to wofi.

**Tech Stack:** QML (Quickshell 0.3.1), Sway 1.11, existing repo conventions (`Root.Theme` singleton, `Components.Pill`-style visuals reimplemented inline since the animated sizing doesn't fit `PopupPanel`'s fixed-size assumptions).

**Spec:** `docs/superpowers/specs/2026-09-20-island-launcher-design.md`

## Global Constraints

- Visual style must match the existing pill/popup look exactly:
  `Root.Theme.base` at `Root.Theme.pillAlpha` (0.92) background,
  `Root.Theme.pillRadius` (13) corner radius, `Root.Theme.bonewhite` text,
  `Root.Theme.fontFamily` ("JetBrainsMono Nerd Font") at
  `Root.Theme.fontSize` (12), `Font.DemiBold` weight — copied verbatim
  from `Theme.qml`.
- Single-monitor assumption stands (per spec's Non-goals): the
  `IpcHandler` lives once, inside `Clock.qml`, which itself is
  instantiated once (`shell.qml`'s `centerSection`).
- Do not remove or modify `set $menu wofi` (`sway/config:22`) — only the
  `$mod+d` binding's target command changes, in the final task.
- No automated test framework exists for this repo's QML (confirmed in
  both this spec and the prior `2026-09-19-quickshell-migration-design.md`).
  Every task's verification step is a live, manual check against the
  running `qs` instance — same approach used throughout this migration.
- `quickshell/modules/` has no `qmldir` file on disk; Quickshell
  auto-synthesizes one from the directory's contents at launch (confirmed
  by inspecting the directory — only `quickshell/components/` has a real
  `qmldir`). Creating `LauncherPopup.qml` in `quickshell/modules/` is
  sufficient; no registration file needs editing.

---

### Task 1: Launcher skeleton — IPC-triggered popup with a static app list

**Files:**
- Create: `quickshell/modules/LauncherPopup.qml`
- Modify: `quickshell/modules/Clock.qml`

**Interfaces:**
- Produces: `LauncherPopup` component with properties `anchorItem` (Item)
  and `open` (bool, read by the popup to show/hide/resize). `Clock.qml`
  exposes an `IpcHandler` reachable via `qs ipc call launcher toggle`.
- Consumes: `Root.Theme` (existing singleton), `DesktopEntries` and
  `Quickshell.iconPath()` (Quickshell built-ins, `import Quickshell`),
  `Quickshell.Widgets.IconImage`.

- [ ] **Step 1: Write `LauncherPopup.qml`**

```qml
// quickshell/modules/LauncherPopup.qml
import QtQuick
import Quickshell
import Quickshell.Widgets
import ".." as Root

PopupWindow {
    id: root
    property var anchorItem: null
    property bool open: false

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    grabFocus: open
    visible: open
    color: "transparent"

    readonly property real collapsedWidth: anchorItem ? anchorItem.width : 40
    readonly property real collapsedHeight: anchorItem ? anchorItem.height : 22
    readonly property real expandedWidth: 320
    readonly property real expandedHeight: 320

    implicitWidth: open ? expandedWidth : collapsedWidth
    implicitHeight: open ? expandedHeight : collapsedHeight

    onClosed: root.open = false

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Root.Theme.base.r, Root.Theme.base.g, Root.Theme.base.b, Root.Theme.pillAlpha)
        radius: Root.Theme.pillRadius
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Repeater {
                model: DesktopEntries.applications.values.filter(e => !e.noDisplay).slice(0, 8)
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    IconImage {
                        source: Quickshell.iconPath(modelData.icon)
                        implicitSize: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.name
                        color: Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.execute()
                            root.open = false
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Wire it into `Clock.qml`**

Read the current file first — it should match the version from the
`4207eb8` commit (Pill-wrapped clock). Modify:

```qml
// quickshell/modules/Clock.qml
import QtQuick
import ".." as Root
import "../components" as Components
```

becomes:

```qml
// quickshell/modules/Clock.qml
import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components
```

and:

```qml
Item {
    id: root
    property date now: new Date()
    property bool altFormat: false
```

becomes:

```qml
Item {
    id: root
    property date now: new Date()
    property bool altFormat: false
    property bool launcherOpen: false
```

and:

```qml
    CalendarPopup {
        id: popup
        anchorItem: root
    }
```

becomes:

```qml
    CalendarPopup {
        id: popup
        anchorItem: root
    }

    LauncherPopup {
        id: launcher
        anchorItem: root
        open: root.launcherOpen
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            root.launcherOpen = !root.launcherOpen
        }
    }
```

- [ ] **Step 3: Restart `qs` and verify via IPC directly**

```bash
kill $(pgrep -x qs); sleep 1; swaymsg reload; sleep 2; pgrep -x qs -a
latest=$(ls -t /run/user/1000/quickshell/by-id/ | head -1)
cat /run/user/1000/quickshell/by-id/$latest/log.qslog | strings | grep -iE "error|warn"
qs ipc call launcher toggle
```

Expected: no new errors in the log. After the `ipc call`, a ~320x320
dark rounded panel appears anchored below the clock, listing up to 8
apps with icons. Take a screenshot to confirm. Click one entry —
expected: the app launches and the panel closes. Run
`qs ipc call launcher toggle` again to re-open, then click anywhere
outside the panel — expected: it closes (via `grabFocus`/`onClosed`).
Run it once more and confirm `qs ipc call launcher toggle` a second time
also closes it (the toggle flips `launcherOpen` back to false).

If the panel doesn't appear at all, check the log for a QML error before
anything else — most likely cause is a typo in the `Repeater.model`
expression or a missing import.

- [ ] **Step 4: Commit**

```bash
cd /home/graditya/.dotfiles
git add quickshell/modules/LauncherPopup.qml quickshell/modules/Clock.qml
git commit -m "feat(quickshell): add IPC-triggered launcher popup skeleton"
```

---

### Task 2: Morph animation (clock size → expanded size)

**Files:**
- Modify: `quickshell/modules/LauncherPopup.qml`

**Interfaces:**
- Consumes: Task 1's `LauncherPopup` (same properties, same file).
- Produces: same public interface; behavior change only (animated instead
  of instant resize).

- [ ] **Step 1: Add `Behavior` blocks**

Modify the `implicitWidth`/`implicitHeight` block:

```qml
    implicitWidth: open ? expandedWidth : collapsedWidth
    implicitHeight: open ? expandedHeight : collapsedHeight

    onClosed: root.open = false
```

becomes:

```qml
    implicitWidth: open ? expandedWidth : collapsedWidth
    implicitHeight: open ? expandedHeight : collapsedHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    onClosed: root.open = false
```

- [ ] **Step 2: Restart `qs` and verify the collapsed state matches the clock**

```bash
kill $(pgrep -x qs); sleep 1; swaymsg reload; sleep 2
grim /tmp/island-collapsed-check.png
```

Crop/zoom the clock area in the screenshot and confirm the clock pill
looks unchanged (the collapsed popup, even though a separate window, sits
flush against it — nothing should look different from before Task 1).

- [ ] **Step 3: Verify the expanded state stays centered under the clock**

```bash
qs ipc call launcher toggle
sleep 1
grim /tmp/island-expanded-check.png
```

Crop/zoom this screenshot around the clock/top-center area. Expected: the
320x320 panel is horizontally centered under where the clock sits, top
edge flush against the clock's bottom edge (same as Task 1, just now
arrived at via animation instead of an instant jump).

**If it's off-center or detached from the clock instead:** the anchor
system isn't recentering automatically as the size grows. Add an explicit
gravity to pin the anchor point:

```qml
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
```

Restart and re-check. If it's *still* wrong, fall back to manual
positioning — replace the `anchor.*` lines with:

```qml
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    onAnchorItemChanged: if (anchorItem) relativeX = Qt.binding(() => (anchorItem.width - root.width) / 2)
```

(keeping `anchor.edges: Edges.Bottom` for vertical placement, but
overriding horizontal centering manually). Only add whichever fallback
was actually needed — don't add both preemptively.

- [ ] **Step 4: Commit**

```bash
cd /home/graditya/.dotfiles
git add quickshell/modules/LauncherPopup.qml
git commit -m "feat(quickshell): animate launcher popup between clock size and expanded size"
```

---

### Task 3: Fuzzy search

**Files:**
- Modify: `quickshell/modules/LauncherPopup.qml`

**Interfaces:**
- Consumes: Task 2's `LauncherPopup`.
- Produces: same file, adds an internal `results` property (array of
  `DesktopEntry`) that Task 4 will read for keyboard navigation.

- [ ] **Step 1: Add the search field and fuzzy matcher**

Replace this exact block from Task 1 (a `Column` containing only the
`Repeater` of app rows):

```qml
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Repeater {
                model: DesktopEntries.applications.values.filter(e => !e.noDisplay).slice(0, 8)
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    IconImage {
                        source: Quickshell.iconPath(modelData.icon)
                        implicitSize: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.name
                        color: Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.execute()
                            root.open = false
                        }
                    }
                }
            }
        }
```

with:

```qml
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            TextInput {
                id: searchField
                width: parent.width
                color: Root.Theme.bonewhite
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
                clip: true
                onTextChanged: root.updateResults()
            }

            Repeater {
                model: root.results
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    IconImage {
                        source: Quickshell.iconPath(modelData.icon)
                        implicitSize: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.name
                        color: Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.execute()
                            root.open = false
                        }
                    }
                }
            }
        }
```

Then add the matching logic and `results` property just above the
`onClosed` line:

```qml
    property var results: []

    function fuzzyScore(query, target) {
        if (query.length === 0) return 0
        const q = query.toLowerCase()
        const t = target.toLowerCase()
        let qi = 0
        let score = 0
        let consecutive = 0
        for (let ti = 0; ti < t.length && qi < q.length; ti++) {
            if (t[ti] === q[qi]) {
                consecutive += 1
                score += 1 + consecutive
                if (ti === 0 || t[ti - 1] === " ") score += 5
                qi += 1
            } else {
                consecutive = 0
            }
        }
        return qi === q.length ? score : -1
    }

    function appScore(query, entry) {
        if (query.length === 0) return 0
        let best = -1
        const fields = [entry.name, entry.genericName].concat(entry.keywords)
        for (const field of fields) {
            if (!field) continue
            const s = root.fuzzyScore(query, field)
            if (s > best) best = s
        }
        return best
    }

    function updateResults() {
        const query = searchField.text
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        const scored = []
        for (const entry of all) {
            const score = root.appScore(query, entry)
            if (query.length === 0 || score >= 0) scored.push({ entry: entry, score: score })
        }
        scored.sort((a, b) => b.score - a.score)
        root.results = scored.slice(0, 8).map(s => s.entry)
    }

    onOpenChanged: if (open) {
        searchField.text = ""
        root.updateResults()
        searchField.forceActiveFocus()
    }
```

(`searchField` is declared later in the file than this block, but QML
resolves ids across the whole document regardless of declaration order,
same as `popup`/`root` references already used elsewhere in this
codebase.)

- [ ] **Step 2: Restart `qs` and verify filtering**

```bash
kill $(pgrep -x qs); sleep 1; swaymsg reload; sleep 2
qs ipc call launcher toggle
```

Expected: opening shows the full (capped) app list per `updateResults()`
running with an empty query. Take a screenshot. Then simulate typing by
checking the log for QML errors first — if none, manually test by
focusing the Sway window and typing a few characters of a known
installed app's name (e.g. "fire" for Firefox if installed, or any app
confirmed present via `ls /usr/share/applications | head`), then
screenshot again. Expected: the list narrows to matching apps only, ranked
with the best subsequence match first.

- [ ] **Step 3: Commit**

```bash
cd /home/graditya/.dotfiles
git add quickshell/modules/LauncherPopup.qml
git commit -m "feat(quickshell): add fuzzy search to launcher popup"
```

---

### Task 4: Keyboard navigation, launch, and Escape-to-close

**Files:**
- Modify: `quickshell/modules/LauncherPopup.qml`

**Interfaces:**
- Consumes: Task 3's `results` property and `searchField`.
- Produces: same file; adds `highlightedIndex` (int) driving which row is
  visually highlighted.

- [ ] **Step 1: Add highlight state and key handling**

Add a property next to `results`:

```qml
    property var results: []
    property int highlightedIndex: 0
```

Reset it whenever results change — modify `updateResults()`'s last line:

```qml
        root.results = scored.slice(0, 8).map(s => s.entry)
```

becomes:

```qml
        root.results = scored.slice(0, 8).map(s => s.entry)
        root.highlightedIndex = 0
```

Add key handling to the `TextInput`:

```qml
            TextInput {
                id: searchField
                width: parent.width
                color: Root.Theme.bonewhite
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
                clip: true
                onTextChanged: root.updateResults()

                Keys.onDownPressed: root.highlightedIndex = Math.min(root.highlightedIndex + 1, root.results.length - 1)
                Keys.onUpPressed: root.highlightedIndex = Math.max(root.highlightedIndex - 1, 0)
                Keys.onEscapePressed: root.open = false
                Keys.onReturnPressed: {
                    if (root.results.length > 0) root.results[root.highlightedIndex].execute()
                    root.open = false
                }
            }
```

Update the result delegate to show the highlight and let mouse hover
move it too. Replace this exact block from Task 3:

```qml
            Repeater {
                model: root.results
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    IconImage {
                        source: Quickshell.iconPath(modelData.icon)
                        implicitSize: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.name
                        color: Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.execute()
                            root.open = false
                        }
                    }
                }
            }
```

with:

```qml
            Repeater {
                model: root.results
                delegate: Row {
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 6
                        color: index === root.highlightedIndex
                            ? Qt.rgba(Root.Theme.bonewhite.r, Root.Theme.bonewhite.g, Root.Theme.bonewhite.b, 0.12)
                            : "transparent"
                    }

                    IconImage {
                        source: Quickshell.iconPath(modelData.icon)
                        implicitSize: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.name
                        color: Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.highlightedIndex = index
                        onClicked: {
                            modelData.execute()
                            root.open = false
                        }
                    }
                }
            }
```

- [ ] **Step 2: Restart `qs` and verify keyboard + mouse interaction**

```bash
kill $(pgrep -x qs); sleep 1; swaymsg reload; sleep 2
qs ipc call launcher toggle
```

With the popup open and search field focused: press Down twice, screenshot,
confirm the highlight moved to the third row. Press Up once, screenshot,
confirm it moved back up one row. Press Escape — expected: popup closes
without launching anything (check no new window/process appeared). Reopen,
press Enter — expected: the highlighted (first, since query is empty)
app launches and the popup closes. Reopen, hover the mouse over a
different row without clicking — expected: the highlight follows the
mouse.

- [ ] **Step 3: Commit**

```bash
cd /home/graditya/.dotfiles
git add quickshell/modules/LauncherPopup.qml
git commit -m "feat(quickshell): add keyboard navigation and escape-to-close to launcher"
```

---

### Task 5: Wire the real `$mod+d` keybinding

**Files:**
- Modify: `sway/config:91`

**Interfaces:**
- Consumes: the `launcher` IPC target from Task 1 (`qs ipc call launcher
  toggle`).
- Produces: the live keybinding end users actually press.

- [ ] **Step 1: Read the current line**

```bash
grep -n '\$mod+d' /home/graditya/.dotfiles/sway/config
```

Confirm it still reads `bindsym $mod+d exec $menu --show drun` at line
91 (the surrounding config may have shifted slightly since this plan was
written — if the line number differs, use the actual line, but confirm
the exact text matches before editing).

- [ ] **Step 2: Swap the binding**

Modify:

```
    bindsym $mod+d exec $menu --show drun
```

to:

```
    bindsym $mod+d exec qs ipc call launcher toggle
```

- [ ] **Step 3: Reload Sway and verify the real shortcut end-to-end**

```bash
swaymsg reload
sleep 1
```

Press `$mod+d` on the live keyboard (or, since this is being driven
programmatically, run the exact command Sway would run to simulate it:
`qs ipc call launcher toggle` — this task's whole point is that Sway now
calls this same command, so confirming the binding text is correct in
Step 2 plus this command working is the full verification). Take a
screenshot confirming the island opens. Press `$mod+d` again (or rerun
the same command) and confirm it closes.

- [ ] **Step 4: Commit**

```bash
cd /home/graditya/.dotfiles
git add sway/config
git commit -m "feat(sway): bind \$mod+d to the island launcher instead of wofi drun"
```

---

## Self-Review Notes

- **Spec coverage:** Trigger & lifecycle (Task 1's `IpcHandler`,
  Task 5's keybinding) ✓. Animation (Task 2) ✓, including the documented
  fallback if the anchor doesn't recenter automatically during resize —
  this is the one genuinely unverified piece of Quickshell behavior in
  this plan, flagged explicitly rather than assumed. App data & search
  (Task 3) ✓. Keyboard nav, launch, Escape (Task 4) ✓. Click-outside and
  re-toggle close paths are both established in Task 1
  (`grabFocus`/`onClosed`, and `toggle()` flipping the same bool) and
  don't need a dedicated task — they're verified as part of Task 1's and
  Task 4's checks rather than invented as a no-op task.
- **Non-goals respected:** no other island surfaces built, wofi/`$menu`
  untouched except the one binding, no fuzzy-finder dependency added
  (self-contained JS function), no multi-monitor logic added.
- **Type/name consistency:** `LauncherPopup`'s `anchorItem`/`open`
  properties are named identically everywhere they're referenced (Clock's
  instantiation in Task 1, never renamed later). `results`,
  `highlightedIndex`, `searchField`, `updateResults()`, `fuzzyScore()`,
  `appScore()` are each defined once (Task 3 or 4) and referenced with
  the same names in every later step that touches them.
