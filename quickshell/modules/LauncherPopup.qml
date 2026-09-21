// quickshell/modules/LauncherPopup.qml
import QtQuick
import Quickshell
import Quickshell.Widgets
import ".." as Root

PanelWindow {
    id: root
    property var anchorItem: null
    property bool open: false
    // Emitted when an entry is launched (click-to-launch below). `open` is
    // externally bound (shell.qml: `open: root.launcherOpen`); writing to
    // it from in here would sever that binding permanently (QML: assigning
    // to a property from inside the component disconnects any external
    // binding on it), so callers react to this signal and set their own
    // state to false instead.
    signal dismissed()

    // History: this was originally a PopupWindow (xdg_popup) anchored to
    // the clock via `anchor.item`/`anchor.edges`. That type's only
    // keyboard-focus mechanism is a compositor "grab", which can only be
    // requested at popup-creation time using a real input-event serial
    // (button/key/touch). This popup is created via a background IPC call
    // (`qs ipc call launcher toggle`) with no such serial, so a grab was
    // never possible and typed input never reached the field (verified
    // live: click-to-place-caret worked, but keystrokes didn't land).
    // PanelWindow (layer-shell) with `focusable: true` is the proven-working
    // alternative: real keyboard delivery here depends on this compositor's
    // focus_follows_mouse behavior (confirmed live by hovering the mouse
    // over the window), not on any grab/serial concept. `anchor`/`Edges`
    // are PopupWindow/PopupAnchor-only concepts and don't exist on
    // PanelWindow; anchoring below is to screen edges instead, same as the
    // main bar in shell.qml.
    focusable: true
    aboveWindows: true
    // Transient overlay, not a dock: must not reserve permanent screen
    // space (verified live: other windows/desktop don't shift when open).
    exclusiveZone: -1
    anchors {
        top: true
        left: true
        right: true
    }
    // Bar (shell.qml) anchors only top/left/right (no bottom), so its own
    // `margins.bottom: 2` is inert — doesn't affect its screen position.
    // Bar's visible strip: margins.top 4 + implicitHeight 26 = ends at y=30.
    margins {
        top: 30
    }
    // Window spans the full screen width (no visual fill), but an unmasked
    // layer-shell surface's input region defaults to its whole geometry —
    // it would otherwise swallow clicks across the entire width of this
    // band, not just over the visible `panel` below. Restrict input to
    // just the rendered panel so the rest stays click-through.
    mask: Region { item: panel }
    // `visible` stays true a beat past `open` going false so the shrink
    // animation below is actually visible before the window unmaps; see
    // `closing` below.
    visible: open || closing
    color: "transparent"

    // Fixed height, permanently. An earlier PopupWindow-based draft tied
    // implicitWidth/Height to `open` (collapsed pill size <-> expanded
    // panel size) directly on the window itself; resizing the window's own
    // geometry at the same moment `visible` turned true corrupted that
    // xdg_popup's geometry negotiation and it silently never mapped. This
    // window's own geometry must never be tied to `open` again. The Task 2
    // morph instead animates an inner Rectangle's size within this
    // fixed-size window (see `panel` below). Width is no longer set here:
    // the `left`/`right` screen anchors above make the window span the
    // full screen width, which is what lets `panel` below center itself
    // under the clock via `anchors.horizontalCenter`.
    implicitHeight: 320

    // Single source of truth for all morph animation timings to prevent
    // coupling bugs where the timer unmaps the window mid-animation.
    readonly property int morphDuration: 180

    // Keeps the window mapped for one animation cycle after `open` goes
    // false, so the collapse plays before the popup disappears.
    property bool closing: false
    onOpenChanged: {
        if (!open) {
            closing = true
            closeTimer.restart()
        } else {
            searchField.text = ""
            root.updateResults()
            searchField.forceActiveFocus()
        }
    }

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

    // DesktopEntries populates asynchronously in the background (scanning
    // .desktop files takes noticeable time after qs starts). updateResults()
    // is only ever called imperatively (on open / on text change), so
    // without this it can run before the scan finishes and permanently
    // freeze `results` at an empty/partial snapshot. Re-run whenever the
    // underlying list actually changes.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.updateResults() }
    }

    Timer {
        id: closeTimer
        interval: root.morphDuration + 20
        onTriggered: root.closing = false
    }

    // No `onClosed` handler: `closed` is declared on `WindowInterface`,
    // which both `PopupWindow` and `PanelWindow` prototype from, so
    // `PanelWindow` does have this signal — it's just not the layer-shell
    // equivalent of xdg_popup's grab-loss "compositor forced a dismiss"
    // event; layer-shell surfaces don't auto-dismiss on focus loss the way
    // xdg_popup grabs did. Not a regression: click-outside-to-close was
    // already established as infeasible and dropped in an earlier task.
    // `visible: open || closing` above already gives full manual control
    // (no stuck-open path either way), and the two real dismiss paths —
    // IPC re-toggle and click-to-launch's `dismissed()` signal below,
    // are handled by shell.qml — don't depend on `closed` at all.

    // Morphs between the clock pill's live size (collapsed) and the full
    // panel size (expanded). Anchored to the window's top-center so it
    // starts flush under the clock and grows outward/downward, clipped
    // within the outer window whose own geometry never changes.
    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.open ? 320 : (root.anchorItem ? root.anchorItem.width : 320)
        height: root.open ? 320 : (root.anchorItem ? root.anchorItem.height : 320)
        Behavior on width {
            NumberAnimation { duration: root.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: root.morphDuration; easing.type: Easing.OutCubic }
        }
        color: Qt.rgba(Root.Theme.base.r, Root.Theme.base.g, Root.Theme.base.b, Root.Theme.pillAlpha)
        radius: Root.Theme.pillRadius
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

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
                delegate: Item {
                    required property var modelData
                    width: parent.width
                    height: 24

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        IconImage {
                            source: Quickshell.iconPath(modelData.icon)
                            implicitSize: 20
                        }
                        Text {
                            text: modelData.name
                            color: Root.Theme.bonewhite
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: Root.Theme.fontSize
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.execute()
                            root.dismissed()
                        }
                    }
                }
            }
        }
    }
}
