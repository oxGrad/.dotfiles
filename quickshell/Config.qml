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
