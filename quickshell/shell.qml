//@ pragma UseQApplication
// quickshell/shell.qml
import Quickshell
import Quickshell.Io
import QtQuick
import "components" as Components
import "modules" as Modules
import "modules/island" as Island

ShellRoot {
    property string islandMode: "collapsed"
    property bool islandOpen: false

    // The only two places that write islandMode/islandOpen — both the
    // IpcHandler below and every CenterIsland instance's signals (Step 2)
    // funnel through these, so "closed" always means the same thing
    // (mode reset to collapsed) regardless of which path triggered it.
    function openIsland(mode) {
        islandOpen = true
        islandMode = mode
    }
    function closeIsland() {
        islandOpen = false
        islandMode = "collapsed"
    }

    IpcHandler {
        target: "island"
        function toggle(mode: string): void {
            if (islandOpen && islandMode === mode) closeIsland()
            else openIsland(mode)
        }
        function close(): void {
            closeIsland()
        }
    }

    Variants {
        model: Quickshell.screens

        Island.CenterIsland {
            required property var modelData
            screen: modelData
            mode: islandMode
            open: islandOpen
            onOpenRequested: (requestedMode) => openIsland(requestedMode)
            onCloseRequested: closeIsland()
        }
    }

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
            implicitHeight: Config.barHeight
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

            property bool launcherOpen: false

            Modules.LauncherPopup {
                id: launcher
                open: launcherOpen
                onDismissed: launcherOpen = false
            }

            IpcHandler {
                target: "launcher"
                function toggle() {
                    launcherOpen = !launcherOpen
                }
            }
        }
    }
}
