// quickshell/modules/WindowTitle.qml
import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components

Components.Pill {
    id: root
    property string title: ""
    visible: root.title.length > 0

    content: Text {
        text: root.title
        color: Root.Theme.subtext1
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.Normal
        elide: Text.ElideRight
    }

    function refresh() {
        getTree.running = true
    }

    Process {
        id: getTree
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                const tree = JSON.parse(text)
                root.title = findFocusedTitle(tree) ?? ""
            }
        }
    }

    function findFocusedTitle(node) {
        const isWindow = node.type === "con" || node.type === "floating_con"
        if (isWindow && node.focused && node.name) return node.name
        for (const child of (node.nodes ?? []).concat(node.floating_nodes ?? [])) {
            const found = findFocusedTitle(child)
            if (found) return found
        }
        return null
    }

    Process {
        id: subscribe
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"window\"]"]
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
