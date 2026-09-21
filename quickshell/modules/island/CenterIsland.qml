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
    // ponytail: was `mask: root.open ? null : Region { item: island }` —
    // invalid QML (an inline object declaration can't be a ternary branch;
    // confirmed via `qs` parse error "Expected token ','" at the `{`).
    // Never actually parsed until Task 7 instantiated this component for
    // the first time. Named Region + id reference preserves the exact
    // same intended behavior (open: unmasked; collapsed/peek: masked to
    // just the pill).
    mask: root.open ? null : maskRegion
    Region { id: maskRegion; item: island }

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

        // ponytail: `Keys.onEscapePressed` used to live on `root` (the
        // PanelWindow) — confirmed live (qs log) this silently never
        // attached at all: "Could not attach Keys property to:
        // CenterIsland_QMLTYPE_23 is not an Item". Qt Quick's `Keys`
        // attached property only attaches to QQuickItem, and PanelWindow
        // is Window-derived, not Item-derived. `island` is a real Item and
        // an ancestor of whatever content grabs active focus (CalendarView
        // via forceActiveFocus() below) — an unaccepted key event bubbles
        // up the Item ancestor chain from the focused item, so attaching
        // here is what actually receives it. WlrLayershell.keyboardFocus
        // above is still required too: without real Wayland seat focus on
        // this surface, no item inside it ever gets an event to bubble.
        Keys.onEscapePressed: root.closeRequested()

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
