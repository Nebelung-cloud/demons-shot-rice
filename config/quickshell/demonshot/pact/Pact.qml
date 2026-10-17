import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs
import qs.components

// vpn-договор (Super+P) — «safe conduct» из concept.html: охранная грамота свитком.
// Всё из Clash Verge: тумблеры, режим, заставы и пинг — это пункты его же трея, жмём их как рукой (verge остаётся в курсе);
// профиль — из его profiles.yaml; трафик и соединения — с сокета его ядра (mihomo).
// Печать = туннель: стоит, пока горит System proxy или TUN. Сломал — оба гаснут, договор void; поставил — вернулись те, что были.
// Открытие: свёрнутый свиток падает, нижний валик раскатывает бумагу, строки проступают за ним. Печать уже на месте;
// поставил — носитель расписывается кровью и шлёпается сургуч, сломал — печать раскалывается, штамп void
PanelWindow {
    id: root

    // ---- verge: трей ----
    readonly property var verge: SystemTray.items.values.find(i => i.title === "clash-verge" || i.id.includes("clash-verge")) ?? null
    // ponytail: пункты трея ищем по английским подписям (language: en в verge); другой язык — поменять строки тут
    function child(op, pre) { return op.children.values.find(e => e.text.startsWith(pre)) ?? null; }
    function lit(op, pre) { return child(op, pre)?.checkState === Qt.Checked; }
    QsMenuOpener { id: top; menu: root.verge?.menu ?? null }
    QsMenuOpener { id: modes; menu: root.child(top, "Outbound Modes") }
    QsMenuOpener { id: proxies; menu: root.child(top, "Proxies") }
    QsMenuOpener { id: grp; menu: proxies.children.values.find(e => e.hasChildren) ?? null }

    readonly property bool sys: lit(top, "System Proxy")
    readonly property bool tun: lit(top, "TUN Mode")
    readonly property var modeNames: ["Rule", "Global", "Direct"]
    readonly property int mode: modeNames.findIndex(m => lit(modes, m))
    readonly property string group: (proxies.children.values.find(e => e.hasChildren)?.text ?? "proxy").toLowerCase()

    // застава из пункта трея «TCP PL 🇵🇱⚡️-NODE🐸   | 48ms»: код страны из флага, имя без транспорта и эмодзи, пинг
    readonly property var transports: ["tcp", "xhttp", "ws", "grpc", "h2", "http", "httpupgrade", "splithttp", "quic", "kcp", "reality", "hy2", "tuic"]
    readonly property var builtin: ({ DIRECT: ["Direct", "bare road"], REJECT: ["Reject", "closed road"] })
    function way(e) {
        const m = /^(.*?)\s*\|\s*(\S*?)\s*ms$/.exec(e.text), label = (m?.[1] ?? e.text).trim(), b = builtin[label];
        const flag = [...label].map(c => c.codePointAt(0)).filter(c => c >= 0x1F1E6 && c <= 0x1F1FF).map(c => String.fromCharCode(c - 0x1F1E6 + 65)).join("");
        const words = label.replace(/[^\x20-\x7E]/g, " ").split(/[\s\-_|·]+/).filter(Boolean);
        const cc = b ? "—" : flag || words.find(w => /^[A-Z]{2}$/.test(w)) || "··";
        const via = words.find(w => transports.includes(w.toLowerCase()))?.toLowerCase();
        const name = words.filter(w => w !== cc && !transports.includes(w.toLowerCase())).map(w => w[0] + w.slice(1).toLowerCase()).join(" ");
        return {
            entry: e, cc, on: e.checkState === Qt.Checked,
            name: b ? b[0] : name || label,
            sub: b ? b[1] : [via, ...(kinds[label] ?? [])].filter(Boolean).join(" · "),
            ms: b ? 0 : parseInt(m?.[2])
        };
    }
    readonly property var ways: grp.children.values.filter(e => !e.isSeparator && e.buttonType !== QsMenuButtonType.None).map(e => way(e))

    // нажать пункт трея; несколько — по очереди: verge после каждого пересобирает меню
    property var queue: []
    function press(label) {
        queue = queue.concat([label]);
        if (!presser.running) presser.start();
    }
    Timer {
        id: presser
        interval: 350
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const [l, ...rest] = root.queue;
            root.queue = rest;
            root.child(top, l)?.triggered();
            if (!rest.length) stop();
        }
    }
    function go(i) { const w = ways[i]; if (w && !w.on) w.entry.triggered(); }
    function route(i) { child(modes, modeNames[i])?.triggered(); }
    property bool pinging: false
    function ping() { child(grp, "Test Latency")?.triggered(); pinging = true; pingT.restart(); }
    Timer { id: pingT; interval: 2500; onTriggered: root.pinging = false }

    // ---- печать ----
    readonly property bool bound: sys || tun
    property var kept: ["System Proxy", "TUN Mode"] // что вернуть, когда печать снова поставят
    property int want: -1                           // пока verge не догнал: 1 — ставим, 0 — ломаем
    readonly property bool sealed: want >= 0 ? want === 1 : bound
    onBoundChanged: want = -1
    Timer { id: wantT; interval: 5000; onTriggered: root.want = -1 } // verge промолчал — показываем как есть
    function seal() {
        if (!verge) return Quickshell.execDetached(["clash-verge"]); // дом спит — разбудить
        if (sealed) {
            kept = [sys && "System Proxy", tun && "TUN Mode"].filter(Boolean);
            kept.forEach(l => press(l));
            want = 0;
        } else {
            (kept.length ? kept : ["System Proxy", "TUN Mode"]).forEach(l => press(l));
            want = 1;
        }
        wantT.restart();
    }
    property date signedAt: new Date()
    onSealedChanged: {
        if (sealed) signedAt = new Date();
        if (!shown) return settle();
        sealed ? signIt() : breakIt();
    }
    // без анимации: свиток свёрнут — печать и подпись просто в нужном виде
    function settle() {
        signSeq.stop();
        ink = 1;
        drip = 1;
        waxOn = sealed;
        voidMark.opacity = sealed ? 0 : 0.9;
        voidMark.scale = 1;
    }
    Component.onCompleted: settle()

    // ---- verge: профиль (bearer, откуда, когда обновлён, сколько потрачено) ----
    readonly property string home: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/io.github.clash-verge-rev.clash-verge-rev"
    property var deed: ({})
    FileView {
        path: root.home + "/profiles.yaml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.deed = root.parseDeed(text())
    }
    // ponytail: yaml читаем регэкспами — profiles.yaml пишет verge, формат у него плоский
    function parseDeed(t) {
        const cur = /^current: *(\S+)/m.exec(t)?.[1], b = t.split(/\n- /).find(s => s.startsWith(`uid: ${cur}`)) ?? "";
        const f = k => new RegExp(`^ +${k}: *(.*)$`, "m").exec(b)?.[1]?.trim() ?? "";
        return { name: f("name"), host: /\/\/([^/:]+)/.exec(f("url"))?.[1] ?? "local", updated: +f("updated"), spent: +f("upload") + +f("download"), total: +f("total") };
    }
    function bytes(n) {
        const u = ["b", "kb", "mb", "gb", "tb", "pb"];
        let i = 0;
        while (n >= 1024 && i < 5) { n /= 1024; i++; }
        return `${n.toFixed(i > 2 ? 2 : 0)} ${u[i]}`;
    }
    function when(d) { return `${Theme.roman(d.getDate()).toLowerCase()} · ${Theme.roman(d.getMonth() + 1).toLowerCase()} · ${Qt.formatTime(d, "hh:mm")}`; }

    // ---- verge: ядро. Сокет сервиса verge или его собственный, секрет — из конфига verge; $0 — путь API ----
    readonly property string core: `d='${home}'; s=/run/clash-verge-service/users/$(id -u)/verge-mihomo.sock; [ -S "$s" ] || s="$d/verge-mihomo.sock"; `
        + `exec curl -sfN --unix-socket "$s" -H "Authorization: Bearer $(sed -n 's/^secret: *//p' "$d/config.yaml")" "http://core$0"`

    // пошлина: скорость раз в секунду, последние 10 минут — копится всегда, чтобы график не начинался с нуля
    property var toll: []
    property real up: 0
    property real down: 0
    Process {
        id: traffic
        running: true
        command: ["sh", "-c", root.core, "/traffic"]
        stdout: SplitParser {
            onRead: l => {
                try {
                    const j = JSON.parse(l);
                    root.up = j.up;
                    root.down = j.down;
                    root.toll = root.toll.slice(-599).concat([[j.up, j.down]]);
                } catch (e) {}
            }
        }
        onExited: retry.start() // verge спит — постучимся позже
    }
    Timer { id: retry; interval: 5000; onTriggered: traffic.running = true }

    property int links: 0
    Process {
        id: conns
        command: ["sh", "-c", root.core, "/connections"]
        stdout: StdioCollector { onStreamFinished: { try { root.links = JSON.parse(text).connections?.length ?? 0; } catch (e) {} } }
    }
    Timer { running: root.visible; interval: 2000; repeat: true; triggeredOnStart: true; onTriggered: conns.running = true }

    // протокол застав (vless · xudp) — только у ядра, в трее его нет
    property var kinds: ({})
    Process {
        id: kindsP
        command: ["sh", "-c", root.core, "/proxies"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text).proxies, k = {};
                    for (const n in p) k[n] = [p[n].type.toLowerCase(), p[n].xudp && "xudp"].filter(Boolean);
                    root.kinds = k;
                } catch (e) {}
            }
        }
    }

    // две кривые по 60 точек (10 с на точку): входящая чернилами, исходящая Rose. Свиток закрыт — не считаем:
    // пошлина копится каждую секунду, а кривые никто не видит
    readonly property var lines: {
        if (!root.visible) return [[], []];
        const s = Array(Math.max(0, 600 - toll.length)).fill([0, 0]).concat(toll), up = [], dn = [];
        let max = 1;
        for (let i = 0; i < 60; i++) {
            let a = 0, b = 0;
            for (let j = i * 10; j < i * 10 + 10; j++) { a += s[j][0]; b += s[j][1]; }
            up.push(a / 10); dn.push(b / 10);
            max = Math.max(max, a / 10, b / 10);
        }
        const pt = (v, i) => Qt.point(i * 592 / 59, 54 - v / max * 50);
        return [up.map(pt), dn.map(pt)];
    }
    function speed(b) { const k = b / 1024; return k >= 1000 ? [(k / 1024).toFixed(1), "mb/s"] : [k.toFixed(1), "kb/s"]; }

    // ---- открытие / закрытие ----
    property int cur: 0       // курсор клавиатуры по заставам
    property real drop: 0     // свёрнутый свиток падает: 0…1
    property real unroll: 0   // нижний валик едет вниз: 0…1 (чуть больше — дёргается на излёте)
    property real ink: 1      // подпись носителя: 0…1
    property real drip: 1     // капля с пера
    property bool waxOn: false // сургуч на бумаге
    property real crack: 0    // осколки сломанной печати
    property real sway: 0     // ленты качаются от удара
    property bool shown: false // раскрыт, печать ведёт себя вживую
    readonly property real rodY: 34 + 944 * unroll // верх нижнего валика
    readonly property real reveal: rodY - 18       // сколько бумаги раскатано

    // строка проступает, когда валик прошёл под ней: y — от верха текста
    function inked(y, span) { return Math.max(0, Math.min(1, (reveal - 62 - y - 10) / (span ?? 120))); }

    function open() {
        leave.stop();
        visible = true;
        cur = Math.max(0, ways.findIndex(w => w.on));
        list.positionViewAtIndex(cur, ListView.Contain);
        kindsP.running = true;
        stage.forceActiveFocus();
        enter.restart();
    }
    function close() { if (visible && !leave.running) { enter.stop(); leave.restart(); } }
    function toggle() { visible && !leave.running ? close() : open(); }

    function signIt() {
        voidOut.restart();
        ink = 0;
        drip = 0;
        signSeq.restart();
    }
    function breakIt() {
        signSeq.stop();
        ink = 1;
        if (waxOn) { waxOn = false; crackAnim.restart(); quake.restart(); }
        voidIn.restart();
    }

    SequentialAnimation {
        id: enter
        ScriptAction {
            script: {
                root.shown = false; root.drop = 0; root.unroll = 0; root.crack = 0;
                root.settle();
            }
        }
        NumberAnimation { target: root; property: "drop"; to: 1; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
        NumberAnimation { target: root; property: "unroll"; to: 1.025; duration: 950; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0.1, 0.2, 1, 1, 1] }
        NumberAnimation { target: root; property: "unroll"; to: 1; duration: 220; easing.type: Easing.InOutSine }
        ScriptAction { script: root.shown = true }
    }
    SequentialAnimation {
        id: leave
        ScriptAction { script: { root.shown = false; signSeq.stop(); } }
        NumberAnimation { target: root; property: "unroll"; to: 0; duration: 420; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "drop"; to: 0; duration: 220; easing.type: Easing.InQuad }
        ScriptAction { script: root.visible = false }
    }
    // носитель расписывается кровью, с пера срывается капля, когда подпись высохла — сургуч
    SequentialAnimation {
        id: signSeq
        PauseAnimation { duration: 120 }
        NumberAnimation { target: root; property: "ink"; to: 1; duration: 1100; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0.1, 0.5, 1, 1, 1] }
        NumberAnimation { target: root; property: "drip"; to: 1; duration: 260; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 180 }
        ScriptAction { script: { root.waxOn = true; quake.restart(); } }
    }
    // удар печати: свиток вздрагивает, по бумаге волна, ленты качаются
    ParallelAnimation {
        id: quake
        SequentialAnimation {
            NumberAnimation { target: shake; property: "y"; to: 7; duration: 60; easing.type: Easing.OutQuad }
            NumberAnimation { target: shake; property: "y"; to: -3; duration: 110; easing.type: Easing.InOutSine }
            NumberAnimation { target: shake; property: "y"; to: 0; duration: 160; easing.type: Easing.OutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "sway"; to: 18; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "sway"; to: -9; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "sway"; to: 4; duration: 240; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "sway"; to: 0; duration: 280; easing.type: Easing.InOutSine }
        }
        NumberAnimation { target: wave; property: "t"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
    }
    NumberAnimation { id: crackAnim; target: root; property: "crack"; from: 0; to: 1; duration: 620; easing.type: Easing.InQuad }
    ParallelAnimation {
        id: voidIn
        NumberAnimation { target: voidMark; property: "scale"; from: 1.9; to: 1; duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
        NumberAnimation { target: voidMark; property: "opacity"; from: 0; to: 0.9; duration: 200 }
    }
    NumberAnimation { id: voidOut; target: voidMark; property: "opacity"; to: 0; duration: 200 }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "demonshot-pact"

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.pit, 0.84)
        opacity: Math.min(1, root.drop * 1.6)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // холст в координатах макета (1920 минус бар), как у меню питания
    Item {
        id: stage
        width: 1856
        height: 1080
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.TopLeft
        y: (root.height - height * scale) / 2
        focus: true

        Keys.onPressed: e => {
            const n = root.ways.length;
            if ([Qt.Key_Up, Qt.Key_K].includes(e.key) && n) root.cur = (root.cur + n - 1) % n;
            else if ([Qt.Key_Down, Qt.Key_J].includes(e.key) && n) root.cur = (root.cur + 1) % n;
            else if ([Qt.Key_Return, Qt.Key_Enter].includes(e.key)) root.go(root.cur);
            else if (e.key === Qt.Key_S) root.seal();
            else if (e.key === Qt.Key_T) root.ping();
            else if (e.key === Qt.Key_Tab) root.route((root.mode + 1) % 3);
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            list.positionViewAtIndex(root.cur, ListView.Contain);
            e.accepted = true;
        }

        // эхо во весь экран: порванный контур
        Outline {
            x: stage.width + 40 - width
            y: 520
            opacity: root.drop
            text: "Pactum"
            font { family: Theme.frak; pixelSize: 300 }
            color: Theme.fade(Theme.bone, 0.08)
            stroke: 1
            layer.enabled: true
            layer.effect: Glitch {}
        }
        Text {
            x: 86
            y: 70
            opacity: root.drop
            text: "let it slide · get loose · can't stop"
            color: Theme.rose
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 4.4 }
        }
        Text {
            anchors { right: parent.right; rightMargin: 60; bottom: parent.bottom; bottomMargin: 44 }
            opacity: root.drop
            textFormat: Text.StyledText
            text: [["↑↓", "застава"], ["⏎", "ехать"], ["s", "печать"], ["t", "пинг"], ["tab", "режим"], ["esc", "свернуть"]]
                .map(([k, v]) => `<font color="${Theme.bone}">${k}</font> ${v}`).join(" · ")
            color: Theme.ash
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 3; capitalization: Font.AllUppercase }
        }

        // ---- свиток 740×1080: валики сверху и снизу, бумага между ними ----
        Item {
            id: scroll
            x: 558
            width: 740
            height: 1080
            y: -260 * (1 - root.drop)
            opacity: Math.min(1, root.drop * 2)
            scale: 1 + 0.08 * (1 - root.drop)
            transformOrigin: Item.Top
            transform: Translate { id: shake }

            MouseArea { anchors.fill: parent } // клик по свитку не закрывает

            RectangularShadow { y: 34; width: 740; height: root.reveal; blur: 90; offset.y: 40; color: Qt.rgba(0, 0, 0, 0.8) }
            // бумага раскатана до нижнего валика
            Item {
                id: paper
                y: 34
                width: 740
                height: root.reveal
                clip: true

                // запас ниже рамки: на излёте валик проскакивает дальше
                Rectangle { width: 740; height: 1000; color: Theme.pg }
                Shape {
                    width: 740
                    height: 960
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: RadialGradient {
                            centerX: 370; centerY: 480; centerRadius: 620
                            focalX: 370; focalY: 480
                            GradientStop { position: 0.7; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                        }
                        PathRectangle { width: 740; height: 960 }
                    }
                }
                // тень от валиков на бумаге
                Rectangle { width: 740; height: 14; gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.3) } GradientStop { position: 1; color: "transparent" } } }
                Rectangle { y: 946; width: 740; height: 14; gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.3) } } }

                // рамка набора: двойная линейка с отступом от валиков, в углах — ромб-заклёпка, как на навершиях валиков
                Shape {
                    width: 740
                    height: 960
                    ShapePath {
                        strokeColor: Theme.frame
                        strokeWidth: 1
                        fillColor: "transparent"
                        PathSvg {
                            path: [0, 3].map(o => {
                                const a = 26.5 + o, b = 38.5 + o, c = 713.5 - o, d = 921.5 - o, g = 8.5 - o; // линии упираются в грани ромба
                                return `M${a + g} ${b} H${c - g} M${c} ${b + g} V${d - g} M${c - g} ${d} H${a + g} M${a} ${d - g} V${b + g}`;
                            }).join(" ")
                        }
                    }
                }
                Repeater {
                    model: [[28, 40], [712, 40], [712, 920], [28, 920]]
                    Item {
                        required property var modelData
                        x: modelData[0]
                        y: modelData[1]
                        Rectangle { x: -6; y: -6; width: 12; height: 12; rotation: 45; color: Theme.crimson; border { width: 1; color: Theme.mix(Theme.crimson, Theme.void_, 0.45) } }
                        Rectangle { x: -1.5; y: -1.5; width: 3; height: 3; rotation: 45; color: Theme.bone }
                    }
                }

                Column {
                    x: 74
                    y: 62
                    width: 592

                    Text {
                        width: parent.width
                        opacity: root.inked(y)
                        horizontalAlignment: Text.AlignHCenter
                        text: `contract of passage · ${Theme.roman(13)}`.toUpperCase()
                        color: Theme.rose
                        font { family: Theme.goth; pixelSize: 15; letterSpacing: 7.5 }
                    }
                    // заголовок с буквицей: S фрактурой Crimson с костяной тенью, впечатывается, когда валик проходит
                    Item {
                        id: title
                        opacity: root.inked(y)
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: rest.x + rest.implicitWidth
                        height: rest.implicitHeight + 4
                        Text {
                            id: rest
                            x: cap.implicitWidth - 3
                            y: 4
                            text: "afe conduct"
                            color: Theme.bone
                            font { family: Theme.goth; pixelSize: 80; weight: Font.Black; letterSpacing: -2 }
                        }
                        Item {
                            width: cap.implicitWidth
                            height: cap.implicitHeight
                            scale: 1 + 0.9 * Math.pow(1 - title.opacity, 2)
                            Text { x: -4; y: cap.y + 4; text: cap.text; color: Theme.bone; font: cap.font }
                            Text {
                                id: cap
                                y: rest.y + rest.baselineOffset - baselineOffset + 10
                                text: "S"
                                color: Theme.crimson
                                font { family: Theme.frak; pixelSize: 112; bold: true }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        topPadding: 8
                        bottomPadding: 12
                        opacity: root.inked(y)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.verge ? "signed in blood, the bearer passes unseen" : "the house is silent · clash verge sleeps"
                        color: root.verge ? Theme.rose : Theme.ash
                        font { family: Theme.goth; pixelSize: 19 }
                    }
                    Grid {
                        opacity: root.inked(y)
                        columns: 2
                        columnSpacing: 40
                        Book.Kv { width: 276; k: "bearer"; v: root.deed.name ?? "—" }
                        Book.Kv { width: 276; k: "issued"; v: root.deed.host ?? "—" }
                        Book.Kv { width: 276; k: "renewed"; v: root.deed.updated ? root.when(new Date(root.deed.updated * 1000)) : "—" }
                        Book.Kv { width: 276; k: "spent"; v: `${root.bytes(root.deed.spent ?? 0)} of ${root.deed.total ? root.bytes(root.deed.total) : "∞"}` }
                    }

                    Book.Sec { opacity: root.inked(y); text: "Manner"; sub: "how the road is taken" }
                    Row {
                        opacity: root.inked(y)
                        spacing: 40
                        Book.Line { width: 276; text: "System"; sub: "proxy"; Book.Seal { on: root.sys; onToggled: root.press("System Proxy") } }
                        Book.Line { width: 276; text: "Tunnel"; sub: "tun"; Book.Seal { on: root.tun; onToggled: root.press("TUN Mode") } }
                    }
                    Book.Line {
                        opacity: root.inked(y)
                        text: "Route"
                        sub: "clash mode"
                        Book.Pick { opts: root.modeNames.map(m => m.toLowerCase()); cur: root.mode; onPicked: i => root.route(i) }
                    }

                    Book.Sec { opacity: root.inked(y); text: "Waystations"; sub: `group · ${root.group}` }
                    // ponytail: больше пяти застав — список листается, свиток не растёт
                    ListView {
                        id: list
                        opacity: root.inked(y)
                        x: -40
                        width: 632
                        height: Math.min(count, 5) * 36
                        clip: true
                        interactive: count > 5
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.ways.length // по числу: делегаты живут, крест на полях успевает впечататься
                        delegate: Item {
                            id: row
                            required property int index
                            readonly property var w: root.ways[index] ?? {}
                            width: 632
                            height: 36
                            Book.Opt {
                                x: 40
                                width: 592
                                lead: row.w.cc ?? ""
                                text: row.w.name ?? ""
                                sub: row.w.sub ?? ""
                                on: !!row.w.on
                                hot: row.index === root.cur
                                onClicked: { root.cur = row.index; root.go(row.index); }
                                Row {
                                    spacing: 4
                                    Text {
                                        id: msv
                                        anchors.baseline: msu.baseline
                                        text: root.pinging && !(row.w.ms === 0) ? "···" : isNaN(row.w.ms) ? "—" : row.w.ms
                                        color: row.w.ms > 100 ? Theme.crimson : row.w.on ? Theme.bone : Theme.ink
                                        font { family: Theme.goth; pixelSize: 21 }
                                        SequentialAnimation on opacity {
                                            running: root.pinging
                                            loops: Animation.Infinite
                                            onStopped: msv.opacity = 1
                                            NumberAnimation { to: 0.3; duration: 300 }
                                            NumberAnimation { to: 1; duration: 300 }
                                        }
                                    }
                                    Book.Small { id: msu; text: "ms" }
                                }
                            }
                        }
                    }

                    Book.Sec { opacity: root.inked(y); text: "Toll"; sub: `last ${Theme.roman(10).toLowerCase()} minutes` }
                    // кривые прочерчиваются пером слева направо вслед за валиком
                    Item {
                        width: 592
                        height: 66
                        opacity: Math.min(1, root.inked(y) * 3)
                        Item {
                            y: 10
                            width: 592 * root.inked(parent.y, 240)
                            height: 56
                            clip: true
                            Shape {
                                width: 592
                                height: 56
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeColor: Theme.ash
                                    strokeWidth: 1
                                    strokeStyle: ShapePath.DashLine
                                    dashPattern: [2, 4]
                                    fillColor: "transparent"
                                    startX: 0; startY: 55
                                    PathLine { x: 592; y: 55 }
                                }
                                ShapePath {
                                    strokeColor: Theme.ink
                                    strokeWidth: 1.5
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.RoundJoin
                                    PathPolyline { path: root.lines[1] }
                                }
                                ShapePath {
                                    strokeColor: Theme.rose
                                    strokeWidth: 1.5
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.RoundJoin
                                    PathPolyline { path: root.lines[0] }
                                }
                            }
                        }
                    }
                    Item {
                        width: 592
                        height: 66
                        opacity: root.inked(y)
                        Speed { y: 10; arrow: "↑"; v: root.speed(root.up)[0]; unit: `${root.speed(root.up)[1]} · out` }
                        Speed { y: 10; x: (592 - width) / 2; arrow: "↓"; v: root.speed(root.down)[0]; unit: `${root.speed(root.down)[1]} · in` }
                        Speed { y: 10; x: 592 - width; v: root.links; unit: "open links" }
                    }

                    // подписи: дом расписался заранее, место носителя справа; печать ляжет между ними, на ленте у валика
                    Item {
                        width: 592
                        height: 110
                        opacity: root.inked(y)
                        Sig {
                            y: 24
                            hand: "Dæmon"
                            path: "M6 20 C 50 4, 90 30, 130 14 S 180 6, 196 16"
                            label: `the house · ${Theme.roman(13)}`
                        }
                        Sig {
                            id: bearer
                            x: 371
                            y: 24
                            hand: Quickshell.env("USER") || "bearer"
                            path: "M4 24 C 30 8, 60 28, 96 18 S 150 2, 170 14 C 182 22, 160 28, 150 20 S 176 6, 198 10"
                            label: `the bearer · ${root.when(root.signedAt)}`
                            tint: root.sealed ? Theme.crimson : Theme.ash
                            glow: root.sealed
                            ink: root.ink
                            opacity: root.sealed ? 1 : 0.35
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            // капля с пера
                            Rectangle {
                                x: 221 - 34
                                y: 61
                                width: 4
                                height: 9 * root.drip
                                radius: 2
                                color: bearer.tint
                            }
                        }
                        // сломал печать — поверх подписи штамп void
                        Item {
                            id: voidMark
                            x: 371 + 110 - width / 2
                            y: 24 + 32 - height / 2
                            width: vt.implicitWidth + 36
                            height: vt.implicitHeight + 10
                            rotation: -11
                            opacity: 0
                            Rectangle { anchors.fill: parent; anchors.margins: -4; color: "transparent"; border { width: 1; color: Theme.crimson } }
                            Rectangle { anchors.fill: parent; color: "transparent"; border { width: 2; color: Theme.crimson } }
                            Text {
                                id: vt
                                anchors.centerIn: parent
                                text: "VOID"
                                color: Theme.crimson
                                font { family: Theme.goth; pixelSize: 28; weight: Font.Black; letterSpacing: 7 }
                            }
                        }
                    }
                }
            }

            // свёрнутая бумага на нижнем валике: тоньше, чем больше раскатано
            Rectangle {
                y: root.rodY + 16 - height / 2
                width: 740
                height: 32 + 28 * Math.max(0, 1 - root.unroll)
                radius: height / 2
                visible: root.unroll < 1
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.mix(Theme.pg, Theme.void_, 0.6) }
                    GradientStop { position: 0.35; color: Theme.mix(Theme.pg, Theme.bone, 0.08) }
                    GradientStop { position: 1; color: Theme.mix(Theme.pg, Theme.void_, 0.7) }
                }
            }
            // тень от загиба над валиком, пока бумага катится
            Rectangle {
                y: root.rodY - 50
                width: 740
                height: 50
                opacity: Math.max(0, 1 - Math.pow(root.unroll, 6))
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) } }
            }

            Rod { y: 18; spin: 0 }
            Rod { y: root.rodY; spin: root.unroll * 30 } // нижний катится — волокна бегут

            // главная печать висит на лентах у нижнего валика и едет вместе с ним
            Item {
                id: wax
                x: 310
                y: root.rodY - 48
                width: 120
                height: 120

                Rib { x: 32; y: 70; rotation: 14 + root.sway; tint: Theme.crimson }
                Rib { x: 64; y: 70; rotation: -12 - root.sway * 0.8; tint: Theme.mix(Theme.crimson, Theme.void_, 0.3) }

                // волна от удара
                Rectangle {
                    id: wave
                    property real t: 1
                    anchors.centerIn: parent
                    width: 120 + 180 * t
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border { width: 2; color: Theme.crimson }
                    opacity: 0.7 * (1 - t)
                }
                Rectangle { anchors.fill: parent; radius: 60; color: Theme.fade(Theme.void_, 0.6); visible: !root.waxOn }
                Book.Seal { d: 120; on: root.waxOn; onToggled: root.seal() }

                // сломали — две половины разлетаются и падают
                Repeater {
                    model: [-1, 1]
                    Item {
                        required property int modelData
                        visible: root.crack > 0 && root.crack < 1
                        x: modelData < 0 ? 0 : 60
                        width: 60
                        height: 120
                        clip: true
                        opacity: 1 - root.crack
                        transform: [
                            Rotation { origin.x: modelData < 0 ? 60 : 0; origin.y: 60; angle: modelData * 38 * root.crack },
                            Translate { x: modelData * 56 * root.crack; y: 110 * root.crack * root.crack }
                        ]
                        Book.Seal { x: modelData < 0 ? 0 : -60; d: 120; on: true; enabled: false }
                    }
                }
            }
        }
    }

    // валик: точёное дерево цвета вина с бликом, у концов костяные обоймы, на концах гранёные навершия.
    // spin — угол поворота (рад): волокна бегут по кругу, так видно, что валик катится
    component Rod: Item {
        id: rd
        property real spin
        readonly property color dark: Theme.mix(Theme.void_, Theme.wine, 0.25)
        x: -24
        width: 788
        height: 32
        RectangularShadow { x: 8; width: parent.width - 16; height: parent.height; radius: 14; blur: 12; offset.y: 5; color: Qt.rgba(0, 0, 0, 0.35) }
        // тело: торцы спрятаны под обоймами
        Rectangle {
            x: 8
            width: parent.width - 16
            height: parent.height
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: rd.dark }
                GradientStop { position: 0.16; color: Theme.mix(Theme.wine, Theme.bone, 0.22) }
                GradientStop { position: 0.3; color: Theme.mix(Theme.wine, Theme.plum, 0.35) }
                GradientStop { position: 0.62; color: Theme.wine }
                GradientStop { position: 0.88; color: rd.dark }
                GradientStop { position: 1; color: Theme.pit }
            }
            // волокна: точки на окружности, видна только передняя половина
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    readonly property real a: rd.spin + index * 2 * Math.PI / 5
                    visible: Math.cos(a) > 0
                    x: 40 + index * 37
                    y: 16 - 13 * Math.sin(a)
                    width: parent.width - 80 - index * 74
                    height: 1
                    opacity: 0.35 * Math.cos(a)
                    color: Theme.pit
                }
            }
            // блик вдоль верха, к концам гаснет
            Rectangle {
                x: 14
                y: 5
                width: parent.width - 28
                height: 2
                radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.fade(Theme.bone, 0.22) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
        // концы: обойма поверх торца тела, за ней шейка и навершие. Координаты от левого края, правый конец — те же числа от правого
        Repeater {
            model: 2
            Item {
                id: end
                required property int index
                function at(x, w) { return index ? rd.width - x - w : x; }
                anchors.fill: parent
                // обойма: кость, посередине винная жилка
                Rectangle {
                    x: end.at(4, 16)
                    y: -3
                    width: 16
                    height: 38
                    radius: 3
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.mix(Theme.bone, Theme.void_, 0.55) }
                        GradientStop { position: 0.2; color: Theme.bone }
                        GradientStop { position: 0.55; color: Theme.mix(Theme.bone, Theme.ash, 0.45) }
                        GradientStop { position: 1; color: Theme.mix(Theme.bone, Theme.void_, 0.7) }
                    }
                    Rectangle { x: 7; width: 2; height: parent.height; color: Theme.fade(Theme.crimson, 0.85) }
                }
                // шейка: от обоймы заходит под ромб
                Rectangle {
                    x: end.at(-20, 26)
                    y: 10
                    width: 26
                    height: 12
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.mix(Theme.bone, Theme.void_, 0.5) }
                        GradientStop { position: 0.35; color: Theme.mix(Theme.bone, Theme.ash, 0.3) }
                        GradientStop { position: 1; color: Theme.mix(Theme.bone, Theme.void_, 0.75) }
                    }
                }
                // навершие: гранёный ромб, свет сверху слева, в сердце капля Crimson; острие сидит во втулке
                Shape {
                    x: end.at(-46, 36)
                    y: -2
                    width: 36
                    height: 36
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath { strokeWidth: -1; fillColor: Theme.bone; PathPolyline { path: [Qt.point(0, 18), Qt.point(18, 0), Qt.point(18, 18), Qt.point(0, 18)] } }
                    ShapePath { strokeWidth: -1; fillColor: Theme.mix(Theme.bone, Theme.ash, 0.35); PathPolyline { path: [Qt.point(18, 0), Qt.point(36, 18), Qt.point(18, 18), Qt.point(18, 0)] } }
                    ShapePath { strokeWidth: -1; fillColor: Theme.mix(Theme.bone, Theme.void_, 0.6); PathPolyline { path: [Qt.point(36, 18), Qt.point(18, 36), Qt.point(18, 18), Qt.point(36, 18)] } }
                    ShapePath { strokeWidth: -1; fillColor: Theme.mix(Theme.bone, Theme.ash, 0.7); PathPolyline { path: [Qt.point(18, 36), Qt.point(0, 18), Qt.point(18, 18), Qt.point(18, 36)] } }
                    ShapePath {
                        strokeColor: Theme.mix(Theme.bone, Theme.void_, 0.7)
                        strokeWidth: 1
                        fillColor: "transparent"
                        PathPolyline { path: [Qt.point(18, 0.5), Qt.point(35.5, 18), Qt.point(18, 35.5), Qt.point(0.5, 18), Qt.point(18, 0.5)] }
                    }
                    Rectangle { x: 14.5; y: 14.5; width: 7; height: 7; rotation: 45; antialiasing: true; color: Theme.crimson; border { width: 1; color: Theme.mix(Theme.crimson, Theme.void_, 0.5) } }
                    Rectangle { x: 16.5; y: 15.5; width: 2; height: 2; color: Theme.fade(Theme.bone, 0.8) }
                }
                // втулка: охватывает острие ромба и конец шейки
                Rectangle {
                    x: end.at(-14, 7)
                    y: 5
                    width: 7
                    height: 22
                    radius: 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.mix(Theme.bone, Theme.void_, 0.55) }
                        GradientStop { position: 0.2; color: Theme.bone }
                        GradientStop { position: 0.55; color: Theme.mix(Theme.bone, Theme.ash, 0.45) }
                        GradientStop { position: 1; color: Theme.mix(Theme.bone, Theme.void_, 0.7) }
                    }
                }
            }
        }
    }
    // лента под печатью: ласточкин хвост
    component Rib: Shape {
        id: rb
        property color tint
        width: 24
        height: 76
        transformOrigin: Item.Top
        ShapePath {
            strokeWidth: -1
            fillColor: root.waxOn ? rb.tint : Theme.fade(Theme.ash, 0.3)
            PathPolyline { path: [Qt.point(0, 0), Qt.point(24, 0), Qt.point(24, 76), Qt.point(12, 62), Qt.point(0, 76), Qt.point(0, 0)] }
        }
    }
    // скорость: стрелка Rose, число, подпись мелко
    component Speed: Column {
        property string arrow
        property var v
        property string unit
        spacing: 6
        Text {
            textFormat: Text.StyledText
            text: (parent.arrow ? `<font color="${Theme.rose}">${parent.arrow}</font> ` : "") + parent.v
            color: Theme.bone
            font { family: Theme.goth; pixelSize: 30 }
        }
        Book.Small { text: parent.unit }
    }
    // подпись: росчерк от руки над линейкой, ink — сколько уже написано
    component Sig: Item {
        id: sg
        property string hand
        property string path
        property string label
        property color tint: Theme.ink
        property bool glow
        property real ink: 1
        width: 221
        height: 86
        Item {
            y: -14
            width: sg.width * sg.ink
            height: 84
            clip: true
            Text {
                x: (sg.width - implicitWidth) / 2
                anchors.baseline: parent.top
                anchors.baselineOffset: 66
                text: sg.hand
                color: sg.tint
                font { family: Theme.frak; pixelSize: 38; bold: true }
                layer.enabled: sg.glow
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.fade(Theme.crimson, 0.5); shadowBlur: 0.5; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
            }
            Shape {
                y: 50
                width: 200
                height: 30
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { xScale: sg.width / 200 }
                ShapePath {
                    strokeColor: sg.tint
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: sg.path }
                }
            }
        }
        Rectangle { y: 60; width: sg.width; height: 1.5; color: Theme.ink }
        Book.Small { y: 74; anchors.horizontalCenter: parent.horizontalCenter; text: sg.label }
    }
}
