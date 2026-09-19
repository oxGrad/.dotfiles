// quickshell/modules/Clock.qml
import QtQuick
import ".." as Root

Item {
    id: root
    property date now: new Date()
    property bool altFormat: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.altFormat
            ? Qt.formatDateTime(root.now, "ddd dd MMM | HH:mm:ss")
            : Qt.formatDateTime(root.now, "HH:mm:ss")
        color: Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    CalendarPopup {
        id: popup
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.altFormat = !root.altFormat
            else popup.visible = !popup.visible
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
