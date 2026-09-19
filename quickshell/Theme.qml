// quickshell/Theme.qml
pragma Singleton
import QtQuick

QtObject {
    readonly property color base: "#272822"
    readonly property color mantle: "#1e1f1c"
    readonly property color crust: "#1e1f1c"

    readonly property color text: "#f8f8f2"
    readonly property color subtext0: "#90908a"
    readonly property color subtext1: "#c2c2bf"

    readonly property color surface0: "#3e3d32"
    readonly property color surface1: "#414339"
    readonly property color surface2: "#464741"

    readonly property color overlay0: "#75715e"
    readonly property color overlay1: "#90908a"
    readonly property color overlay2: "#cccccc"

    readonly property color bonewhite: "#faf9f6"
    readonly property color blue: "#6a7ec8"
    readonly property color lavender: "#819aff"
    readonly property color sapphire: "#56adbc"
    readonly property color sky: "#66d9ef"
    readonly property color teal: "#66d9ef"
    readonly property color green: "#a6e22e"
    readonly property color yellow: "#e2e22e"
    readonly property color peach: "#ffd56c"
    readonly property color maroon: "#ff6583"
    readonly property color red: "#f92672"
    readonly property color mauve: "#ae81ff"
    readonly property color pink: "#f92672"
    readonly property color flamingo: "#ff9767"
    readonly property color rosewater: "#f8f8f0"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int pillRadius: 13
    readonly property real pillAlpha: 0.92
}
