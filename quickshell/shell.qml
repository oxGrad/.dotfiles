//@ pragma UseQApplication
// quickshell/shell.qml
import Quickshell
import QtQuick
import "components" as Components
import "modules" as Modules

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

            Row {
                id: leftSection
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Modules.Workspaces {}
            }

            Row {
                id: centerSection
                anchors.centerIn: parent
                spacing: 6

                Modules.Clock {}
            }

            Row {
                id: rightSection
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Modules.Tray {}

                Components.Pill {
                    content: Row {
                        spacing: 10
                        Modules.Backlight {}
                        Modules.Volume {}
                        Modules.Bluetooth {}
                        Modules.Network {}
                        Modules.Battery {}
                    }
                }
            }
        }
    }
}
