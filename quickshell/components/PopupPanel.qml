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
