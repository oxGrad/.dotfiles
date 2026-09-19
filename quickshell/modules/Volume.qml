// quickshell/modules/Volume.qml
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".." as Root

Item {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int volumePct: Math.round((sink?.audio?.volume ?? 0) * 100)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.muted
            ? "󰌧 muted" //
            : "󰌨 " + root.volumePct.toString().padStart(4, " ") + "%" //
        color: root.muted ? Root.Theme.overlay0 : Root.Theme.bonewhite
        font.family: Root.Theme.fontFamily
        font.pixelSize: Root.Theme.fontSize
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: openPavucontrol.running = true
        onWheel: (wheel) => {
            if (!root.sink) return
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1.5, root.sink.audio.volume + delta))
        }
    }

    Process {
        id: openPavucontrol
        command: ["pavucontrol"]
    }
}
