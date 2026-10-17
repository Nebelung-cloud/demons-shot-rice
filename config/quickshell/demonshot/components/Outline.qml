import QtQuick
import QtQuick.Shapes
import qs

// контурный текст (как -webkit-text-stroke): только обводка, без заливки
Shape {
    id: root

    property string text
    property alias font: metrics.font
    property color color: Theme.rose
    property real stroke: 1.5

    implicitWidth: metrics.advanceWidth + stroke * 2
    implicitHeight: metrics.height + stroke * 2
    preferredRendererType: Shape.CurveRenderer

    TextMetrics { id: metrics; text: root.text }

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.stroke
        fillColor: "transparent"
        PathText { x: root.stroke; y: root.stroke; text: root.text; font: metrics.font }
    }
}
