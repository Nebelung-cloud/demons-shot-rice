import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.settings
import "../components/arcana.js" as Arcana

// уведомления — знамения, вытянутые из колоды. справа снизу, свежее — у угла.
// слева корешок с арканом приложения (как в лаунчере); карта влетает переворотом, уходит — сгорая обратно.
// снизу тлеет фитиль таймаута, искра ползёт к аркану; наведение — пауза и карта выдвигается из колоды.
// старые бледнеют вглубь. критические всегда тянут Башню: Crimson, рамка дышит, заголовок рвётся, сами не гаснут
PanelWindow {
    id: root

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => { if (!Rules.store.dnd || n.urgency === NotificationUrgency.Critical) n.tracked = true; }
    }

    property int lift: 0 // открыт угол оберегов — колода встаёт над ним
    readonly property int count: server.trackedNotifications.values.length

    visible: count > 0
    anchors { bottom: true; right: true }
    margins { bottom: 14 + lift; right: 14 }
    implicitWidth: 400
    implicitHeight: col.height + 20
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "demonshot-notifications"

    Column {
        id: col
        x: 10
        y: 10
        width: 380
        spacing: 8

        // сама модель, не массив: иначе Repeater пересоздаёт все плитки и анимация входа играет заново
        Repeater {
            model: server.trackedNotifications

            Item {
                id: tile
                required property var modelData
                required property int index
                readonly property var n: modelData
                readonly property bool crit: n.urgency === NotificationUrgency.Critical
                readonly property color accent: crit ? Theme.crimson : Theme.rose
                readonly property var arc: crit ? Arcana.major(16) : Arcana.forApp(n.desktopEntry || "", n.appName || "", "")
                readonly property int depth: root.count - 1 - index
                property real s: 420     // сдвиг вправо
                property real flip: -80  // поворот по Y
                property real life: 1
                property real pulse: 1
                property real tear: 0
                property real seed: 13
                property var after: null
                property real lift: hover.hovered ? -8 : 0
                Behavior on lift { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }

                // в колоде видно noteDeck (house rules · Notices), остальные ждут скрытыми
                visible: depth < Rules.store.noteDeck
                width: col.width
                height: Math.max(body.height + 30, 76)
                opacity: (1 - s / 420) * (1 - depth * 0.7 / Rules.store.noteDeck)
                transform: [
                    Rotation { origin.x: tile.width; origin.y: tile.height / 2; axis { x: 0; y: 1; z: 0 } angle: tile.flip; distanceToPlane: 700 },
                    Translate { x: tile.s + tile.lift }
                ]

                // сжечь и уйти: та же дорога обратно, потом f (expire/dismiss)
                function burn(f) {
                    if (out.running) return;
                    after = f;
                    out.start();
                }

                ParallelAnimation {
                    running: true
                    NumberAnimation { target: tile; property: "s"; to: 0; duration: Theme.hit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                    NumberAnimation { target: tile; property: "flip"; to: 0; duration: Theme.hit + 160; easing.type: Easing.OutBack }
                }
                SequentialAnimation {
                    id: out
                    ParallelAnimation {
                        NumberAnimation { target: tile; property: "s"; to: 420; duration: 240; easing.type: Easing.InBack }
                        NumberAnimation { target: tile; property: "flip"; to: 80; duration: 240; easing.type: Easing.InQuad }
                    }
                    ScriptAction { script: tile.after() }
                }

                // таймаут: фитиль life тлеет до нуля, потом карта сгорает. Своего таймаута нет и noteTime 0 — ждёт, пока не смахнут
                NumberAnimation on life {
                    running: !tile.crit && (tile.n.expireTimeout > 0 || Rules.store.noteTime > 0)
                    paused: running && hover.hovered
                    from: 1; to: 0
                    duration: tile.n.expireTimeout > 0 ? tile.n.expireTimeout : Rules.store.noteTime * 1000
                    onFinished: tile.burn(() => tile.n.expire())
                }

                // Башня: рамка дышит, заголовок время от времени рвётся
                SequentialAnimation on pulse {
                    running: tile.crit
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
                NumberAnimation on tear { id: rip; running: false; from: 9; to: 0; duration: 320; easing.type: Easing.OutQuad }
                Timer {
                    running: tile.crit && tile.visible
                    interval: 2400
                    repeat: true
                    onTriggered: { tile.seed = Math.random() * 100; rip.restart(); }
                }

                HoverHandler { id: hover }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => {
                        const def = tile.n.actions.find(a => a.identifier === "default");
                        if (e.button === Qt.LeftButton && def) def.invoke(); else tile.burn(() => tile.n.dismiss());
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: tile.crit ? Qt.darker(Theme.plum, 1.4) : Theme.crypt
                    border {
                        width: 1
                        color: tile.crit ? Qt.rgba(Theme.crimson.r, Theme.crimson.g, Theme.crimson.b, tile.pulse)
                                         : hover.hovered ? Theme.plum : Theme.wine
                    }
                }

                // корешок: номер аркана сверху, иконка снизу, шов акцента справа
                Rectangle {
                    id: spine
                    x: 1
                    y: 1
                    width: 44
                    height: parent.height - 2
                    color: tile.crit ? Theme.crimson : Theme.void_

                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 7 }
                        width: 38
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.arc.num
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 11
                        font { family: Theme.goth; pixelSize: 22 }
                        color: tile.crit ? Theme.bone : tile.accent
                    }
                    Flourish {
                        anchors.centerIn: parent
                        kind: "beads"
                        k: 0.8
                        rotation: 90
                        color: tile.crit ? Theme.bone : Theme.plum
                        visible: tile.height > 92
                    }
                    TintIcon {
                        id: icon
                        visible: ok
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 9 }
                        size: 18
                        name: tile.n.appIcon || tile.n.desktopEntry
                        color: tile.crit ? Theme.bone : Theme.ash
                    }
                    Text {
                        visible: !icon.ok
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 7 }
                        text: ["sigil", "moon"].includes(tile.arc.glyph) ? "\u{F0AE2}" : tile.arc.glyph
                        font { family: Theme.mono; pixelSize: 18 }
                        color: tile.crit ? Theme.bone : Theme.ash
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: tile.accent
                    }
                }

                // фитиль: тлеет справа налево, искра идёт к корешку; наведение прижимает её
                Item {
                    visible: !tile.crit
                    x: spine.width + 1
                    y: parent.height - 3
                    width: parent.width - x - 1
                    height: 2

                    Rectangle { anchors.fill: parent; color: Theme.wine }
                    Rectangle { width: parent.width * tile.life; height: 2; color: Theme.plum }
                    Glow {
                        cx: parent.width * tile.life
                        cy: 1
                        rx: 16
                        ry: 7
                        color: Theme.rose
                        opacity: hover.hovered ? 0.25 : 1
                        SequentialAnimation on scale {
                            running: tile.visible && !tile.crit // карты глубже колоды и Башня искры не показывают
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.7; duration: 110 }
                            NumberAnimation { to: 1.1; duration: 170 }
                            NumberAnimation { to: 0.9; duration: 90 }
                        }
                    }
                    Rectangle {
                        x: parent.width * tile.life - 2
                        y: -1
                        width: 4
                        height: 4
                        radius: 2
                        color: hover.hovered ? Theme.ash : Theme.blush
                    }
                }

                // картинка уведомления (аватар, обложка) — справа, в рамке
                Rectangle {
                    id: pic
                    visible: img.status === Image.Ready
                    x: parent.width - width - 12
                    y: 12
                    width: 52
                    height: 52
                    color: "transparent"
                    border { width: 1; color: tile.crit ? Theme.crimson : Theme.plum }
                    Image {
                        id: img
                        anchors { fill: parent; margins: 2 }
                        source: tile.n.image
                        fillMode: Image.PreserveAspectCrop
                        sourceSize { width: 96; height: 96 }
                    }
                }

                Column {
                    id: body
                    x: spine.width + 14
                    y: 12
                    width: parent.width - x - 14 - (pic.visible ? pic.width + 12 : 0)
                    spacing: 3

                    Row {
                        spacing: 6
                        Text {
                            anchors.baseline: name.baseline
                            text: (tile.n.appName || "omen").toUpperCase()
                            font { family: Theme.mono; pixelSize: 10; letterSpacing: 2.2; weight: Font.Bold }
                            color: tile.accent
                        }
                        Text {
                            id: name
                            text: "· " + tile.arc.name.toLowerCase()
                            font { family: Theme.goth; pixelSize: 14 }
                            color: Theme.ash
                        }
                    }
                    Text {
                        width: parent.width
                        text: tile.n.summary || "can't"
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font { family: Theme.goth; pixelSize: 21 }
                        lineHeight: 0.95
                        color: Theme.blush
                        layer.enabled: tile.crit
                        layer.effect: Glitch {
                            amount: tile.tear
                            seed: tile.seed
                            freq: Qt.vector2d(0.03, 0.14)
                        }
                    }
                    Flourish {
                        visible: tile.n.body !== ""
                        kind: "rule"
                        k: 0.8
                        color: tile.crit ? Theme.crimson : Theme.plum
                    }
                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: tile.n.body
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        font { family: Theme.mono; pixelSize: 11 }
                        color: Theme.ash
                        linkColor: Theme.rose
                    }
                    Row {
                        visible: actions.count > 0
                        topPadding: 6
                        spacing: 6
                        Repeater {
                            id: actions
                            model: tile.n.actions.filter(a => a.identifier !== "default")
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: label.width + 20
                                height: 24
                                color: act.containsMouse ? Theme.plum : "transparent"
                                border { width: 1; color: act.containsMouse ? tile.accent : Theme.wine }
                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: Theme.roman(parent.index + 1).toLowerCase() + " · " + parent.modelData.text
                                    font { family: Theme.goth; pixelSize: 14 }
                                    color: act.containsMouse ? Theme.blush : Theme.ash
                                }
                                MouseArea { id: act; anchors.fill: parent; hoverEnabled: true; onClicked: parent.modelData.invoke() }
                            }
                        }
                    }
                }
            }
        }
    }
}
