// quickshell/modules/Workspaces.qml
import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components

Components.Pill {
    id: root
    property var workspaces: []

    content: Row {
        spacing: 4
        Repeater {
            model: root.workspaces
            delegate: Text {
                required property var modelData
                text: {
                    const icons = { "1": "", "2": "", "3": "", "4": "", "5": "", "6": "" }
                    return icons[modelData.name] ?? modelData.name
                }
                color: modelData.focused ? Root.Theme.bonewhite : Root.Theme.subtext0
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
            }
        }
    }

    function refresh() {
        getWorkspaces.running = true
    }

    Process {
        id: getWorkspaces
        command: ["swaymsg", "-t", "get_workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.workspaces = JSON.parse(text)
        }
    }

    Process {
        id: subscribe
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"workspace\"]"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
        subscribe.running = true
    }
}
