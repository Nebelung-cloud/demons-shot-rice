import QtQuick
import QtQuick.Layouts
import qs

// линейные сцены и подписи для карт таро: Art.Moon, Art.Water, Art.T2 …
// всё, что идёт в столбик (ColumnLayout карты), уже по центру
QtObject {

    // заголовок внутри карты: готика 26
    component T1: Text {
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        font { family: Theme.goth; pixelSize: 26; weight: Font.Bold }
        color: Theme.bone
    }

    // мелкая подпись: Montserrat 8, капс, разреженно
    component T2: Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        horizontalAlignment: Text.AlignHCenter
        font { family: Theme.p3; pixelSize: 8; weight: Font.DemiBold; letterSpacing: 2.7; capitalization: Font.AllUppercase }
        color: Theme.ash
    }

    // крупная цифра + приписка фрактурой (12:53 PM, 21 %)
    component Big: Row {
        property string text
        property string small
        property int size: 56
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 14
        spacing: 4
        Text { text: parent.text; color: Theme.bone; font { family: Theme.goth; pixelSize: parent.size; weight: Font.Bold } }
        Text {
            anchors.baseline: parent.children[0].baseline
            text: parent.small
            visible: text !== ""
            font { family: Theme.frak; pixelSize: Math.round(parent.size * 0.4) }
            color: Theme.rose
        }
    }

    component Icon: PixelIcon {
        Layout.alignment: Qt.AlignHCenter
        size: 90
    }

    // полумесяц пикселями (сетка 23, клетка 4 — как px-иконки): контур Line и Rose-серп; lit — насколько освещён (0…1)
    component Moon: Canvas {
        property real lit: 0.25
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 92
        implicitHeight: 92
        onLitChanged: requestPaint()
        readonly property var pal: Theme.pal; onPalChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"), n = 23, k = width / n, c = n / 2, r = c;
            const sx = c + r * 2 * lit, sy = c - r * 0.2 * lit; // центр тени
            g.reset();
            for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
                const x = i + 0.5, y = j + 0.5, d = Math.hypot(x - c, y - c);
                if (d > r) continue;
                if (d > r - 1.2) g.fillStyle = Theme.line;
                else if (Math.hypot(x - sx, y - sy) > r - 1) g.fillStyle = Theme.rose;
                else continue;
                g.fillRect(i * k, j * k, k, k);
            }
        }
    }

    // вода: горизонтальные черты у нижнего края карты (кладётся в scene)
    component Water: Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6; bottomMargin: 0 }
        spacing: 6
        opacity: 0.6
        Repeater {
            model: 5
            Rectangle { width: parent.width; height: 1; color: Theme.line }
        }
    }

    // занавесь: вертикальные нити, гаснут книзу (кладётся в scene, side: -1 слева, 1 справа)
    component Curtain: Row {
        property int side: -1
        x: side < 0 ? 4 : parent.width - width - 4
        spacing: 5
        opacity: 0.7
        Repeater {
            model: 6
            Rectangle {
                width: 1
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.4; color: Theme.line }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }

    // круги на воде
    component Ripples: Canvas {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 14
        implicitWidth: 150
        implicitHeight: 36
        opacity: 0.7
        readonly property var pal: Theme.pal; onPalChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.strokeStyle = Theme.line;
            g.lineWidth = 1;
            for (let r = 7; r <= width / 2; r += 8) {
                g.beginPath();
                g.ellipse(width / 2 - r, height / 2 - r * height / width, r * 2, r * 2 * height / width);
                g.stroke();
            }
        }
    }

    // орб: контурный круг с Crimson-дугой прогресса, внутри — что угодно
    component Orb: Item {
        property real value: 0
        property int size: 128
        default property alias content: inner.data
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: size
        implicitHeight: size
        onValueChanged: arc.requestPaint()
        Canvas {
            id: arc
            anchors.fill: parent
            readonly property var pal: Theme.pal; onPalChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"), c = width / 2;
                g.reset();
                g.lineWidth = 1.5;
                g.strokeStyle = Theme.line;
                g.beginPath(); g.arc(c, c, c - 1, 0, Math.PI * 2); g.stroke();
                g.lineWidth = 3;
                g.strokeStyle = Theme.fade(Theme.bone, 0.12);
                g.beginPath(); g.arc(c, c, c - 8.5, 0, Math.PI * 2); g.stroke();
                g.strokeStyle = Theme.crimson;
                g.beginPath(); g.arc(c, c, c - 8.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, parent.value))); g.stroke();
            }
        }
        Item { id: inner; anchors.centerIn: parent; width: childrenRect.width; height: childrenRect.height }
    }

    // столбики в контурных рамках, заливка Crimson→Rose: model [[значение 0…100, подпись], …]
    component Bars: Row {
        id: bars
        property var model: []
        property int h: 130
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 14
        spacing: 14
        // по числу столбиков, а не по массиву: новый массив каждые 2 с пересоздавал бы столбики, и Behavior на высоте не играл
        Repeater {
            model: bars.model.length
            Column {
                required property int index
                readonly property var modelData: bars.model[index]
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(modelData[0])
                    font { family: Theme.goth; pixelSize: 15 }
                    color: Theme.bone
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: parent.parent.h
                    color: "transparent"
                    border { width: 1; color: Theme.line }
                    Rectangle {
                        x: 2; width: 10
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                        height: Math.max(0, (parent.height - 4) * Math.min(100, modelData[0]) / 100)
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.rose }
                            GradientStop { position: 1; color: Theme.crimson }
                        }
                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData[1]
                    font { family: Theme.p3; pixelSize: 7; weight: Font.DemiBold; letterSpacing: 1 }
                    color: Theme.ash
                }
            }
        }
    }

    // строки списка: model [[слева, справа, выделена, глиф?], …]; глиф — своим столбиком перед текстом
    component Rows: Column {
        property var model: []
        Layout.fillWidth: true
        Layout.topMargin: 12
        Repeater {
            model: parent.model
            Item {
                required property var modelData
                width: parent.width
                height: 24
                Rectangle { width: parent.width; height: 1; color: Theme.fade(Theme.bone, 0.18) }
                Text {
                    id: glyph
                    visible: !!modelData[3]
                    x: 4
                    width: visible ? 18 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData[3] ?? ""
                    font { family: Theme.mono; pixelSize: 14 }
                    color: modelData[2] ? Theme.rose : Theme.bone
                }
                Text {
                    x: glyph.visible ? 28 : 4
                    width: parent.width - x - right.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: modelData[0]
                    font { family: Theme.goth; pixelSize: 15 }
                    color: modelData[2] ? Theme.rose : Theme.bone
                }
                Text {
                    id: right
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    text: modelData[1]
                    font { family: Theme.p3; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1; capitalization: Font.AllUppercase }
                    color: Theme.ash
                }
            }
        }
    }

    // кнопки плеера: ⏮ ⏯ ⏭, середина — Crimson
    component Ctrl: Row {
        property bool playing
        signal prev
        signal toggle
        signal next
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 10
        spacing: 4
        Repeater {
            model: [["󰒮", 40], [parent.playing ? "󰏤" : "󰐊", 52], ["󰒭", 40]]
            Rectangle {
                required property var modelData
                required property int index
                width: modelData[1]
                height: 28
                radius: 2
                color: index === 1 ? Theme.crimson : "transparent"
                border { width: 1; color: index === 1 ? Theme.crimson : Theme.line }
                Text { anchors.centerIn: parent; text: modelData[0]; color: Theme.bone; font { family: Theme.mono; pixelSize: 15 } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: [parent.parent.prev, parent.parent.toggle, parent.parent.next][index]()
                }
            }
        }
    }

    // столбики cava: values 0…1
    component Eq: Row {
        property var values: []
        property int h: 56
        Layout.fillWidth: true
        Layout.topMargin: 14
        height: h
        Layout.preferredHeight: h // иначе раскладка берёт implicitHeight по самому высокому столбику и прыгает
        spacing: 3
        Repeater {
            model: parent.values.length
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: (parent.width - 3 * (parent.values.length - 1)) / parent.values.length
                height: Math.max(2, parent.h * (parent.values[index] ?? 0))
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.rose }
                    GradientStop { position: 1; color: Theme.crimson }
                }
            }
        }
    }
}
