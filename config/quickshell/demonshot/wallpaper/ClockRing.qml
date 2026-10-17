import QtQuick
import QtQuick.Shapes
import qs

// часы-колесо (реф: KIRA — FOCUS): кольцо с зубцами и текстом по кругу медленно крутится,
// стрелки-копья показывают настоящее время, всё наклонено в 3D. Центр колеса — (0, 0) этого Item
Item {
    id: root

    property real r: 470          // радиус
    property real band: 56        // ширина кольца
    property string big: "CAN'T STOP · "
    property string small: "let it slide · get loose · "
    property real bigPad: 64
    property real smallPad: 178
    property real hourLen: 240
    property real minLen: 380
    property real spin: 0         // поворот кольца, градусы
    property real tiltX: 18
    property real tiltY: -26
    property real tiltZ: 8
    property date time: new Date()

    opacity: 0.85

    // окружность; ccw — против часовой (дырка при WindingFill)
    function circle(rad, ccw) {
        const f = ccw ? 0 : 1;
        return `M ${r + rad} ${r} A ${rad} ${rad} 0 1 ${f} ${r - rad} ${r} A ${rad} ${rad} 0 1 ${f} ${r + rad} ${r} Z `;
    }

    // полоса (наружный круг по часовой, внутренний против) + 40 зубцов-секторов по 3.4° от r−1 до r+23
    readonly property string gear: {
        let p = circle(r) + circle(r - band, true);
        const pt = (rad, deg) => `${r + rad * Math.sin(deg * Math.PI / 180)} ${r - rad * Math.cos(deg * Math.PI / 180)}`;
        for (let k = 0; k < 40; k++) {
            const a = 2 + k * 9, b = a + 3.4, ro = r + 23, ri = r - 1;
            p += `M ${pt(ri, a)} L ${pt(ro, a)} A ${ro} ${ro} 0 0 1 ${pt(ro, b)} L ${pt(ri, b)} A ${ri} ${ri} 0 0 0 ${pt(ri, a)} Z `;
        }
        return p;
    }

    Item {
        id: face
        x: -root.r
        y: -root.r
        width: root.r * 2
        height: root.r * 2
        // css: rotateX rotateY rotate — справа налево
        transform: [
            Rotation { origin.x: root.r; origin.y: root.r; angle: root.tiltZ },
            Rotation { origin.x: root.r; origin.y: root.r; axis { x: 0; y: 1; z: 0 } angle: root.tiltY; distanceToPlane: 1800 },
            Rotation { origin.x: root.r; origin.y: root.r; axis { x: 1; y: 0; z: 0 } angle: root.tiltX; distanceToPlane: 1800 }
        ]

        // кольцо, зубцы и текст: один раз в текстуру, дальше крутится готовая картинка
        Item {
            // запас 30px: зубцы торчат за кольцо, а слой режет по своим границам
            x: -30
            y: -30
            width: root.r * 2 + 60
            height: root.r * 2 + 60
            rotation: root.spin
            layer.enabled: true
            layer.smooth: true

            Item {
              x: 30
              y: 30
              width: root.r * 2
              height: root.r * 2

              // шестерня: полоса и 40 зубцов одним силуэтом — заливка Void, костяная обводка снаружи,
              // тонкая белая линия внутри полосы (как в concept.html)
              Shape {
                  anchors.fill: parent
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath { strokeColor: Theme.bone; strokeWidth: 3; fillColor: Theme.bone; fillRule: ShapePath.WindingFill; PathSvg { path: root.gear } }
                  ShapePath { strokeWidth: -1; fillColor: Theme.void_; fillRule: ShapePath.WindingFill; PathSvg { path: root.gear } }
                  ShapePath {
                      fillColor: "transparent"
                      strokeWidth: 1
                      strokeColor: "#FFFFFF"
                      PathSvg { path: root.circle(root.r - 9) }
                  }
              }

              // текст по кругу: верх букв наружу
              Repeater {
                  model: (root.big.repeat(3)).split("")
                  Text {
                      required property string modelData
                      required property int index
                      x: root.r - width / 2
                      y: root.bigPad
                      text: modelData
                      font { family: Theme.goth; pixelSize: 96; weight: Font.Black }
                      color: Theme.bone
                      transform: Rotation { origin.x: width / 2; origin.y: root.r - root.bigPad; angle: index * 360 / (root.big.length * 3) }
                  }
              }
              Repeater {
                  model: (root.small.repeat(3)).split("")
                  Text {
                      required property string modelData
                      required property int index
                      x: root.r - width / 2
                      y: root.smallPad
                      text: modelData
                      font { family: Theme.goth; pixelSize: 40; weight: Font.Black }
                      color: Theme.rose
                      transform: Rotation { origin.x: width / 2; origin.y: root.r - root.smallPad; angle: index * 360 / (root.small.length * 3) }
                  }
              }
            }
        }

        Needle { len: root.hourLen; angle: (root.time.getHours() % 12) * 30 + root.time.getMinutes() * 0.5 }
        Needle { len: root.minLen; angle: root.time.getMinutes() * 6 }

        // ось: двойное костяное кольцо
        Rectangle {
            x: root.r - 22; y: root.r - 22
            width: 44; height: 44; radius: 22
            color: Theme.void_
            border { width: 1.5; color: Theme.bone }
            Rectangle { anchors.centerIn: parent; width: 32; height: 32; radius: 16; color: "transparent"; border { width: 1.5; color: Theme.bone } }
        }
    }

    // стрелка-копьё: наконечник с загнутыми крыльями, гарда, трилистник из трёх колец; заливка Void, костяной контур по силуэту
    component Needle: Shape {
        id: n
        property real len
        property real angle
        x: root.r - 50
        y: root.r - len - 150
        width: 100
        height: len + 150
        preferredRendererType: Shape.CurveRenderer
        transform: Rotation {
            origin.x: 50; origin.y: n.height; angle: n.angle
            Behavior on angle { NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }
        }

        // сначала толстый костяной контур всех частей, потом заливка поверх — контур остаётся только снаружи
        ShapePath { strokeColor: Theme.bone; strokeWidth: 4; fillColor: Theme.bone; fillRule: ShapePath.WindingFill; joinStyle: ShapePath.MiterJoin; PathSvg { path: n.svg } }
        ShapePath { strokeWidth: -1; fillColor: Theme.void_; fillRule: ShapePath.WindingFill; PathSvg { path: n.svg } }

        readonly property string svg: {
            const h = height, cx = 50, top = 0;
            // древко
            let p = `M ${cx - 4.5} 150 L ${cx + 4.5} 150 L ${cx + 4.5} ${h} L ${cx - 4.5} ${h} Z `;
            // наконечник 84×166 (clip-path из концепта)
            const sx = cx - 42, pt = (ax, ay) => `${sx + 84 * ax} ${top + 166 * ay}`;
            p += `M ${pt(0.5, 0)} L ${pt(0.6, 0.42)} L ${pt(1, 0.74)} L ${pt(0.57, 0.64)} L ${pt(0.5, 1)} L ${pt(0.43, 0.64)} L ${pt(0, 0.74)} L ${pt(0.4, 0.42)} Z `;
            // гарда 100×7
            const gy = 190;
            p += `M 0 ${gy + 3.5} L 12 ${gy} L 88 ${gy} L 100 ${gy + 3.5} L 88 ${gy + 7} L 12 ${gy + 7} Z `;
            // трилистник: три кольца 9…14 px
            const ty = 150 + (h - 150) * 0.3;
            for (const [ax, ay] of [[0.5, 0.22], [0.24, 0.66], [0.76, 0.66]]) {
                const ox = cx - 38 + 76 * ax, oy = ty + 76 * ay;
                // кольцо по часовой, дырка против — при WindingFill древко сквозь дырку остаётся залитым
                p += `M ${ox + 14} ${oy} A 14 14 0 1 1 ${ox - 14} ${oy} A 14 14 0 1 1 ${ox + 14} ${oy} Z `;
                p += `M ${ox + 9} ${oy} A 9 9 0 1 0 ${ox - 9} ${oy} A 9 9 0 1 0 ${ox + 9} ${oy} Z `;
            }
            return p;
        }
    }
}
