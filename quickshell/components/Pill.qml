// quickshell/components/Pill.qml
import QtQuick
import ".."

Rectangle {
    id: root
    default property alias content: inner.data
    property real horizontalPadding: 12

    color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, Theme.pillAlpha)
    radius: Theme.pillRadius
    implicitHeight: 22
    implicitWidth: inner.implicitWidth + horizontalPadding * 2

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 6
    }
}
