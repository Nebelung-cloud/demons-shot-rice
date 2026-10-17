import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services
import "../components/arcana.js" as Arcana

// экран блокировки: Void с тёплым свечением в нише из двух арок, по бокам свечи; сверху дата готикой,
// по центру рваные Crimson-часы, под ними строка песни; ниже карта дня из колоды; внизу имя и пароль-линия с ☾
WlSessionLockSurface {
    id: root

    required property var auth // { buffer, fail, busy, submit() } из lock.qml
    property string layout: "EN"

    color: Theme.void_

    SystemClock { id: clock; precision: SystemClock.Minutes } // секунд на локе нет — не будить всё раз в секунду
    readonly property var card: Arcana.ofTheDay(clock.date)
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    Item {
        id: stage
        readonly property real s: Math.min(root.width / 1920, root.height / 1080)
        width: root.width / s
        height: root.height / s
        scale: s
        transformOrigin: Item.TopLeft
        focus: true

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.auth.submit();
            else if (e.key === Qt.Key_Escape) root.auth.buffer = "";
            else if (e.key === Qt.Key_Backspace) root.auth.buffer = root.auth.buffer.slice(0, -1);
            else if (e.text && e.text.charCodeAt(0) >= 32) { root.auth.buffer += e.text; root.auth.fail = false; }
            else return;
            e.accepted = true;
        }

        // замок: ниша с часами выезжает снизу, верх (LOCKED, модули) падает сверху и защёлкивается
        Translate { id: rise; y: stage.height }
        Translate { id: drop; y: -300 }
        ParallelAnimation {
            running: true
            NumberAnimation { target: rise; property: "y"; from: stage.height; to: 0; duration: 900; easing.type: Easing.OutQuart }
            SequentialAnimation {
                PauseAnimation { duration: 450 }
                NumberAnimation { target: drop; property: "y"; from: -300; to: 0; duration: 550; easing.type: Easing.OutBack; easing.overshoot: 2 }
            }
        }

        Glow { transform: rise; cx: stage.width / 2; cy: stage.height * 0.34; rx: stage.width * 0.28; ry: stage.height * 0.42; color: Theme.fade(Theme.plum, 0.6) }
        Glow { cx: stage.width / 2; cy: stage.height * 1.08; rx: stage.width * 0.6; ry: stage.height * 0.3; color: Theme.fade(Theme.wine, 0.9) }

        // падающие карты по бокам — мимо арки
        Repeater {
            model: 14
            Falling { required property int index; i: index; stageH: stage.height }
        }

        // ниша: две тонкие арки
        Arch { transform: rise; w: 820; at: 70; color: Theme.fade(Theme.rose, 0.22) }
        Arch { transform: rise; w: 768; at: 96; color: Theme.fade(Theme.bone, 0.07) }

        Candle { x: stage.width / 2 - 460; y: 690 }
        Candle { x: stage.width / 2 - 510; y: 740; scale: 0.6 }
        Candle { x: stage.width / 2 + 460; y: 690 }
        Candle { x: stage.width / 2 + 510; y: 740; scale: 0.6 }

        Column {
            transform: rise
            anchors.horizontalCenter: parent.horizontalCenter
            y: 150
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${Qt.locale("en_US").dayName(clock.date.getDay())} · ${Theme.roman(clock.date.getDate())} · ${Qt.locale("en_US").monthName(clock.date.getMonth())}`
                font { family: Theme.goth; pixelSize: 30 }
                color: Theme.bone
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.roman(clock.date.getFullYear()).toLowerCase()
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 5.5 }
                color: Theme.ash
            }
        }

        GlitchText {
            transform: rise
            x: (stage.width - width) / 2
            y: 205
            text: Qt.formatTime(clock.date, "hh:mm")
            font { family: Theme.frak; pixelSize: 220; letterSpacing: -4 }
            color: Theme.crimson
            interval: 2600 // рвётся заново время от времени
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.fade(Theme.crimson, 0.35)
                shadowBlur: 1
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 64
            }
        }

        Text {
            transform: rise
            anchors.horizontalCenter: parent.horizontalCenter
            y: 458
            text: (Media.lyrics[Media.line]?.[1] ?? "still right before your eyes").toLowerCase()
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 5.5 }
            color: Theme.rose
        }

        // карта дня: одна лицом из колоды, две рубашкой по бокам
        Item {
            transform: rise
            x: stage.width / 2
            y: 505
            scale: 0.8
            transformOrigin: Item.TopLeft
            BackCard { x: -110; transform: Rotation { origin.x: 110; origin.y: 1400; angle: -9 } opacity: 0.6 }
            BackCard { x: -110; transform: Rotation { origin.x: 110; origin.y: 1400; angle: 9 } opacity: 0.6 }
            Card {
                x: -110
                num: root.card.num
                name: root.card.name
                raysY: 0.42
                scene: Art.Water {}
                ArcanaArt { glyph: root.card.glyph; size: 100 }
                Art.T2 { Layout.topMargin: 18; text: "card of the day" }
            }
        }

        // смысл карты слева снизу
        Column {
            x: 150
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            spacing: 8
            Text { text: root.card.q; color: Theme.bone; font.family: Theme.goth; font.pixelSize: 34 }
            Text {
                text: `${root.card.num} · ${root.card.name} — карта дня`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                color: Theme.ash
            }
        }

        // виньетка
        Item {
            anchors.fill: parent
            clip: true
            Glow {
                cx: stage.width * 0.5; cy: stage.height * 0.5
                rx: stage.width * 0.8; ry: stage.height * 0.75
                color: "transparent"; fade: 0.45; edge: Theme.fade(Theme.pit, 0.85)
            }
        }

        // уголки видоискателя
        Item {
            transform: drop
            x: 90; y: 90
            width: 220; height: 230
            opacity: 0.8
            Rectangle { width: parent.width; height: 2; color: Theme.rose }
            Rectangle { width: 2; height: parent.height; color: Theme.rose }
            Text {
                x: 4; y: -height - 12
                text: "LOCKED<"
                font { family: Theme.mono; pixelSize: 22; weight: Font.Bold; letterSpacing: 3 }
                color: Theme.bone
            }
        }
        Item {
            x: stage.width - 46 - width; y: stage.height - 46 - height
            width: 220; height: 230
            opacity: 0.8
            Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: Theme.rose }
            Rectangle { x: parent.width - 2; width: 2; height: parent.height; color: Theme.rose }
        }

        // батарея, звук, раскладка — те же модули, что в баре, в ряд
        Row {
            transform: drop
            anchors { right: parent.right; rightMargin: 90 }
            y: 40
            spacing: 26
            Mod { visible: UPower.displayDevice.isLaptopBattery; label: "BAT"; value: Math.round(UPower.displayDevice.percentage * 100); v: UPower.displayDevice.percentage }
            Mod { label: "VOL"; value: Math.round((root.sink?.audio.volume ?? 0) * 100); v: root.sink?.audio.volume ?? 0 }
            Mod { label: "KB"; value: root.layout; v: 1 }
        }

        Row {
            transform: rise
            anchors.horizontalCenter: parent.horizontalCenter
            y: 866
            spacing: 14
            Text { text: Quickshell.env("USER"); color: Theme.bone; font { family: Theme.goth; pixelSize: 28 } }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: "ARCH · HYPRLAND"
                font { family: Theme.mono; pixelSize: 10; letterSpacing: 4 }
                color: Theme.ash
            }
        }

        // пароль: тонкая линия Bone с ☾ по краям, точки квадратные; ошибка — Crimson
        Item {
            transform: rise
            x: (stage.width - 380) / 2
            y: 918
            width: 380
            height: 40
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: root.auth.fail ? 2 : 1.5
                color: root.auth.fail ? Theme.crimson : Theme.bone
            }
            Row {
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: Math.min(root.auth.buffer.length, 20)
                    Rectangle { width: 8; height: 8; color: root.auth.fail ? Theme.crimson : Theme.bone }
                }
            }
            Text { x: -30; y: parent.height - 14; text: "☾"; color: Theme.ash; font { family: Theme.goth; pixelSize: 26 } }
            Text { x: parent.width + 30 - width; y: parent.height - 14; text: "☾"; color: Theme.ash; font { family: Theme.goth; pixelSize: 26 } }
        }

        Text {
            transform: rise
            visible: !root.auth.fail
            anchors.horizontalCenter: parent.horizontalCenter
            y: 984
            textFormat: Text.StyledText
            text: root.auth.busy ? "…" : `<font color="${Theme.bone}">⏎</font> ВОЙТИ · <font color="${Theme.bone}">ESC</font> СТЕРЕТЬ`
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
            color: Theme.ash
        }

        // неверный пароль — триптих костяных плашек
        Row {
            transform: rise
            visible: root.auth.fail
            anchors.horizontalCenter: parent.horizontalCenter
            y: 978
            spacing: 6
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: cant.width + 32
                    height: cant.height + 14
                    color: Theme.bone
                    rotation: [-2, 1.5, -2][index]
                    y: index === 1 ? 3 : 0
                    Text { id: cant; anchors.centerIn: parent; text: "can't"; color: Theme.void_; font { family: Theme.goth; pixelSize: 24; weight: Font.Black } }
                }
            }
        }
    }

    component Arch: Item {
        id: arch
        property real w
        property real at  // отступ сверху
        property color color
        x: (stage.width - w) / 2
        y: at
        width: w
        height: stage.height - at + 2
        // полукруг сверху + стены вниз, без пола
        Canvas {
            anchors.fill: parent
            readonly property var pal: Theme.pal; onPalChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"), r = arch.w / 2;
                g.reset();
                g.strokeStyle = arch.color;
                g.lineWidth = 1.5;
                g.beginPath();
                g.moveTo(0.75, height);
                g.lineTo(0.75, r);
                g.arc(r, r, r - 0.75, Math.PI, 0);
                g.lineTo(arch.w - 0.75, height);
                g.stroke();
            }
        }
    }

    component Candle: Item {
        Glow { cx: 0; cy: 0; rx: 110; ry: 110; fade: 1; color: Theme.fade(Theme.rose, 0.12) }
        Glow { cx: 0; cy: 0; rx: 34; ry: 34; fade: 1; color: Theme.fade(Theme.crimson, 0.4) }
        Rectangle { x: -3; y: -3; width: 6; height: 6; radius: 3; color: Theme.ember }
    }

    component Mod: Column {
        property string label
        property string value
        property real v
        width: 44
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: parent.label; color: Theme.ash; font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 1.8 }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 3; bottomPadding: 6; text: parent.value; color: Theme.bone; font.family: Theme.goth; font.pixelSize: 26 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 28; height: 2; color: Theme.wine
            Rectangle { width: parent.width * Math.min(1, parent.parent.v); height: 2; color: Theme.rose }
        }
    }
}
