// quickshell/modules/island/CenterIsland.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.." as Root

PanelWindow {
    id: root
    // No `required property var screen` here: PanelWindow (via
    // WindowInterface) already declares a real `screen` property.
    // Redeclaring it would shadow that real property with a same-named
    // local one, so shell.qml's `screen: modelData` binding would set the
    // shadow instead of the compositor-assigned screen the window actually
    // needs — works by luck on a single-monitor setup, breaks silently on
    // multi-monitor. `screen: modelData` in shell.qml already binds
    // straight onto the real property once this shadow is gone (same
    // pattern the bar's own PanelWindow there already uses correctly).
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
    property string mode: "collapsed"     // "collapsed" | "calendar" (peek is tracked separately via `island.peeking`, not a mode value)
    property bool open: false

    signal openRequested(string requestedMode)
    signal closeRequested()

    // `open` and `mode` both flip to their closed values synchronously in
    // the same shell.qml call (closeIsland()), so an `active: ... ||
    // root.open` condition on the Loader below never gets a rendered frame
    // where it still holds true — verified live: no fade ever played.
    // `closing` outlives that synchronous flip for one animation cycle,
    // the same pattern (and reason) LauncherPopup.qml already uses for
    // exactly this problem (`visible: open || closing`).
    property bool closing: false
    onOpenChanged: {
        if (!open) {
            closing = true
            closeAnimTimer.restart()
        }
    }
    Timer {
        id: closeAnimTimer
        interval: Root.Config.contentFadeOutDuration + 20
        onTriggered: root.closing = false
    }

    anchors { top: true; bottom: true; left: true; right: true }
    // -1, not 0: on a wlr-layer-shell surface, `exclusiveZone: 0` means
    // "respect other surfaces' exclusive zones" (not "reserve none"). This
    // fullscreen overlay window sat below the bar's own auto-computed
    // exclusive zone (margins.top 4 + implicitHeight 26 = 30px) as a
    // result, pushing the whole window's origin down to y=30 — the actual
    // root cause of the collapsed pill sitting ~30px lower than the old
    // clock pill. -1 means "don't reserve space AND ignore others'
    // reservations", same as LauncherPopup.qml's own overlay window uses,
    // for the same reason: transient overlay, not a dock.
    exclusiveZone: -1
    color: "transparent"
    // Bar (shell.qml) is also layer Top with no mask, so its full-width
    // unmasked strip would otherwise intercept clicks/hover meant for the
    // pill once the pill sits back in that same vertical band (per the
    // exclusiveZone fix above). Overlay ranks above Top, so the island
    // wins input in the overlap.
    WlrLayershell.layer: WlrLayer.Overlay
    // `WlrLayershell.keyboardFocus` requests real Wayland seat keyboard
    // focus from the compositor regardless of cursor position, which a
    // keybind-triggered open (Task 8) needs — sway's default
    // `focus_follows_mouse yes` means an IPC-triggered open with the
    // cursor elsewhere would otherwise send Escape to whatever window the
    // cursor was actually over, not the island (confirmed live). A
    // separate `focusable: open` binding used to sit alongside this one,
    // but `focusable` and `WlrLayershell.keyboardFocus` are two QML
    // bindings onto the same backing field (per Quickshell's qmltypes:
    // both `notify: keyboardFocusChanged`) — having both bound raced two
    // writers over one piece of state, undefined which won, and is a
    // plausible contributor to the still-open Escape-key bug.
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
        // Collapsed/peek: center within the bar's own height band, matching
        // how every other bar pill is `anchors.verticalCenter`-ed there —
        // just sitting at `barTopMargin` (the pill's own top) left it
        // sitting visibly lower than the rest of the bar whenever the
        // pill's height doesn't exactly equal the bar's height (collapsed
        // is 22px inside a 26px band). Open: flush at the top margin so the
        // panel grows straight down from the bar line, per spec.
        y: root.open ? Root.Config.barTopMargin
                     : Root.Config.barTopMargin + (Root.Config.barHeight - height) / 2

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
            // No `enabled: !root.open` here: if the cursor was over the
            // pill when it opened (peeking == true) and then moved away
            // while `open` stayed true, a disabled handler never fires
            // `onHoveredChanged`, so `peeking` got stuck true — the
            // collapsed pill would reappear at peek size until re-hovered.
            // The `peeking && !root.open` guard on implicitWidth/Height
            // below already correctly gates peek sizing to the collapsed
            // state on its own; tracking real hover at all times (including
            // while open) is strictly more correct and needs nothing else.
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
            // `|| root.closing`: closeIsland() (shell.qml) sets `open` and
            // `mode` to their closed values in the same synchronous call,
            // so `|| root.open` alone (an earlier attempt at this fix)
            // never actually held true for a rendered frame — confirmed
            // live, no fade ever played. `root.closing` (above) outlives
            // that synchronous flip for one animation cycle, keeping
            // CalendarView alive long enough for the opacity fade-out
            // below to actually be visible before the Loader tears it down.
            active: root.mode === "calendar" || root.closing
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
