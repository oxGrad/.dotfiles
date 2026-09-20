// quickshell/modules/LauncherPopup.qml
import QtQuick
import Quickshell
import Quickshell.Widgets
import ".." as Root

PopupWindow {
    id: root
    property var anchorItem: null
    property bool open: false
    // Emitted when the compositor/window dismisses the popup, or an entry
    // is launched. `open` is externally bound (Clock.qml:
    // `open: root.launcherOpen`); writing to it from in here would sever
    // that binding permanently (QML: assigning to a property from inside
    // the component disconnects any external binding on it), so callers
    // react to this signal and set their own state to false instead.
    signal dismissed()

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    // No grabFocus here: a grabbing xdg_popup can only be created in
    // direct response to a real input-event serial (button/key/touch).
    // This popup is opened via IPC (`qs ipc call launcher toggle`), which
    // has no such serial, so the compositor rejects the grab and the
    // popup never maps (verified live: "Failed to create grabbing popup
    // ... parent window has received input" in the Wayland log). None of
    // the sibling popups (CalendarPopup/NetworkPopup/BluetoothPopup) grab
    // focus either; closing is done by toggling again, same as those.
    // `visible` stays true a beat past `open` going false so the shrink
    // animation below is actually visible before the window unmaps; see
    // `closing` below.
    visible: open || closing
    color: "transparent"

    // Fixed size, permanently. An earlier draft tied implicitWidth/Height
    // to `open` (collapsed pill size <-> expanded panel size) directly on
    // this PopupWindow, but resizing the popup's own geometry at the same
    // moment `visible` turns true corrupts the xdg_popup's geometry
    // negotiation and it silently never maps (verified live: reproduced
    // with grabFocus removed, still no render; fixed immediately by using
    // a constant size instead). This window's own geometry must never be
    // tied to `open` again. The Task 2 morph instead animates an inner
    // Rectangle's size within this fixed-size window (see `panel` below).
    implicitWidth: 320
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

    onClosed: root.dismissed()

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
