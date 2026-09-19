// quickshell/modules/NetworkPopup.qml
import QtQuick
import Quickshell
import Quickshell.Io
import ".." as Root
import "../components" as Components

Components.PopupPanel {
    id: root
    property var anchorItem: null
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    visible: false
    property var networks: []

    onVisibleChanged: if (visible) refresh()

    function refresh() {
        list.running = true
    }

    function bars(signal) {
        if (signal > 75) return "▰▰▰▰"
        if (signal > 50) return "▰▰▰▱"
        if (signal > 25) return "▰▰▱▱"
        return "▰▱▱▱"
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set()
                const rows = []
                for (const line of text.trim().split("\n")) {
                    if (!line) continue
                    const [inUse, signal, security, ...rest] = line.split(":")
                    const ssid = rest.join(":")
                    if (!ssid || seen.has(ssid)) continue
                    seen.add(ssid)
                    rows.push({ inUse: inUse === "*", signal: parseInt(signal), secured: security !== "" && security !== "--", ssid })
                }
                rows.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
                root.networks = rows
            }
        }
    }

    Process {
        id: connector
        property string ssid: ""
        property string password: ""
        command: password.length > 0
            ? ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", ssid]
        onExited: root.refresh()
    }

    content: [
        Repeater {
            model: root.networks
            delegate: Rectangle {
                required property var modelData
                width: root.implicitWidth - 16
                height: 22
                color: "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        text: modelData.ssid
                        color: modelData.inUse ? Root.Theme.sky : Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.bars(modelData.signal) + (modelData.secured ? " 󰂼" : "") //
                        color: Root.Theme.subtext1
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        connector.ssid = modelData.ssid
                        connector.password = ""
                        connector.running = true
                    }
                }
            }
        },
        Text {
            text: "󰖎 Rescan" //
            color: Root.Theme.subtext1
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent
                onClicked: root.refresh()
            }
        }
    ]
}
