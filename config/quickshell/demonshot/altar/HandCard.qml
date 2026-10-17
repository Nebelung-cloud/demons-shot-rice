import QtQuick
import qs
import qs.components

// карта в руке: веер с общим центром поворота под экраном, под курсором выдвигается на 48px и «переворачивается»
Card {
    id: c

    property int i: 0
    readonly property bool hovered: mouse.containsMouse
    property real lift: hovered ? -48 : 0
    property real dealY: 0

    up: hovered
    seed: i * 3
    z: hovered ? 10 : i
    hot: hovered
    ownHover: false
    // зона стоит на месте покоя и вытянута вверх на ext, карта поднята на lift — в координаты карты
    aim: Qt.point(mouse.mouseX, mouse.mouseY - ext - lift)
    readonly property real fan: [-20, -12, -4, 4, 12, 20][i]
    readonly property real ext: hovered ? 48 : 0 // поднятая карта тянет зону вверх за собой
    transform: [
        Translate { y: c.lift + c.dealY },
        Rotation { origin.x: 110; origin.y: 1800; angle: c.fan }
    ]

    Behavior on lift { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }

    signal clicked
    // зона мыши — соседом в руке, под всеми картами (кнопки на картах кликаются, карты мышь не ловят).
    // Стоит на месте покоя: поднятая карта не уезжает из-под курсора на нижнем крае. Порядок — по i, а не по z:
    // поднятую рисуем поверх, но ловить мышь над соседом она не должна.
    // В свойстве, а не ребёнком: дети карты уходят в её колонку (default alias), и раскладка двигала бы зону
    property MouseArea zone: MouseArea {
        id: mouse
        parent: c.parent
        z: c.i - 20
        x: c.x
        y: c.y - c.ext
        width: c.width
        height: c.height + c.ext
        hoverEnabled: true
        onClicked: c.clicked()
        transform: [
            Translate { y: c.dealY },
            Rotation { origin.x: 110; origin.y: 1800 + c.ext; angle: c.fan }
        ]
    }

    // сдача: снизу, по карте через 40ms, slam
    function deal() { dealing.restart(); }
    SequentialAnimation {
        id: dealing
        PropertyAction { target: c; property: "dealY"; value: 560 }
        PauseAnimation { duration: c.i * Theme.stagger }
        NumberAnimation { target: c; property: "dealY"; to: 0; duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
    }
}
