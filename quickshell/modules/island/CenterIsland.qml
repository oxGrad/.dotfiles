// quickshell/modules/island/CenterIsland.qml
import QtQuick
import Quickshell
import "../.." as Root

PanelWindow {
    id: root
    required property var screen
    property string mode: "collapsed"     // "collapsed" | "peek" | "calendar"
    property bool open: false

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    focusable: open

    // Collapsed/peek: only the pill itself is clickable, the rest of this
    // fullscreen window is click-through to whatever is behind it (same
    // technique LauncherPopup.qml uses). Open: the whole window becomes
    // clickable so clickCatcher below can see, and close on, outside clicks.
    mask: root.open ? null : Region { item: island }

    Keys.onEscapePressed: root.close()

    function close() {
        root.open = false
        root.mode = "collapsed"
    }

    function toggle(requestedMode) {
        if (root.open && root.mode === requestedMode) {
            root.close()
        } else {
            root.open = true
            root.mode = requestedMode
        }
    }

    // Sits below `island` in z-order (declared first) so clicks on the
    // island itself are consumed by the island's own content first and
    // never reach this catcher.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.close()
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
