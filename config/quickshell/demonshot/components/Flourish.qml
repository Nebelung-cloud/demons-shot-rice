import QtQuick
import QtQuick.Shapes
import qs

// орнамент-разделитель 44×14: рисуется левая половина, правая — её зеркало.
// kind: scroll (завитки + ромб), rule (линия, полумесяцы, ромб), beads (бусины), swag (арка с каплями; flip — вниз)
Item {
    id: root

    property string kind: "scroll"
    property color color: Theme.rose
    property bool flip: false
    property real k: 1 // масштаб: толщина штриха растёт вместе с ним

    readonly property var paths: ({
        scroll: ["M22 7 C17 7 15 10 11 9.5 C7 9 6.5 4.5 3.8 5 C1.6 5.4 1.8 8.6 3.9 8.4 C5.3 8.3 5.2 6.4 4.1 6.6",
                 "M22 4 L20 7 L22 10 Z"],
        rule: ["M3 7 H19.5 M22 4.5 L19.5 7 L22 9.5 M7.5 4.5 A2.6 2.6 0 0 0 7.5 9.5",
               "M3 5.8 A1.2 1.2 0 1 0 3 8.2 A1.2 1.2 0 1 0 3 5.8 Z"],
        beads: ["", [[2, .45], [5, .55], [8, .7], [11, .85], [14.2, 1.05], [17.7, 1.3], [22, 2]]
                    .map(([x, r]) => `M${x} ${7 - r} A${r} ${r} 0 1 0 ${x} ${7 + r} A${r} ${r} 0 1 0 ${x} ${7 - r} Z`).join(" ")],
        swag: ["M1.5 10 C2 7.5 4.5 7.5 7 8.3 C12 9.8 17 9 19.6 6.4 L22 3",
               "M1.5 9 A1.4 1.4 0 1 0 1.5 11.8 A1.4 1.4 0 1 0 1.5 9 Z M22 1 L21 3 L22 5 Z"]
    })

    implicitWidth: 44 * k
    implicitHeight: 14 * k
    transform: Scale { origin.y: 7 * root.k; yScale: root.flip ? -1 : 1 }

    Item {
        width: 44
        height: 14
        scale: root.k
        transformOrigin: Item.TopLeft

        Repeater {
            model: 2
            Shape {
                required property int index
                width: 44
                height: 14
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { origin.x: 22; xScale: index ? -1 : 1 }

                ShapePath {
                    strokeColor: root.color
                    strokeWidth: 1
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: root.paths[root.kind][0] }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: root.color
                    PathSvg { path: root.paths[root.kind][1] }
                }
            }
        }
    }
}
