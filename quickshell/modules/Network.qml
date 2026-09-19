// quickshell/modules/Network.qml
import QtQuick
import Quickshell.Io
import ".." as Root

Item {
    id: root
    property string state: "disconnected" // "wifi" | "ethernet" | "disconnected" | "disabled"
    property int signalPct: 0

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: {
            if (root.state === "wifi") return "󰤭 " + root.signalPct + "%" //
            if (root.state === "ethernet") return "󰌿 Wired" //
            if (root.state === "disabled") return "󰍮" //
            return "󰍚" //
        }
        color: root.state === "disconnected" ? Root.Theme.red
             : root.state === "disabled" ? Root.Theme.overlay0
             : Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    NetworkPopup {
        id: popup
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = !popup.visible
    }

    Process {
        id: status
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "dev", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const wifi = lines.find(l => l.startsWith("wifi:"))
                const eth = lines.find(l => l.startsWith("ethernet:"))
                if (eth && eth.endsWith(":connected")) root.state = "ethernet"
                else if (wifi && wifi.endsWith(":connected")) root.state = "wifi"
                else if (wifi && wifi.endsWith(":unavailable")) root.state = "disabled"
                else root.state = "disconnected"
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: status.running = true
    }
}
