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
