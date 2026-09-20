// quickshell/modules/LauncherPopup.qml
import QtQuick
import Quickshell
import Quickshell.Widgets
import ".." as Root

PopupWindow {
    id: root
    property var anchorItem: null
    property bool open: false

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    grabFocus: open
    visible: open
    color: "transparent"

    readonly property real collapsedWidth: anchorItem ? anchorItem.width : 40
    readonly property real collapsedHeight: anchorItem ? anchorItem.height : 22
    readonly property real expandedWidth: 320
    readonly property real expandedHeight: 320

    implicitWidth: open ? expandedWidth : collapsedWidth
    implicitHeight: open ? expandedHeight : collapsedHeight

    onClosed: root.open = false

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Root.Theme.base.r, Root.Theme.base.g, Root.Theme.base.b, Root.Theme.pillAlpha)
        radius: Root.Theme.pillRadius
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Repeater {
                model: DesktopEntries.applications.values.filter(e => !e.noDisplay).slice(0, 8)
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    IconImage {
                        source: Quickshell.iconPath(modelData.icon)
                        implicitSize: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.name
                        color: Root.Theme.bonewhite
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        width: parent.width
                        height: parent.height
                        onClicked: {
                            modelData.execute()
                            root.open = false
                        }
                    }
                }
            }
        }
    }
}
