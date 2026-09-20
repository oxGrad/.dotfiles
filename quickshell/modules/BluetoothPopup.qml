// quickshell/modules/BluetoothPopup.qml
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import ".." as Root
import "../components" as Components

Components.PopupPanel {
    id: root
    property var anchorItem: null
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    visible: false

    content: [
        Rectangle {
            width: parent.width
            height: 22
            color: "transparent"
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Bluetooth.defaultAdapter?.enabled ? "Bluetooth: on" : "Bluetooth: off"
                color: Root.Theme.bonewhite
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
        },
        Repeater {
            model: Bluetooth.defaultAdapter?.devices?.values ?? []
            delegate: Rectangle {
                required property var modelData
                width: root.implicitWidth - 16
                height: 22
                color: "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.connected ? "󰂱 " : "󰂯 ") + modelData.name // 󰂱 / 󰂯
                    color: modelData.connected ? Root.Theme.sky : Root.Theme.bonewhite
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSize
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
        },
        Text {
            text: "󰑐 Scan"  // 󰑐
            color: Root.Theme.subtext1
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent
                onClicked: Bluetooth.defaultAdapter.discovering = true
            }
        }
    ]
}
