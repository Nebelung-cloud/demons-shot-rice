import QtQuick
import qs

// фишка казино с подписью: 16 долей по краю, пунктир внутри, римская цифра; выбранная — Crimson/Bone и докручивается со slam
Item {
    id: root

    required property int index
    property string text
    property bool on: false
    signal clicked

    width: row.width
    height: 44

    Row {
        id: row
        spacing: 12

        Canvas {
            id: chip
            width: 44
            height: 44
            readonly property var pal: Theme.pal; onPalChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"), c = 22;
                g.reset();
                for (let k = 0; k < 16; k++) {
                    g.fillStyle = k % 2 ? (root.on ? Theme.crimson : Theme.crypt) : (root.on ? Theme.bone : Theme.wine);
                    g.beginPath(); g.moveTo(c, c);
                    g.arc(c, c, c, (k - 4) * Math.PI / 8, (k - 3) * Math.PI / 8);
                    g.fill();
                }
                g.fillStyle = root.on ? Theme.crimson : Theme.crypt;
                g.beginPath(); g.arc(c, c, 16, 0, Math.PI * 2); g.fill();
                g.strokeStyle = root.on ? Theme.fade(Theme.bone, 0.55) : Theme.dim;
                g.setLineDash([2, 2]);
                g.beginPath(); g.arc(c, c, 16, 0, Math.PI * 2); g.stroke();
            }
            Text {
                anchors.centerIn: parent
                text: Theme.roman(root.index + 1)
                font { family: Theme.goth; pixelSize: 15 }
                color: root.on ? Theme.bone : Theme.ash
            }
            RotationAnimation on rotation {
                id: spin
                running: false
                from: -270
                to: 0
                duration: 500
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font { family: Theme.goth; pixelSize: 22 }
            color: root.on || mouse.containsMouse ? Theme.bone : Theme.ash
        }
    }

    onOnChanged: { chip.requestPaint(); if (on) spin.restart(); }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
