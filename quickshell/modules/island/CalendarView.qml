// quickshell/modules/island/CalendarView.qml
import QtQuick
import "../.." as Root

Column {
    id: root
    property date viewDate: new Date()
    spacing: 8
    focus: true

    function monthGrid() {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        const startOffset = first.getDay()
        const daysInMonth = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < startOffset; i++) cells.push(null)
        for (let d = 1; d <= daysInMonth; d++) cells.push(d)
        return cells
    }

    function shiftMonth(delta) {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1)
    }

    function goToday() {
        viewDate = new Date()
    }

    Keys.onLeftPressed: root.shiftMonth(-1)
    Keys.onRightPressed: root.shiftMonth(1)
    Keys.onHomePressed: root.goToday()

    Text {
        text: Qt.formatDate(root.viewDate, "dddd, d MMMM yyyy")
        color: Root.Theme.subtext0
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    Row {
        spacing: 10
        Text {
            text: "‹"
            color: Root.Theme.subtext0
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(-1) }
        }
        Text {
            text: Qt.formatDate(root.viewDate, "MMMM yyyy")
            color: Root.Theme.bonewhite
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
        }
        Text {
            text: "›"
            color: Root.Theme.subtext0
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSize
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(1) }
        }
    }

    Grid {
        columns: 7
        spacing: 4
        Repeater {
            model: root.monthGrid()
            delegate: Text {
                required property var modelData
                width: 32
                horizontalAlignment: Text.AlignHCenter
                text: modelData ? modelData.toString() : ""
                color: {
                    if (!modelData) return "transparent"
                    const today = new Date()
                    const isToday = modelData === today.getDate()
                        && root.viewDate.getMonth() === today.getMonth()
                        && root.viewDate.getFullYear() === today.getFullYear()
                    return isToday ? Root.Theme.pink : Root.Theme.bonewhite
                }
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSize
                font.weight: Font.DemiBold
            }
        }
    }
}
