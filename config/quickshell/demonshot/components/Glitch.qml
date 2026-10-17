import QtQuick

// тот же разрыв, что в GlitchText, но для любого item: layer.effect: Glitch {}
ShaderEffect {
    property vector2d size: Qt.vector2d(width, height)
    property vector2d freq: Qt.vector2d(0.022, 0.09)
    property real amount: 26
    property real seed: 13
    fragmentShader: Qt.resolvedUrl("shaders/glitch.frag.qsb")
}
