// quickshell/modules/CalendarPopup.qml
import QtQuick
import Quickshell
import ".." as Root
import "../components" as Components

Components.PopupPanel {
    id: root
    property var anchorItem: null
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    visible: false
    property date viewDate: new Date()

    function monthGrid() {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        const startOffset = first.getDay()
        const daysInMonth = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < startOffset; i++) cells.push(null)
        for (let d = 1; d <= daysInMonth; d++) cells.push(d)
        return cells
    }

    content: [
        Text {
            text: Qt.formatDate(root.viewDate, "MMMM yyyy")
            color: Root.Theme.mauve
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
        },
        Grid {
            columns: 7
            spacing: 2
            Repeater {
                model: root.monthGrid()
                delegate: Text {
                    required property var modelData
                    required property int index
                    width: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData ? modelData.toString() : ""
                    color: {
                        if (!modelData) return "transparent"
                        const today = new Date()
                        const isToday = modelData === today.getDate()
                            && root.viewDate.getMonth() === today.getMonth()
                            && root.viewDate.getFullYear() === today.getFullYear()
                        return isToday ? Root.Theme.pink : Root.Theme.sky
                    }
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSize
                    font.weight: Font.DemiBold
                }
            }
        },
        Row {
            spacing: 10
            Text {
                text: "‹ prev"
                color: Root.Theme.subtext1
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
                }
            }
            Text {
                text: "next ›"
                color: Root.Theme.subtext1
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
                }
            }
        }
    ]
}
