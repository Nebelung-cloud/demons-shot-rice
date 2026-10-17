import QtQuick
import qs

// рубашка колоды: Plum, косая сетка, D фрактурой в ромбе
Rectangle {
    width: 220
    height: 380
    radius: 10
    color: Theme.cloak
    border { width: 1.5; color: Theme.line }
    clip: true

    // косая сетка через 14px
    Canvas {
        anchors.fill: parent
        anchors.margins: 1.5
        readonly property var pal: Theme.pal; onPalChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.strokeStyle = Theme.fade(Theme.bone, 0.13);
            g.lineWidth = 1;
            for (let k = -height; k < width + height; k += 14) {
                g.beginPath(); g.moveTo(k, 0); g.lineTo(k + height, height); g.stroke();
                g.beginPath(); g.moveTo(k, height); g.lineTo(k + height, 0); g.stroke();
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 9
        radius: 3
        color: "transparent"
        border { width: 1.5; color: Theme.line }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 96
        height: 96
        rotation: 45
        color: Theme.cloak
        border { width: 1.5; color: Theme.line }
        Text {
            anchors.centerIn: parent
            rotation: -45
            text: "D"
            font { family: Theme.frak; pixelSize: 64 }
            color: Theme.rose
        }
    }
    // арки над и под ромбом (его диагональ ~136)
    Flourish { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height / 2 - 80 - height; kind: "swag"; k: 2.4; color: Theme.line }
    Flourish { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height / 2 + 80; kind: "swag"; k: 2.4; flip: true; color: Theme.line }
}
