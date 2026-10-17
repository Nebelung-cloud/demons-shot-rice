import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.settings

// меню питания: P3R, отзеркаленное. Слева карта-«персона», справа лесенка пунктов,
// выбранный — чёрная фрактура на Crimson-плашке с костяной тенью. ↑↓ гоняют плашку со slam
PanelWindow {
    id: root

    property int sel: 4

    // пункт: подпись, части надписи [вид, текст] (f — фрактура, m — моно Rose), стиль строки в лесенке,
    // отступ до следующего [обычный, если следующий выбран], аркан, смысл, что делает, строка на плашке, команда
    readonly property var items: [
        { label: "Lock", parts: [["f", "L"], ["", "ock"]], right: 200, size: 86, rot: -3, tone: 1, gap: [110, 150],
          num: "II", name: "The Priestess", icon: "󰌾", q: "Keep the secret.", what: "блокировка экрана", lyr: "still right before your eyes",
          deco: [{ k: "x", top: 8, right: 130, size: 54, rot: 8 }],
          cmd: ["loginctl", "lock-session"] },
        { label: "Log out", parts: [["", "Log"], ["m", "out"]], right: 120, size: 60, rot: 2, tone: 0.62, gap: [62, 100],
          num: "0", name: "The Fool", icon: "󰍃", q: "Step off the edge.", what: "выход из сеанса", lyr: "get loose",
          deco: [{ k: "o", top: 8, right: 420 }, { k: "ln", top: 62, right: 90, w: 380, h: 2, rot: -4, op: 0.7 }],
          dispatch: "hl.dsp.exit()" },
        { label: "Suspend", parts: [["f", "S"], ["", "uspend"]], right: 230, size: 80, rot: -1, tone: 1, gap: [104, 140],
          num: "XVIII", name: "The Moon", moon: true, q: "Sleep, don't dream.", what: "сон", lyr: "let it slide",
          deco: [{ k: "x", top: 14, right: 130, size: 30, op: 0.6 }],
          cmd: ["systemctl", "suspend"] },
        { label: "Hibernate", parts: [["", "Hiber"], ["f", "n"], ["", "ate"]], right: 150, size: 54, rot: 3, tone: 0.62, gap: [68, 76],
          num: "XII", name: "The Hanged Man", icon: "󰜗", q: "Hang until dawn.", what: "гибернация", lyr: "frozen till dawn",
          cmd: ["systemctl", "hibernate"] },
        { label: "Shut down", parts: [["f", "S"], ["", "hut down"]], right: 180, size: 78, rot: 2, tone: 1, gap: [100, 140],
          num: "XIII", name: "Death", sigil: true, q: "Every door closes.", what: "завершение сеанса", lyr: "every door closes",
          cmd: ["systemctl", "poweroff"] },
        { label: "Reboot", parts: [["f", "R"], ["", "eboot"]], right: 170, size: 84, rot: -2, tone: 1, gap: [112, 150],
          num: "X", name: "The Wheel", icon: "󰜉", q: "The wheel turns again.", what: "перезагрузка", lyr: "one more round",
          cmd: ["systemctl", "reboot"] },
        { label: "Firmware", parts: [["", "Firm"], ["m", "ware"]], right: 250, size: 54, rot: 1, tone: 0.62, gap: [68, 100],
          num: "XV", name: "The Devil", icon: "󰘚", q: "Down to the cellar.", what: "настройки прошивки", lyr: "down to the cellar",
          deco: [{ k: "x", top: -4, right: 520, size: 40, rot: -10 }, { k: "ln", top: 58, right: 130, w: 320, h: 1, rot: 3 }],
          cmd: ["systemctl", "reboot", "--firmware-setup"] },
        { label: "Cancel", parts: [["f", "C"], ["", "ancel"]], right: 110, size: 76, rot: -2, tone: 0, gap: [0, 0],
          num: "XVII", name: "The Star", icon: "󰫢", q: "Not tonight.", what: "вернуться", lyr: "can't stop" }
    ].filter(it => it.label !== "Hibernate" || Rules.canHibernate)
    readonly property var cur: items[sel]

    // y каждой строки: выбранная занимает 144, соседи расступаются
    readonly property var tops: {
        let y = 96;
        return items.map((it, k) => { const t = y; y += k === sel ? 144 : it.gap[+(k === sel - 1)]; return t; });
    }

    function open() {
        sel = items.findIndex(it => it.label === "Shut down");
        visible = true;
        enter.restart();
        slam.restart();
    }
    function close() { visible = false; }
    function pick(i) {
        sel = (i + items.length) % items.length;
        slam.restart();
    }
    function accept() {
        const it = cur;
        close();
        // DEMONSHOT_DRYRUN=1 — только лог, для отладки во вложенной сессии
        if (Quickshell.env("DEMONSHOT_DRYRUN")) return console.log("power:", it.label);
        if (it.cmd) Quickshell.execDetached(it.cmd);
        if (it.dispatch) Hyprland.dispatch(it.dispatch);
    }

    function html(parts, size) {
        return parts.map(([k, s]) =>
            k === "f" ? `<span style="font-family:'${Theme.frak}'; font-size:${Math.round(size * 1.4)}px; font-weight:700">${s}</span>`
          : k === "m" ? `<span style="font-family:'${Theme.mono}'; font-size:${Math.round(size * 0.5)}px; font-weight:700; color:${Theme.rose}">${s}</span>`
          : s).join("");
    }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "demonshot-power"

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Theme.fade(Theme.pit, 0.84)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // холст в координатах макета (1920 минус бар) — масштабируется под экран
    Item {
        id: stage
        width: 1856
        height: 1080
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.TopLeft
        y: (root.height - height * scale) / 2
        focus: true

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up || e.key === Qt.Key_K) root.pick(root.sel - 1);
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab) root.pick(root.sel + 1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.accept();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        // косой луч света
        Rectangle { x: 636; y: -300; width: 520; height: 1700; rotation: 14; color: Theme.fade(Theme.plum, 0.3) }

        // эхо выбранного пункта во весь экран: тонкий контур, порванный
        Outline {
            x: stage.width + 80 - width
            y: 250
            rotation: 7
            text: root.cur.label
            font { family: Theme.frak; pixelSize: 330 }
            color: Theme.fade(Theme.bone, 0.09)
            stroke: 1
            layer.enabled: true
            layer.effect: Glitch {}
        }

        // «персона»
        Card {
            id: card
            x: 426
            y: 190
            scale: 1.6
            rotation: -9
            transformOrigin: Item.TopLeft
            up: true
            seed: root.sel
            num: root.cur.num
            name: root.cur.name
            raysY: 0.5 // одна иконка — по центру сцены

            ArcanaArt { glyph: root.cur.sigil ? "sigil" : root.cur.moon ? "moon" : root.cur.icon ?? "" }

            NumberAnimation on x {
                id: enter
                from: -500; to: 426
                duration: 380
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
            }
        }

        Column {
            x: 86
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            spacing: 8
            Text { text: root.cur.q; color: Theme.bone; font.family: Theme.goth; font.pixelSize: 34 }
            Text {
                text: `${root.cur.num} · ${root.cur.name} — ${root.cur.what}`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                color: Theme.ash
            }
        }

        Lyr { y: 100; rightGap: 440; text: "let inhibitions slide" }
        Lyr { y: 896; rightGap: 300; text: "13 shots · can't slow down"; color: Theme.ash }
        Ring { y: 884; x: stage.width - 240 - width; opacity: 0.6 }

        // лесенка
        Repeater {
            model: root.items

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: index === root.sel

                width: stage.width
                y: root.tops[index]
                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }

                GlitchText {
                    x: stage.width - row.modelData.right - width
                    y: -row.modelData.size * 0.25 // в концепте line-height .8
                    rotation: row.modelData.rot
                    opacity: row.on ? 0 : 1 // выбранный рисует плашка
                    strength: 9
                    freq: Qt.vector2d(0.03, 0.12)
                    textFormat: Text.RichText
                    text: root.html(row.modelData.parts, row.modelData.size)
                    font { family: Theme.goth; pixelSize: row.modelData.size; weight: Font.Black }
                    color: row.modelData.tone === 0 ? Theme.ash : Theme.fade(Theme.bone, row.modelData.tone)
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea { anchors.fill: parent; onClicked: row.on ? root.accept() : root.pick(row.index) }
                }

                Repeater {
                    model: row.modelData.deco ?? []
                    Item {
                        required property var modelData
                        readonly property var d: modelData
                        Text {
                            visible: d.k === "x"
                            x: stage.width - d.right - width
                            y: d.top
                            rotation: d.rot ?? 0
                            opacity: d.op ?? 1
                            text: "☾"
                            font { family: Theme.goth; pixelSize: d.size ?? 40 }
                            color: Theme.bone
                        }
                        Ring { visible: d.k === "o"; x: stage.width - d.right - width; y: d.top }
                        Rectangle {
                            visible: d.k === "ln"
                            x: stage.width - d.right - width
                            y: d.top
                            width: d.w ?? 0
                            height: d.h ?? 1
                            rotation: d.rot ?? 0
                            transformOrigin: Item.Left
                            opacity: d.op ?? 1
                            color: Theme.bone
                        }
                    }
                }
            }
        }

        // плашка выбора: костяная подложка, Crimson-клин с острым концом влево, чёрная фрактура
        Item {
            id: hl
            // сдвиг для slam: клин и надпись, подложка — отдельно, на 50ms позже
            property real s1: 0
            property real s2: 0

            width: stage.width
            y: root.tops[root.sel]

            Blade { color: Theme.bone; dx: 22; dy: 14; shift: hl.s2 }
            Blade { color: Theme.crimson; shift: hl.s1 }

            Item {
                id: selItem
                x: stage.width - 190 - selText.width + hl.s1
                y: (106 - height) / 2 // в концепте line-height 1, а у UnifrakturCook строка 1.31em
                opacity: 1 - hl.s1 / 160
                width: selText.width
                height: selText.height
                rotation: 7
                transformOrigin: Item.Right

                GlitchText {
                    x: -6; y: 6
                    strength: 9
                    freq: Qt.vector2d(0.03, 0.12)
                    text: root.cur.label
                    font: selText.font
                    color: Theme.bone
                }
                GlitchText {
                    id: selText
                    strength: 9
                    freq: Qt.vector2d(0.03, 0.12)
                    text: root.cur.label
                    font { family: Theme.frak; pixelSize: 106; letterSpacing: -3 }
                    color: Theme.void_
                }
                MouseArea { anchors.fill: parent; onClicked: root.accept() }
            }

            Lyr { y: 88; rightGap: 120; rotation: 7; text: root.cur.lyr; color: Theme.void_ }

            // влетает справа на каждый выбор
            ParallelAnimation {
                id: slam
                NumberAnimation { target: hl; property: "s1"; from: 160; to: 0; duration: Theme.hit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                SequentialAnimation {
                    PropertyAction { target: hl; property: "s2"; value: 160 }
                    PauseAnimation { duration: 50 }
                    NumberAnimation { target: hl; property: "s2"; to: 0; duration: Theme.hit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                }
            }
        }

        Text {
            anchors { right: parent.right; rightMargin: 60; bottom: parent.bottom; bottomMargin: 44 }
            textFormat: Text.StyledText
            text: `<font color="${Theme.bone}">↑↓</font> ВЫБОР · <font color="${Theme.bone}">⏎</font> ПРИНЯТЬ · <font color="${Theme.bone}">ESC</font> ОТМЕНА`
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 3 }
            color: Theme.ash
        }
    }

    component Lyr: Text {
        property int rightGap
        x: stage.width - rightGap - width
        font { family: Theme.mono; pixelSize: 11; letterSpacing: 4.4 }
        color: Theme.rose
    }

    component Ring: Rectangle {
        width: 34; height: 34; radius: 17
        color: "transparent"
        border { width: 1.5; color: Theme.bone }
        Text { anchors.centerIn: parent; text: "☾"; color: Theme.bone; font.family: Theme.goth; font.pixelSize: 22 }
    }

    // клин 840×104, наклон 7° вокруг правого края
    component Blade: Shape {
        id: blade
        property color color
        property real dx: 0
        property real dy: 0
        property real shift: 0 // для slam
        x: stage.width - 30 - width + dx + shift
        opacity: 1 - shift / 160
        y: 8 + dy
        width: 840
        height: 104
        rotation: 7
        transformOrigin: Item.Right
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: blade.color
            strokeWidth: -1
            PathPolyline { path: [Qt.point(0, 64.5), Qt.point(117.6, 4.2), Qt.point(840, 0), Qt.point(823.2, 104), Qt.point(92.4, 104), Qt.point(0, 64.5)] }
        }
    }
}
