import QtQuick
import QtQuick.Shapes
import qs

// детали книги (house rules) и свитка (pact): §-параграф, строки через отточие, сургучная печать-тумблер, выбор словом.
// Подключаются как Book.Seal {}, Book.Opt {} …
QtObject {
    // параграф: § слово, линейка, справа подпись
    component Sec: Item {
        id: sc
        property string text
        property string sub
        width: parent?.width ?? 0
        height: 44
        Text { id: sg; y: 20; text: "§"; color: Theme.crimson; font { family: Theme.goth; pixelSize: 20; bold: true } }
        Text { id: st; x: sg.implicitWidth + 12; y: 20; text: sc.text; color: Theme.bone; font { family: Theme.goth; pixelSize: 20; bold: true } }
        Small { id: ss; anchors.right: parent.right; anchors.baseline: st.baseline; text: sc.sub }
        Rectangle {
            x: st.x + st.implicitWidth + 12
            y: st.y + st.baselineOffset - 5
            width: (sc.sub ? ss.x - 12 : sc.width) - x
            height: 1
            color: Theme.mix(Theme.wine, Theme.bone, 0.25, 0.8)
        }
    }
    component Small: Text {
        color: Theme.ash
        font { family: Theme.mono; pixelSize: 9; letterSpacing: 2; capitalization: Font.AllUppercase }
    }
    // отточие до значения
    component Leader: Shape {
        id: ld
        height: 2
        ShapePath {
            strokeColor: Theme.fade(Theme.ash, 0.55)
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 2] // в толщинах штриха: точка 2px, зазор 4px
            capStyle: ShapePath.FlatCap
            startX: 0
            startY: 1
            PathLine { x: Math.max(0, ld.width); y: 1 }
        }
    }
    // строка правила: подпись, отточие, справа контрол
    component Line: Item {
        id: ln
        property string text
        property string sub
        default property alias ctl: slot.data
        width: parent?.width ?? 0
        height: 42
        Text { id: lt; anchors.verticalCenter: parent.verticalCenter; text: ln.text; color: Theme.ink; font { family: Theme.goth; pixelSize: 22 } }
        Small { id: ls; x: lt.implicitWidth + 12; anchors.baseline: lt.baseline; text: ln.sub }
        Leader { x: (ln.sub ? ls.x + ls.implicitWidth : lt.implicitWidth) + 14; y: lt.y + lt.baselineOffset - 4; width: slot.x - x - 14 }
        Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }
    // выбор строкой: выбранная — крест на полях
    component Opt: Item {
        id: o
        property string text
        property string sub
        property bool on
        property bool hot             // курсор клавиатуры — как под мышью
        property string lead          // метка слева от имени: код страны у застав
        default property alias tail: oslot.data
        signal clicked
        width: parent?.width ?? 0
        height: 36
        Text {
            id: dag
            x: -30
            anchors.verticalCenter: parent.verticalCenter
            visible: o.on
            text: "†"
            color: Theme.crimson
            font { family: Theme.goth; pixelSize: 26 }
            NumberAnimation on scale { id: stab; running: false; from: 1.8; to: 1; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
        }
        // анимация — только на клик: при сборке страницы биндинг тоже дёргает onChanged
        property bool ready
        Component.onCompleted: ready = true
        onOnChanged: if (on && ready) stab.restart()
        Text {
            id: ol
            anchors.baseline: ot.baseline
            visible: !!o.lead
            text: o.lead
            color: Theme.rose
            font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 1.2 }
        }
        Text {
            id: ot
            x: o.lead ? 48 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: o.text
            color: o.on ? Theme.bone : oh.containsMouse || o.hot ? Theme.ink : Theme.ash
            font { family: Theme.goth; pixelSize: 20 }
        }
        Small { id: os; x: ot.x + ot.implicitWidth + 12; anchors.baseline: ot.baseline; text: o.sub }
        Leader { x: (o.sub ? os.x + os.implicitWidth : ot.x + ot.implicitWidth) + 14; y: ot.y + ot.baselineOffset - 4; width: oslot.x - x - 14 }
        // под хвостом: кнопки в хвосте (Forget у bluetooth) ловят клик сами
        MouseArea { id: oh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: o.clicked() }
        Item { id: oslot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }
    // переключатель — сургучная печать с D: нет печати — пунктирный круг; поставил — капля сургуча шлёпается сверху
    component Seal: Item {
        id: sl
        property bool on
        property real d: 32
        signal toggled
        width: d
        height: d
        Shape {
            visible: !sl.on
            anchors.fill: parent
            ShapePath {
                strokeColor: Theme.fade(Theme.ash, 0.6)
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 2]
                fillColor: "transparent"
                PathAngleArc { centerX: sl.d / 2; centerY: sl.d / 2; radiusX: sl.d / 2 - 1; radiusY: sl.d / 2 - 1; sweepAngle: 360 }
            }
        }
        Item {
            id: wax
            visible: sl.on
            anchors.fill: parent
            rotation: -14
            // подтёк сургуча
            Rectangle {
                x: sl.d * 0.78
                y: sl.d * 0.72
                width: sl.d * 0.28
                height: sl.d * 0.25
                radius: width / 2
                color: Theme.mix(Theme.crimson, Theme.void_, 0.25)
            }
            // блик слева сверху: вертикальный градиент, повёрнутый на -40°
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                rotation: -40
                border { width: sl.d / 8; color: Theme.mix(Theme.crimson, Theme.void_, 0.25) }
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.mix(Theme.crimson, Theme.bone, 0.3) }
                    GradientStop { position: 0.4; color: Theme.crimson }
                    GradientStop { position: 1; color: Theme.mix(Theme.crimson, Theme.void_, 0.45) }
                }
            }
            Text {
                anchors.centerIn: parent
                text: "D"
                color: Theme.mix(Theme.crimson, Theme.void_, 0.5)
                style: Text.Raised
                styleColor: Theme.mix(Theme.crimson, Theme.bone, 0.3)
                font { family: Theme.frak; pixelSize: sl.d * 0.53; bold: true }
            }
            ParallelAnimation {
                id: stamp
                NumberAnimation { target: wax; property: "scale"; from: 1.9; to: 1; duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                NumberAnimation { target: wax; property: "opacity"; from: 0; to: 1; duration: 200 }
            }
        }
        property bool ready
        Component.onCompleted: ready = true
        onOnChanged: if (on && ready) stamp.restart()
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sl.toggled() }
    }
    // выбор из нескольких — слова через точку, выбранное обведено чернилами от руки
    component Pick: Row {
        id: pk
        property var opts: []
        property int cur: -1
        signal picked(int i)
        spacing: 24
        Repeater {
            model: pk.opts
            Item {
                id: w
                required property string modelData
                required property int index
                readonly property bool on: index === pk.cur
                width: wt.implicitWidth
                height: wt.implicitHeight
                Text { visible: w.index > 0; x: -15; text: "·"; color: Theme.fade(Theme.ash, 0.5); font: wt.font }
                Text { id: wt; text: w.modelData; color: w.on ? Theme.bone : wm.containsMouse ? Theme.ink : Theme.ash; font { family: Theme.goth; pixelSize: 21 } }
                // обводка проявляется слева направо, как росчерк
                Item {
                    id: ring
                    property real rev: 1
                    visible: w.on
                    x: -10
                    y: -6
                    width: (wt.width + 24) * rev
                    height: wt.height + 11
                    clip: true
                    Rectangle {
                        width: wt.width + 20
                        height: parent.height
                        radius: height / 2
                        rotation: -5
                        color: "transparent"
                        border { width: 1.5; color: Theme.crimson }
                    }
                    NumberAnimation on rev { id: draw; running: false; from: 0; to: 1; duration: 350; easing.type: Easing.OutQuad }
                }
                property bool ready
                Component.onCompleted: ready = true
                onOnChanged: if (on && ready) draw.restart()
                MouseArea { id: wm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pk.picked(w.index) }
            }
        }
    }
    // ползунок: тянется вживую, применяется на отпускании (и на колёсике) — чтобы не плодить процессы на каждый пиксель
    component Kv: Item {
        id: kv
        property string k
        property string v
        width: parent?.width ?? 0
        height: 30
        Text { id: kk; anchors.bottom: parent.bottom; text: kv.k.toUpperCase(); color: Theme.ash; font { family: Theme.mono; pixelSize: 11; letterSpacing: 2.2 } }
        Leader { x: kk.implicitWidth + 12; y: kk.y + kk.baselineOffset - 2; width: vv.x - x - 12 }
        Text { id: vv; anchors.right: parent.right; anchors.baseline: kk.baseline; text: kv.v; color: Theme.bone; font { family: Theme.mono; pixelSize: 14 } }
    }
}
