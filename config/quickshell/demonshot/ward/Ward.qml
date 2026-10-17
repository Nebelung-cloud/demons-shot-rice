import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.settings

// обереги — угол справа снизу, как utilities у caelestia: горячий угол (курсор в самый угол) или Super+N.
// Четверть астролябии: обод с делениями, по ободу печати-тумблеры (wi-fi, bluetooth, голос, тишина, игра, vpn, правила дома),
// каллиграфический росчерк с завитками отделяет их от поля со свечами: клик — все зажглись (система не засыпает) или все задуты.
// Уходит, когда курсор покинул круг, по Esc или Super+N
Scope {
    id: root

    signal settingsRequested

    // ponytail: рисуется в 400×400, k — ручка масштаба всего угла
    readonly property real k: 1
    readonly property int size: Math.round(400 * k)

    property bool open: false
    property bool byKey: false
    property real t: open ? 1 : 0 // раскрытие 0…1: всё рисуется от него
    Behavior on t { NumberAnimation { duration: root.open ? 620 : 260; easing.type: root.open ? Easing.OutCubic : Easing.InCubic } }

    function show(key) {
        if (open) return;
        byKey = key;
        open = true;
        vpnPoll.running = true;
        stage.forceActiveFocus();
        if (!key) grace.restart();
    }
    function close() { open = false; }
    function toggle() { open ? close() : show(true); }

    // ---- печати ----
    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.mic] }

    property bool game: false
    onGameChanged: {
        if (game) Rules.hypr(`hl.config({ animations = { enabled = false }, general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true }, `
                           + `decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } } })`);
        else { Rules.windows(); Rules.motion(); Rules.hypr("hl.config({ general = { allow_tearing = false } })"); }
    }

    // первый vpn/wireguard-профиль nmcli; нет такого — нет и печати
    property var vpn: null // { name, on }
    Process {
        id: vpnPoll
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "con", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = text.split("\n").map(l => l.replace(/\\:/g, "\x01").split(":").map(x => x.replace(/\x01/g, ":")))
                    .find(f => f[1] === "vpn" || f[1] === "wireguard");
                root.vpn = c ? { name: c[0], on: !!c[2] } : null;
            }
        }
    }
    Process { id: vpnAct; onExited: vpnPoll.running = true }

    readonly property var seals: [
        { id: "wifi", name: "Wi-Fi", icon: "\u{F05A9}" },
        { id: "bt", name: "Bluetooth", icon: "\u{F00AF}" },
        { id: "mic", name: "Voice", icon: "\u{F036C}" },
        { id: "dnd", name: "Silence", icon: "\u{F009B}" },
        { id: "game", name: "Game", icon: "\u{F0297}" }
    ].concat(vpn ? [{ id: "vpn", name: "VPN", icon: "\u{F0582}" }] : [],
             [{ id: "rules", name: "House rules", icon: "\u{F0493}" }])

    function isOn(id) {
        switch (id) {
        case "wifi": return Networking.wifiEnabled;
        case "bt": return Bluetooth.defaultAdapter?.enabled ?? false;
        case "mic": return !(mic?.audio?.muted ?? true);
        case "dnd": return Rules.store.dnd;
        case "game": return game;
        case "vpn": return vpn?.on ?? false;
        }
        return false;
    }
    function flip(id) {
        switch (id) {
        case "wifi": Networking.wifiEnabled = !Networking.wifiEnabled; break;
        case "bt": { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled; break; }
        case "mic": if (mic?.audio) mic.audio.muted = !mic.audio.muted; break;
        case "dnd": Rules.store.dnd = !Rules.store.dnd; break;
        case "game": game = !game; break;
        case "vpn": vpnAct.exec(["nmcli", "con", vpn.on ? "down" : "up", "id", vpn.name]); vpn = { name: vpn.name, on: !vpn.on }; break;
        case "rules": close(); settingsRequested(); break;
        }
    }

    // ---- свеча: не спать (idle inhibit). Ингибитору нужно живое окно — невидимое 0×0, как у caelestia ----
    property bool vigil: false
    IdleInhibitor {
        enabled: root.vigil
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "demonshot-vigil"
            mask: Region {}
        }
    }

    // ---- росчерк: средняя линия (завиток · дуга r300 · завиток) → многоугольник с нажимом, толще в середине ----
    function curl(p, d, n, rho, turns) {
        const s = Math.sign(d[0] * n[1] - d[1] * n[0]), o = [p[0] + n[0] * rho, p[1] + n[1] * rho], out = [];
        for (let i = 1; i <= 36; i++) {
            const a = s * turns * 2 * Math.PI * i / 36, r = rho * (1 - 0.72 * i / 36);
            out.push([o[0] + r * (-n[0] * Math.cos(a) + n[1] * Math.sin(a)), o[1] + r * (-n[0] * Math.sin(a) - n[1] * Math.cos(a))]);
        }
        return out;
    }
    readonly property var spine: {
        const R = 300, u = th => [Math.cos(th), Math.sin(th)], P = th => [400 + R * Math.cos(th), 400 + R * Math.sin(th)];
        const a0 = 188 * Math.PI / 180, a1 = 262 * Math.PI / 180, arc = [];
        for (let i = 0; i <= 74; i++) arc.push(P(a0 + (a1 - a0) * i / 74));
        // касательная по ходу дуги (-sin, cos), нормаль к центру угла (-cos, -sin)
        const A = curl(P(a0), [Math.sin(a0), -Math.cos(a0)], u(a0).map(x => -x), 12, 0.9).reverse();
        const B = curl(P(a1), [-Math.sin(a1), Math.cos(a1)], u(a1).map(x => -x), 12, 0.9);
        return A.concat(arc, B);
    }
    function swash(frac) {
        const L = spine, n = Math.max(2, Math.ceil(L.length * frac)), l = [], r = [];
        for (let i = 0; i < n; i++) {
            const p = L[Math.max(0, i - 1)], q = L[Math.min(L.length - 1, i + 1)];
            const dx = q[0] - p[0], dy = q[1] - p[1], len = Math.hypot(dx, dy) || 1;
            const w = (0.5 + 3.6 * Math.pow(Math.sin(Math.PI * i / (L.length - 1)), 1.6)) / 2;
            l.push(`${L[i][0] - dy / len * w} ${L[i][1] + dx / len * w}`);
            r.push(`${L[i][0] + dy / len * w} ${L[i][1] - dx / len * w}`);
        }
        return `M${l.join(" L")} L${r.reverse().join(" L")} Z`;
    }

    // ---- горячий угол: курсор в самый угол экрана ----
    PanelWindow {
        anchors { bottom: true; right: true }
        implicitWidth: 6
        implicitHeight: 6
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "demonshot-ward-corner"
        // курсор в углу — тоже «внутри»: окно угла может лежать поверх круга, и тогда круг не видит курсора
        MouseArea { id: corner; anchors.fill: parent; hoverEnabled: true; onEntered: dwell.restart(); onExited: { dwell.stop(); if (root.open) leave.restart(); } }
    }
    Timer { id: dwell; interval: 120; onTriggered: root.show(false) }

    PanelWindow {
        id: win

        visible: root.t > 0
        anchors { bottom: true; right: true }
        implicitWidth: root.size
        implicitHeight: root.size
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open && root.byKey ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "demonshot-ward"
        // мышь ловит только четверть круга, угол квадрата за ней — насквозь
        mask: Region { width: win.width * 2; height: win.height * 2; shape: RegionShape.Ellipse }

        Item {
            id: stage
            anchors { right: parent.right; bottom: parent.bottom }
            width: 400
            height: 400
            scale: root.k
            transformOrigin: Item.BottomRight
            focus: true
            Keys.onEscapePressed: root.close()

            // вышел из круга — уйти (через миг: дрогнувшая рука не закрывает)
            HoverHandler { id: inside; onHoveredChanged: hovered ? leave.stop() : leave.restart() }
            Timer { id: leave; interval: 350; onTriggered: if (!inside.hovered && !corner.containsMouse) root.close() }
            // с угла открыли, а курсор так и не зашёл в круг — не висеть
            Timer { id: grace; interval: 1500; onTriggered: if (!inside.hovered && !corner.containsMouse) root.close() }

            // фон: обод Crypt, поле Void — круги растут из угла
            Disc { r: 398 * root.t; color: Theme.crypt }
            Disc { r: 300 * root.t; color: Theme.void_ }

            // обод: двойная линия, прорисовывается по дуге, между линиями деления через 2.5°
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                Rim { rr: 392; strokeColor: Theme.wine }
                Rim { rr: 382; strokeColor: Theme.plum }
                Rim { rr: 312; strokeColor: Theme.wine; strokeStyle: ShapePath.DashLine; dashPattern: [1, 4] }
            }
            Repeater {
                model: 37
                Item {
                    required property int index
                    x: 400
                    y: 400
                    rotation: 180 + index * 2.5
                    visible: index / 36 <= root.t
                    Rectangle {
                        x: index % 6 ? 385 : 383
                        width: index % 6 ? 4 : 9
                        height: 1
                        color: index % 6 ? Theme.wine : Theme.rose
                    }
                }
            }

            // росчерк ведётся пером: многоугольник растёт по ходу t
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.rose
                    fillRule: ShapePath.WindingFill
                    PathSvg { path: root.swash(Math.min(1, root.t * 1.15)) }
                }
                // волосная линия-эхо над росчерком
                ShapePath {
                    strokeColor: Theme.plum
                    strokeWidth: 0.8
                    fillColor: "transparent"
                    PathAngleArc { centerX: 400; centerY: 400; radiusX: 291; radiusY: 291; startAngle: 197; sweepAngle: 56 * Math.max(0, root.t * 1.3 - 0.3) }
                }
            }
            // ромб и две бусины в середине росчерка
            Item {
                x: 400 - 300 * Math.SQRT1_2
                y: 400 - 300 * Math.SQRT1_2
                opacity: root.t > 0.55 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                Rectangle { x: -5; y: -5; width: 10; height: 10; rotation: 45; color: Theme.crimson }
                Rectangle { x: -1.5; y: -1.5; width: 3; height: 3; rotation: 45; color: Theme.bone }
                Repeater {
                    model: [-7, 7]
                    Rectangle {
                        required property real modelData
                        readonly property real a: (225 + modelData) * Math.PI / 180
                        x: 400 + 300 * Math.cos(a) - parent.x - 2
                        y: 400 + 300 * Math.sin(a) - parent.y - 2
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.rose
                    }
                }
            }

            // поле — свечи на полке, высокие к углу, низкие к краю круга. Клик по полю: зажечь все / задуть все.
            // Горят — система не засыпает (бдение)
            Item {
                anchors.fill: parent
                opacity: Math.max(0, root.t * 2.5 - 1.5)

                // отсвет от свечей
                Shape {
                    anchors.fill: parent
                    opacity: root.vigil ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 900 } }
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: RadialGradient {
                            centerX: 310; centerY: 250; centerRadius: 210
                            focalX: 310; focalY: 250
                            GradientStop { position: 0; color: Qt.alpha(Theme.rose, 0.22) }
                            GradientStop { position: 0.5; color: Qt.alpha(Theme.crimson, 0.07) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        PathSvg { path: "M100 400 A300 300 0 0 1 400 100 V400 Z" }
                    }
                }

                // полка: свечи стоят на ней, а не висят над линией
                Rectangle { x: 100; y: 386; width: 300; height: 14; color: Theme.crypt }
                Rectangle { x: 100; y: 386; width: 300; height: 1; color: Theme.wine }

                // [от правого края до оси, высота воска, толщина, натёк]
                Repeater {
                    model: [[56, 168, 30, 0.4], [100, 118, 24, 0.6], [150, 132, 30, 0.35], [200, 66, 22, 0.7], [238, 34, 18, 0.5]]
                    Candle {
                        required property var modelData
                        required property int index
                        x: 400 - modelData[0] - width / 2
                        y: 386 - height
                        h: modelData[1]
                        w: modelData[2]
                        drip: modelData[3]
                        phase: index
                        lit: root.vigil
                    }
                }

                // клик и рука-курсор — только внутри поля (r < 296), печати лежат сверху
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    readonly property bool inField: Math.hypot(400 - mouseX, 400 - mouseY) < 296
                    cursorShape: inField ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (inField) root.vigil = !root.vigil
                }
            }

            // печати по ободу: между 192° и 258°, у каждой римский номер снаружи
            Repeater {
                model: root.seals

                Item {
                    id: seal
                    required property var modelData
                    required property int index
                    readonly property real a: (192 + 66 * index / Math.max(1, root.seals.length - 1)) * Math.PI / 180
                    readonly property bool on: root.isOn(modelData.id)
                    readonly property bool lit: on || tap.hovered
                    property real kick: 1

                    x: 400 + 340 * Math.cos(a) - 22
                    y: 400 + 340 * Math.sin(a) - 22
                    width: 44
                    height: 44
                    scale: root.t > 0.3 + index * 0.08 ? (tap.hovered ? 1.08 : 1) : 0
                    transform: Scale { origin.x: 22; origin.y: 22; xScale: seal.kick; yScale: seal.kick }
                    Behavior on scale { NumberAnimation { duration: Theme.hit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }

                    // внешнее кольцо пунктиром; сломанная печать (вкл) медленно вращается
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: seal.on ? Theme.crimson : Theme.wine
                            strokeWidth: 1
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [2, 2.6]
                            fillColor: "transparent"
                            PathAngleArc { centerX: 22; centerY: 22; radiusX: 21; radiusY: 21; startAngle: 0; sweepAngle: 360 }
                        }
                        RotationAnimation on rotation { running: seal.on && win.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 14000 }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        radius: 17
                        color: seal.on ? Theme.crimson : Theme.void_
                        border.color: seal.on ? Theme.crimson : seal.lit ? Theme.rose : Theme.wine
                        Behavior on color { ColorAnimation { duration: Theme.hit } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: seal.modelData.icon
                        font { family: Theme.mono; pixelSize: 16 }
                        color: seal.on ? Theme.bone : seal.lit ? Theme.rose : Theme.ash
                    }
                    // номер снаружи, по радиусу
                    Text {
                        x: 22 + 34 * Math.cos(seal.a) - width / 2
                        y: 22 + 34 * Math.sin(seal.a) - height / 2
                        text: Theme.roman(seal.index + 1)
                        font { family: Theme.goth; pixelSize: 10 }
                        color: seal.on ? Theme.crimson : Theme.dim
                    }

                    NumberAnimation on kick { id: punch; running: false; from: 0.78; to: 1; duration: Theme.hit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                    HoverHandler { id: tap; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { punch.restart(); root.flip(seal.modelData.id); } }
                }
            }

        }
    }

    // круг с центром в углу: окно обрезает его до четверти
    component Disc: Rectangle {
        property real r
        x: 400 - r
        y: 400 - r
        width: 2 * r
        height: 2 * r
        radius: r
    }
    component Rim: ShapePath {
        property real rr
        strokeWidth: 1
        fillColor: "transparent"
        PathAngleArc { centerX: 400; centerY: 400; radiusX: rr; radiusY: rr; startAngle: 180; sweepAngle: 90 * root.t }
    }
    // свеча: воск с натёками и лункой, лужица; над ним фитиль, пламя (дрожит в своём ритме phase) и ореол —
    // нарисованы под толщину 12 и масштабируются вместе со свечой. Задули — от фитиля тает дымок
    component Candle: Item {
        id: c
        property real h: 30
        property real w: 12
        property real drip: 0.4  // натёк: доля высоты
        property bool lit: true
        property int phase: 0
        readonly property real s: w / 12
        readonly property color wax: Theme.bone
        readonly property color shade: Qt.darker(Theme.bone, 1.18)

        width: w + 12
        height: h + 26 * s

        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: c.h
            // тело, теневой бок справа — цилиндр; натёки свисают через край, видны по силуэту; сверху лунка
            Rectangle { x: 6; width: c.w; height: c.h; color: c.wax }
            Rectangle { x: 6 + c.w * 0.72; width: c.w * 0.28; height: c.h; color: c.shade }
            Rectangle { x: 4.5; width: c.w * 0.24; height: c.h * c.drip; radius: width / 2; color: c.wax }
            Rectangle { x: 7.5 + c.w * 0.78; width: c.w * 0.22; height: c.h * c.drip * 0.6; radius: width / 2; color: c.shade }
            Rectangle { x: 6; width: c.w; height: Math.max(2, c.w * 0.12); color: Qt.darker(c.wax, 1.3) } // лунка
        }

        Item {
            x: c.width / 2 - 5
            y: c.height - c.h - 26
            width: 10
            height: 26
            scale: c.s
            transformOrigin: Item.Bottom

            Rectangle { x: -9; y: -1; width: 28; height: 28; radius: 14; color: Theme.rose; opacity: c.lit ? 0.16 : 0; Behavior on opacity { NumberAnimation { duration: 500 } } }
            Rectangle { x: 4.5; y: 20; width: 1; height: 6; color: c.lit ? Theme.ash : Theme.dim }
            Shape {
                y: 6
                width: 10
                height: 14
                opacity: c.lit ? 1 : 0
                scale: c.lit ? 1 : 0.3
                Behavior on opacity { NumberAnimation { duration: 260 } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Bottom
                ShapePath { strokeWidth: -1; fillColor: Theme.crimson; PathSvg { path: "M5 0 C6.7 4.4 10 7 10 9.6 A5 4.4 0 0 1 0 9.6 C0 7 3.3 4.4 5 0 Z" } }
                ShapePath { strokeWidth: -1; fillColor: Theme.rose; PathSvg { path: "M5 3.5 C6.2 6.4 8.4 8 8.4 10 A3.4 3.4 0 0 1 1.6 10 C1.6 8 3.8 6.4 5 3.5 Z" } }
                ShapePath { strokeWidth: -1; fillColor: Theme.bone; PathSvg { path: "M5 7 C5.8 8.6 6.9 9.4 6.9 10.8 A1.9 1.9 0 0 1 3.1 10.8 C3.1 9.4 4.2 8.6 5 7 Z" } }
                SequentialAnimation on rotation {
                    running: c.lit && root.open
                    loops: Animation.Infinite
                    NumberAnimation { to: 5; duration: 700 + c.phase * 70; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -4; duration: 900 + c.phase * 55; easing.type: Easing.InOutSine }
                }
                // дрожь — по высоте, а не масштабом: scale занят зажиганием
                transform: Scale {
                    origin.x: 5; origin.y: 14
                    SequentialAnimation on yScale {
                        running: c.lit && root.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.82; duration: 190 + c.phase * 23; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.08; duration: 330 + c.phase * 41; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.93; duration: 160 + c.phase * 17; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 270 + c.phase * 29; easing.type: Easing.InOutSine }
                    }
                }
            }

            Shape {
                id: smoke
                width: 10
                height: 20
                opacity: 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.ash
                    strokeWidth: 0.8
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: "M5 20 C1 15 9 12 5 7 C2 3 7 0 5 -6" }
                }
                ParallelAnimation {
                    id: puff
                    NumberAnimation { target: smoke; property: "opacity"; from: 0.8; to: 0; duration: 2200; easing.type: Easing.InQuad }
                    NumberAnimation { target: smoke; property: "y"; from: 0; to: -16; duration: 2200; easing.type: Easing.OutCubic }
                }
            }
        }
        onLitChanged: if (!lit && root.open) puff.restart()
    }
}
