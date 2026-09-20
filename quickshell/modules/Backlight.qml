// quickshell/modules/Backlight.qml
import QtQuick
import Quickshell.Io
import ".." as Root

Item {
    id: root
    property int percent: 0
    property bool available: false

    // No backlight device (desktop with an external monitor): hide the
    // module entirely rather than showing a permanently-0% icon (Row
    // excludes invisible children from layout, so this leaves no gap).
    visible: available
    implicitWidth: available ? label.implicitWidth : 0
    implicitHeight: available ? label.implicitHeight : 0

    Text {
        id: label
        anchors.fill: parent
        text: {
            const icons = ["󰃛", "󰃞", "󰃠"]
            const idx = Math.min(icons.length - 1, Math.floor(root.percent / (100 / icons.length)))
            return icons[idx] + " " + root.percent.toString().padStart(3, " ") + "%"
        }
        color: Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            const cmd = wheel.angleDelta.y > 0 ? "+5%" : "5%-"
            bump.command = ["brightnessctl", "set", cmd]
            bump.running = true
        }
    }

    Process {
        id: bump
        onExited: refresh.running = true
    }

    Process {
        id: refresh
        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // brightnessctl -m output: class,name,current,pct%,max
                const fields = text.trim().split(",")
                root.percent = parseInt(fields[3])
            }
        }
    }

    Process {
        id: detect
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim().length > 0
                if (root.available) refresh.running = true
            }
        }
    }

    Component.onCompleted: detect.running = true
}
