import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import qs

// карта таро (референс il_fullxfull…jpg, тёмная): тонкая линейная графика Bone,
// цифра готикой над завитком, имя фрактурой между ромбами, внутри — сцена (слот)
Item {
    id: root

    property string num
    property string name
    property bool up: false // «перевёрнутая»: сливовая заливка + Crimson-контур со свечением
    property int seed: 0    // сдвиг искр, у каждой карты свой
    property bool rays: true
    property real raysY: 0.45 // центр лучей по высоте сцены
    property real raysR: 150  // длина лучей: короче — не лезут в подписи под рисунком
    property bool sparks: false
    default property alias art: col.data   // столбик по центру (Art.T1, Art.Moon …)
    property alias scene: slot.data        // свободный слой (Art.Water, Art.Curtain)
    property alias under: under.data       // на всю карту, под содержимым (мышь)
    property real dim: 0                   // притушить: дальние карты на локе

    readonly property color ln: Theme.fade(Theme.bone, up ? 0.9 : 0.78)

    width: 220
    height: 380

    // Balatro (как в концепте): карта чуть покачивается, под курсором прогибается к нему в 3D и подрастает.
    // Наклон — на внутреннем face: свой transform у корня занимают веер/рука/колода
    property bool live: true
    property bool hot: true // можно ли наклоняться к курсору: рука решает сама, какая карта под мышью
    property real rx: 0
    property real ry: 0
    property real k: 1
    property real t: seed * 1.7
    // карта на экране: Item.visible не знает, что окно скрыто, а скрытые попапы держат карты всегда — без этого анимации тикают вхолостую
    readonly property bool shown: visible && (Window.window?.visible ?? false)

    // рука ловит мышь своими зонами под картами, а HoverHandler карты съедал бы у них ховер (Qt 6.12, blocking не спасает):
    // там ownHover: false, курсор приходит в aim от зоны
    property bool ownHover: true
    property point aim: tilt.point.position

    HoverHandler { id: tilt; enabled: root.live && root.ownHover }
    FrameAnimation {
        running: root.live && root.shown
        onTriggered: {
            const p = root.aim, on = root.hot && (tilt.hovered || !root.ownHover);
            const f = 1 - Math.pow(0.86, frameTime * 60); // ponytail: lerp вместо пружины; пружина с перелётом — если захочется «желе»
            root.rx += ((on ? (0.5 - p.y / root.height) * 30 : 0) - root.rx) * f; // ±15° к курсору
            root.ry += ((on ? (p.x / root.width - 0.5) * 30 : 0) - root.ry) * f;
            root.k += ((on ? 1.05 : 1) - root.k) * f;
            root.t += frameTime;
        }
    }

    // ниже всего: прямоугольники мышь не ловят, кнопки поверх ловят сами.
    // Вне face: наклон и подрастание не двигают зону мыши, иначе на краю карта дёргается
    Item { id: under; anchors.fill: parent }

    Item {
        id: face
        anchors.fill: parent
        transform: [
            Rotation { origin.x: 110; origin.y: 190; angle: Math.sin(root.t * 0.8) * 1.2 },
            Rotation { origin.x: 110; origin.y: 190; axis { x: 0; y: 1; z: 0 } angle: root.ry + Math.cos(root.t) * 4; distanceToPlane: 900 },
            Rotation { origin.x: 110; origin.y: 190; axis { x: 1; y: 0; z: 0 } angle: root.rx + Math.sin(root.t * 1.3) * 3; distanceToPlane: 900 },
            Scale { origin.x: 110; origin.y: 190; xScale: root.k; yScale: root.k }
        ]


        RectangularShadow {
            anchors.fill: body
            radius: 10
            blur: 60
            offset.y: 30
            color: Qt.rgba(0, 0, 0, 0.7)
        }

        RectangularShadow {
            id: glow
            visible: root.up
            anchors.fill: body
            radius: 10
            blur: 60
            spread: 1
            color: Theme.crimson
            // дышит, как открытая карта в концепте
            SequentialAnimation on opacity {
                running: root.up
                paused: running && !root.shown
                loops: Animation.Infinite
                NumberAnimation { from: 0.45; to: 0.7; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.7; to: 0.45; duration: 4000; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            id: body
            anchors.fill: parent
            radius: 10
            border.width: 1.5
            border.color: root.up ? Theme.crimson : root.ln
            gradient: Gradient {
                GradientStop { position: 0; color: root.up ? Theme.plum : Theme.mix(Theme.wine, Theme.void_, 0.5) }
                GradientStop { position: 1; color: root.up ? Theme.cloak : Theme.mix(Theme.crypt, Theme.void_, 0.5) }
            }
        }

        Rectangle {
            id: inner
            anchors.fill: parent
            anchors.margins: 9
            radius: 3
            color: "transparent"
            border.width: 1.5
            border.color: root.ln
            clip: true

            // цифра готикой над завитком
            Column {
                id: numRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                spacing: -1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.num
                    font { family: Theme.goth; pixelSize: 20; weight: Font.Bold; letterSpacing: 2 }
                    color: Theme.bone
                }
                Flourish { anchors.horizontalCenter: parent.horizontalCenter; kind: "scroll"; k: 1.6; color: root.ln }
            }

            Item {
                id: art
                anchors { top: numRow.bottom; bottom: plate.top; left: parent.left; right: parent.right }
                anchors.margins: 6

                // лучи: тонкие спицы через 15°, гаснут к краю, медленно вращаются
                Canvas {
                    id: rays
                    visible: root.rays
                    x: (parent.width - width) / 2
                    y: parent.height * root.raysY - height / 2
                    width: 300; height: 300
                    opacity: 0.5
                    readonly property var pal: Theme.pal; onPalChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d"), c = width / 2;
                        g.reset();
                        const fade = g.createRadialGradient(c, c, 62, c, c, root.raysR);
                        fade.addColorStop(0, root.ln);
                        fade.addColorStop(1, "transparent");
                        g.strokeStyle = fade;
                        g.lineWidth = 1;
                        for (let a = 0; a < 360; a += 15) {
                            const r = a * Math.PI / 180;
                            g.beginPath();
                            g.moveTo(c + Math.cos(r) * 64, c + Math.sin(r) * 64);
                            g.lineTo(c + Math.cos(r) * root.raysR, c + Math.sin(r) * root.raysR);
                            g.stroke();
                        }
                    }
                    RotationAnimation on rotation { running: root.rays; paused: running && !root.shown; from: 0; to: 360; duration: 90000; loops: Animation.Infinite }
                }

                // руны старшего футарка по краям сцены (вместо искр ✦), выжжены как на деревянных плашках.
                // Без sparks не создаются вовсе: 11 скрытых Text на каждую карту (на локе их 15)
                Repeater {
                    model: root.sparks ? [[6,6],[90,5],[4,30],[93,26],[8,58],[90,55],[14,84],[84,86],[50,2],[30,12],[72,14]] : []
                    Text {
                        required property var modelData
                        required property int index
                        visible: (index + root.seed) % 3 !== 0
                        x: art.width * ((modelData[0] + root.seed * 3) % 94) / 100
                        y: art.height * modelData[1] / 100
                        text: "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"[(index * 7 + root.seed * 5) % 24]
                        rotation: (index * 37 + root.seed * 11) % 50 - 25
                        font { family: "Noto Sans Runic"; pixelSize: 10 + (index * 5 + root.seed) % 6 }
                        color: Theme.rose
                    }
                }

                Item {
                    id: slot
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: col
                    anchors.centerIn: parent
                    width: parent.width - 4
                    spacing: 0
                }
            }

            Item {
                id: plate
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 36

                Rectangle { anchors.fill: parent; color: root.up ? Theme.fade(Theme.void_, 0.5) : "transparent" }
                Rectangle { width: parent.width; height: 1.5; color: root.ln }
                // двойная черта плашки
                Rectangle { x: 11; y: 3; width: parent.width - 22; height: 1; color: root.ln }

                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; rotation: 45
                        color: "transparent"; border { width: 1; color: Theme.rose }
                    }
                    Text {
                        text: root.name
                        font { family: Theme.frak; pixelSize: 21 }
                        color: Theme.bone
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; rotation: 45
                        color: "transparent"; border { width: 1; color: Theme.rose }
                    }
                }
            }
        }

        Rectangle { visible: root.dim > 0; anchors.fill: parent; radius: 10; color: Theme.void_; opacity: root.dim; z: 100 }
    }
}
