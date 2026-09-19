// quickshell/shell.qml
import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 26
            margins {
                top: 4
                right: 8
                bottom: 2
                left: 8
            }
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "quickshell alive"
                color: "#faf9f6"
            }
        }
    }
}
