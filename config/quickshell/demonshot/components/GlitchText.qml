import QtQuick
import qs

// рваный текст: обычный Text, прогнанный через glitch.frag
// static по умолчанию; tear() рвёт заново, interval > 0 — рвёт сам
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias textFormat: label.textFormat
    property real strength: 26             // сила сдвига, px
    property vector2d freq: Qt.vector2d(0.022, 0.09)
    property int interval: 0             // мс между разрывами, 0 — статично
    property real seed: 13

    readonly property int pad: Math.ceil(strength)
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    function tear() { seed = Math.random() * 100; }

    Item {
        id: src
        x: -root.pad
        y: -root.pad
        width: label.implicitWidth + root.pad * 2
        height: label.implicitHeight + root.pad * 2
        visible: false
        layer.enabled: true

        Text {
            id: label
            x: root.pad
            y: root.pad
            font.family: Theme.frak
            color: Theme.crimson
        }
    }

    ShaderEffect {
        x: src.x
        y: src.y
        width: src.width
        height: src.height
        property variant source: src
        property vector2d size: Qt.vector2d(width, height)
        property vector2d freq: root.freq
        property real amount: root.strength
        property real seed: root.seed
        fragmentShader: Qt.resolvedUrl("shaders/glitch.frag.qsb")
    }

    Timer {
        running: root.interval > 0 && root.visible
        interval: root.interval
        repeat: true
        onTriggered: root.tear()
    }
}
