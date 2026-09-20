// quickshell/modules/Battery.qml
import QtQuick
import Quickshell.Services.UPower
import ".." as Root

Item {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property int pct: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool plugged: device?.state === UPowerDeviceState.PendingCharge
    readonly property bool critical: root.pct <= 15 && !root.charging
    readonly property bool warning: root.pct <= 30 && !root.charging

    // No real battery (desktop machine, or UPower's DisplayDevice fallback
    // with isPresent=false): hide the module entirely rather than showing a
    // permanently-blinking-pink "critical" 0% (Row excludes invisible
    // children from layout, so this leaves no gap).
    visible: device?.isPresent ?? false
    implicitWidth: visible ? label.implicitWidth : 0
    implicitHeight: visible ? label.implicitHeight : 0

    Text {
        id: label
        anchors.fill: parent
        text: {
            const icons = ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"] //
            const idx = Math.min(icons.length - 1, Math.floor(root.pct / (100 / icons.length)))
            const icon = (root.charging || root.plugged) ? "󰂄" : icons[idx] //
            return icon + " " + root.pct.toString().padStart(3, " ") + "%"
        }
        color: {
            if (root.critical) return Root.Theme.pink
            if (root.warning) return Root.Theme.yellow
            if (root.charging || root.plugged) return Root.Theme.green
            return Root.Theme.bonewhite
        }
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold

        SequentialAnimation on opacity {
            running: root.critical
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.3; duration: 500 }
            NumberAnimation { from: 0.3; to: 1.0; duration: 500 }
        }
    }
}
