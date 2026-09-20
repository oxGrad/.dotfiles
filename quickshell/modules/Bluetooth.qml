// quickshell/modules/Bluetooth.qml
import QtQuick
import Quickshell.Bluetooth
import ".." as Root

Item {
    id: root
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool connected: (Bluetooth.defaultAdapter?.devices?.values ?? []).some(d => d.connected)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.enabled ? (root.connected ? "󰂱" : "󰂯") : "󰂲" // 󰂱 / 󰂯 / 󰂲
        color: !root.enabled ? Root.Theme.overlay0 : (root.connected ? Root.Theme.sky : Root.Theme.bonewhite)
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    BluetoothPopup {
        id: popup
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = !popup.visible
    }
}
