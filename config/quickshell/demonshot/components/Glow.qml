import QtQuick
import QtQuick.Shapes
import qs

// мягкое эллиптическое свечение: радиальный градиент от color к прозрачному на fade
Shape {
    id: root

    property real rx: 100
    property real ry: 100
    property color color: Theme.plum
    property real fade: 0.7 // где гаснет, доля радиуса
    property color edge: "transparent" // цвет на краю (для виньетки: прозрачный центр, тёмный край)
    property real cx: 0     // центр
    property real cy: 0

    x: cx - rx
    y: cy - rx
    width: rx * 2
    height: rx * 2
    transform: Scale { origin.x: root.rx; origin.y: root.rx; yScale: root.ry / root.rx }

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: root.rx; centerY: root.rx; centerRadius: root.rx
            focalX: root.rx; focalY: root.rx
            GradientStop { position: 0; color: root.color }
            GradientStop { position: root.fade; color: "transparent" }
            GradientStop { position: 1; color: root.edge }
        }
        PathRectangle { width: root.width; height: root.height }
    }
}
