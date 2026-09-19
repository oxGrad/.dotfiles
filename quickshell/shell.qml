// quickshell/shell.qml
import Quickshell
import QtQuick
import "components" as Components

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

            Components.Pill {
                anchors.centerIn: parent
                content: Text {
                    text: "themed pill"
                    color: Theme.bonewhite
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
