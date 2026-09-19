// quickshell/modules/Tray.qml
import QtQuick
import Quickshell.Services.SystemTray
import ".." as Root
import "../components" as Components

Components.Pill {
    id: root
    visible: SystemTray.items.values.length > 0

    content: Row {
        spacing: 5
        Repeater {
            model: SystemTray.items.values
            delegate: Image {
                required property var modelData
                source: modelData.icon
                width: 14
                height: 14
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) modelData.activate()
                        else modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
