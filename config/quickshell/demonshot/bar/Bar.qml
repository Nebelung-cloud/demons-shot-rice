import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs
import qs.components

// вертикальный бар слева, 64px: D, римские ws, часы столбиком, батарея, профиль, XIII — питание
PanelWindow {
    id: root

    property bool powerOpen: false
    signal powerClicked

    anchors { left: true; top: true; bottom: true }
    implicitWidth: 64
    color: Theme.crypt
    WlrLayershell.namespace: "demonshot-bar"

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    readonly property var bat: UPower.displayDevice

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // раскладка: старт — main-клавиатура из hyprctl, дальше событие activelayout>>kbd,Layout
    property string kbd: ""
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: root.kbd = JSON.parse(this.text).keyboards.find(k => k.main)?.active_keymap ?? "" }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") root.kbd = e.data.slice(e.data.lastIndexOf(",") + 1); }
    }

    // hyprland 0.56 с lua: dispatch принимает lua-выражение, workspace.activate() тут не работает
    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.wine }

    WheelHandler { onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1") }

    ColumnLayout {
        anchors { fill: parent; rightMargin: 1 }
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            topPadding: 10
            bottomPadding: 6
            text: "D"
            font { family: Theme.frak; pixelSize: 40 }
            color: Theme.crimson
        }

        Flourish { Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 10; kind: "scroll" }

        Item {
            Layout.fillWidth: true
            implicitHeight: 6 * 46

            // активный — сплошной Crimson, переезжает со slam
            Rectangle {
                width: parent.width
                height: 46
                y: (root.active - 1) * 46
                visible: root.active >= 1 && root.active <= 6
                color: Theme.crimson
                Behavior on y { NumberAnimation { duration: Theme.hit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }
            }

            Repeater {
                model: 6

                Item {
                    id: ws
                    required property int index
                    readonly property int n: index + 1
                    readonly property var w: Hyprland.workspaces.values.find(w => w.id === n)
                    readonly property bool occ: (w?.toplevels.values.length ?? 0) > 0
                    readonly property bool on: root.active === n

                    y: index * 46
                    width: parent.width
                    height: 46

                    // занятый — штрих Rose слева
                    Rectangle { visible: ws.occ && !ws.on; y: 14; width: 3; height: 18; color: Theme.rose }
                    Text {
                        anchors.centerIn: parent
                        text: Theme.roman(ws.n)
                        font { family: Theme.goth; pixelSize: 20 }
                        color: ws.on || ws.occ ? Theme.bone : Theme.dim
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.go(ws.n) }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Flourish { anchors.centerIn: parent; kind: "rule"; color: Theme.plum }
        }

        Column {
            Layout.fillWidth: true
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatTime(clock.date, "hh")
                font { family: Theme.goth; pixelSize: 30 }
                lineHeight: 0.95
                color: Theme.bone
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatTime(clock.date, "mm")
                font { family: Theme.goth; pixelSize: 30 }
                lineHeight: 0.95
                color: Theme.ash
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 10
                text: Theme.roman(clock.date.getDate()) + "·" + Theme.roman(clock.date.getMonth() + 1)
                font { family: Theme.mono; pixelSize: 9; letterSpacing: 1 }
                color: Theme.ash
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Flourish { anchors.centerIn: parent; kind: "beads"; color: Theme.plum }
        }

        // что-то играет — три полоски эквалайзера: пауза index·0.3 с, подъём и спад по 0.9 с (InOutSine).
        // Свой таймер ~30 кадров/с вместо анимаций: те тикают каждый vsync (120 Гц), и бар перерисовывался
        // 120 раз в секунду всё время, пока играет музыка. ponytail: interval — ручка плавности
        Row {
            id: eq
            property real t: 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 10
            visible: Mpris.players.values.some(p => p.isPlaying)
            height: 14
            spacing: 3

            Timer {
                running: eq.visible
                interval: 33
                repeat: true
                onTriggered: eq.t += interval / 1000
            }
            function ease(x) { return (1 - Math.cos(Math.PI * x)) / 2; }

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real rest: index * 0.3
                    readonly property real u: eq.t % (1.8 + rest) - rest // < 0 — ещё пауза
                    width: 3
                    height: 14
                    color: Theme.rose
                    transform: Scale {
                        origin.y: 14
                        yScale: 0.25 + 0.75 * (u < 0 ? 0 : u < 0.9 ? eq.ease(u / 0.9) : 1 - eq.ease((u - 0.9) / 0.9))
                    }
                }
            }
        }

        Column {
            Layout.fillWidth: true
            topPadding: 7
            bottomPadding: 9
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "KBD"
                font { family: Theme.mono; pixelSize: 9; letterSpacing: 1.8 }
                leftPadding: 1.8
                color: Theme.ash
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 3
                // "English (US)" → EN, "Russian" → RU
                text: root.kbd.slice(0, 2).toUpperCase()
                font { family: Theme.goth; pixelSize: 22 }
                color: Theme.bone
            }
        }

        Mod {
            visible: root.bat.isLaptopBattery
            readonly property bool chg: root.bat.state === UPowerDeviceState.Charging
            label: chg ? "CHG" : "BAT"
            value: Math.round(root.bat.percentage * 100)
            v: root.bat.percentage
            // ниже 15% без зарядки — Crimson
            alert: !chg && root.bat.percentage < 0.15
        }

        // профиль питания (power-profiles-daemon): засечки I·II·III, клик — следующий
        Column {
            id: prof
            readonly property int p: PowerProfiles.profile
            readonly property int n: PowerProfiles.hasPerformanceProfile ? 3 : 2

            Layout.fillWidth: true
            topPadding: 7
            bottomPadding: 12
            spacing: 7

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: ["ECO", "BAL", "MAX"][prof.p]
                font { family: Theme.mono; pixelSize: 9; letterSpacing: 1.8 }
                leftPadding: 1.8
                color: profTap.hovered ? Theme.bone : Theme.ash
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Repeater {
                    model: prof.n
                    Rectangle {
                        required property int index
                        width: 6
                        height: 6 + index * 4
                        anchors.bottom: parent.bottom
                        color: index <= prof.p ? (prof.p === 2 ? Theme.crimson : Theme.rose) : Theme.wine
                        Behavior on color { ColorAnimation { duration: Theme.hit } }
                    }
                }
            }
            HoverHandler { id: profTap; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: PowerProfiles.profile = (prof.p + 1) % prof.n }
        }

        // XIII — меню питания, в рамке из двух арок
        Rectangle {
            id: xiii
            readonly property bool lit: root.powerOpen || pwr.containsMouse
            readonly property color ink: lit ? Theme.bone : Theme.crimson

            Layout.fillWidth: true
            Layout.topMargin: 8
            implicitHeight: 78
            color: lit ? Theme.crimson : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.hit } }

            Rectangle { width: parent.width; height: 1; color: Theme.wine }
            Flourish { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 9 } kind: "swag"; color: xiii.ink }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "XIII"
                font { family: Theme.goth; pixelSize: 20 }
                color: xiii.ink
            }
            Flourish { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 9 } kind: "swag"; flip: true; color: xiii.ink }
            MouseArea { id: pwr; anchors.fill: parent; hoverEnabled: true; onClicked: root.powerClicked() }
        }
    }

    // модуль: метка 9px Ash, цифра готикой, тонкая шкала Rose по Wine
    component Mod: Column {
        property string label
        property string value
        property real v
        property bool alert

        Layout.fillWidth: true
        topPadding: 7
        bottomPadding: 9

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: parent.label
            font { family: Theme.mono; pixelSize: 9; letterSpacing: 1.8 }
            leftPadding: 1.8
            color: Theme.ash
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: 3
            bottomPadding: 6
            text: parent.value
            font { family: Theme.goth; pixelSize: 22 }
            color: parent.alert ? Theme.crimson : Theme.bone
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 28
            height: 2
            color: Theme.wine
            Rectangle { width: parent.width * Math.min(1, parent.parent.v); height: 2; color: parent.parent.alert ? Theme.crimson : Theme.rose }
        }
    }
}
