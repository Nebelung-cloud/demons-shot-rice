import QtQuick
import qs
import qs.components
import "../components/arcana.js" as Arcana

// падающая карта на локе: лицо аркана с одной стороны, рубашка с другой, кувыркается в 3D.
// дальние (s меньше) мельче, темнее и падают медленнее (20–70 с на экран)
Item {
    id: root

    property int i: 0
    property real stageH: 1080
    readonly property real s: 0.26 + (i * 3 % 5) * 0.09
    readonly property real t: 18 / s                 // с на экран
    readonly property real phase: (i * 4.7 / t) % 1  // как отрицательная задержка в css
    readonly property real dx: i % 3 * 40 - 40
    property real p: 0
    property real q: 0
    // ponytail: без размытия дальних карт — только яркость и прозрачность; blur на 14 картах дорого
    readonly property var arc: [Arcana.major(15), Arcana.major(18), Arcana.major(17), Arcana.major(13),
        Arcana.major(19), Arcana.major(10), Arcana.major(16)][i % 7]

    x: (i % 2 ? 1420 + (i * 137) % 400 : (i * 181) % 420 - 20) - 110 + dx * ((p + phase) % 1)
    y: -420 + (stageH + 540) * ((p + phase) % 1)
    width: 220
    height: 380
    scale: s
    opacity: 0.3 + s

    NumberAnimation on p { from: 0; to: 1; duration: root.t * 1000; loops: Animation.Infinite }
    NumberAnimation on q { from: 0; to: 1; duration: (8 + root.i % 4 * 3) * 1000; loops: Animation.Infinite }

    Flipable {
        anchors.fill: parent
        front: Card {
            live: false // кувыркаются сами
            num: root.arc.num
            name: root.arc.name
            seed: root.i
            dim: 0.65 - root.s
            raysY: 0.5 // одна иконка — по центру сцены
            ArcanaArt { glyph: root.arc.glyph }
        }
        back: BackCard {
            Rectangle { anchors.fill: parent; radius: 10; color: Theme.void_; opacity: 0.65 - root.s + 0.3 }
        }
        transform: Rotation {
            origin.x: 110
            origin.y: 190
            axis { x: root.i % 2 ? 1 : -0.6; y: 0.5 + root.i % 3 * 0.3; z: 0.3 }
            angle: 360 * ((root.q + root.phase) % 1)
        }
    }
}
