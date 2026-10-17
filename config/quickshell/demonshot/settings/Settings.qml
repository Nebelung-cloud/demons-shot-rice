import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// house rules (Super+I или Settings в лаунчере) — гримуар, как «Вариант · книга» в concept.html:
// раздел = глава, слева фронтиспис с арканом, справа правила; ←→ или клик по краю листа листают, пройденные вкладки уезжают на левый обрез.
// Всё применяется сразу и живёт в ~/.config/demonshot/rules.json (Rules). Сеть, bluetooth и звук — живое состояние
// (nmcli, bluez, pipewire), в файл не пишутся
PanelWindow {
    id: root

    property int sel: 0
    readonly property var rules: Rules.store

    // глава: имя, подпись, иконка, аркан, имя карты, смысл, по-русски, строчка клипа, страница, вводный абзац
    readonly property var sections: [
        { name: "Network", sub: "wi-fi · vpn", icon: "\u{F0928}", num: "XVII", card: "The Star", q: "Signal from afar.", ru: "сеть", lyr: "still right before your eyes", page: "net",
          pr: "Signals come through the walls. Name the ones you trust, give them the word, and the rest stay outside." },
        { name: "Bluetooth", sub: "paired", icon: "\u{F00AF}", num: "VI", card: "The Lovers", q: "Pair the hearts.", ru: "bluetooth", lyr: "never drink alone", page: "bt",
          pr: "Bonds made through the air. Keep the trusted ones close; strangers wait at the door until you call them by name." },
        { name: "Sound", sub: "out · in · apps", icon: "\u{F057E}", num: "XIV", card: "Temperance", q: "Mix it right.", ru: "звук", lyr: "let it slide", page: "snd",
          pr: "Every voice in the house runs through one mixer. Pour each one right, and gag the ones that talk too much." },
        { name: "Display", sub: "scale · light · windows", icon: "\u{F0379}", num: "XIX", card: "The Sun", q: "Let there be light.", ru: "экран", lyr: "losing your precious pride", page: "disp",
          pr: "Light, scale and the space between windows. Keep the edges sharp and the glow low." },
        { name: "Colors", sub: "palettes · paint over", icon: "\u{F03D8}", num: "III", card: "The Empress", q: "Paint it red.", ru: "цвета", lyr: "can't slow down", page: "col",
          pr: "One deck of colors for the whole house. Choose it, and every window, the bar and this very book take the paint at once." },
        { name: "Input", sub: "keys · touchpad", icon: "\u{F030C}", num: "I", card: "The Magician", q: "Quick hands.", ru: "ввод", lyr: "get loose", page: "inp",
          pr: "How fast the hands are answered. Tune the keys and the glass under your fingers until they obey without a thought." },
        { name: "Idle", sub: "lock · dpms · sleep", icon: "\u{F04B2}", num: "XII", card: "The Hanged Man", q: "Wait it out.", ru: "простой", lyr: "a perfect compromise to freedom", page: "idle",
          pr: "When nobody moves, the house waits. Then it bars the door, puts out the light and falls asleep." },
        { name: "Notices", sub: "do not disturb", icon: "\u{F009A}", num: "XX", card: "Judgement", q: "Hear the call.", ru: "уведомления", lyr: "can't can't can't", page: "note",
          pr: "Omens come drawn from the deck. Say how long each one burns, how many lie open, and when the house keeps silent." },
        { name: "System", sub: "about · time · shell", icon: "\u{F0493}", num: "IV", card: "The Emperor", q: "Set the house rules.", ru: "система", lyr: "xiii shots", page: "sys",
          pr: "What the machine is, what it waits for, and how it counts the hours." }
    ]
    readonly property var cur: sections[sel]

    function open() {
        visible = true;
        stage.forceActiveFocus();
        err = "";
        settle();
        refresh();
        enter.restart();
    }
    function close() { visible = false; pick = ""; }
    function toggle() { visible ? close() : open(); }

    // ---- листание: лист с двумя сторонами вертится вокруг корешка ----
    // вперёд: справа сразу новая глава, лист несёт уходящую правую страницу и на обороте — новую левую; назад — зеркально
    property int shownL: 0  // что лежит на левой странице
    property int shownR: 0  // что лежит на правой
    property int from: 0    // глава, с которой листаем
    property bool fwd: true
    property real flip: 0   // ход листа 0→1
    function turn(k) {
        k = Math.max(0, Math.min(sections.length - 1, k)); // ponytail: книга не закольцована — с последней главы дальше некуда
        if (leafAnim.running) { leafAnim.stop(); settle(); } // лист ещё в полёте — дожимаем его сразу
        if (k === sel) return;
        from = sel;
        fwd = k > sel;
        sel = k;
        pick = "";
        if (fwd) shownR = k; else shownL = k;
        leafAnim.restart();
        stage.forceActiveFocus();
    }
    function settle() { shownL = sel; shownR = sel; }
    NumberAnimation {
        id: leafAnim
        target: root
        property: "flip"
        from: 0
        to: 1
        duration: 750
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.35, 0.05, 0.2, 1, 1, 1]
        onFinished: root.settle()
    }

    // цвета книги тянутся от палитры, так что колода перекрашивает и её
    readonly property color pg: Theme.pg
    readonly property color ink: Theme.ink
    readonly property color rule: Theme.rule
    readonly property color frame: Theme.frame
    function folio(n) { return `— ${Theme.roman(n).toLowerCase()} —`; }

    // ---- сеть: как в caelestia (services/Nmcli.qml) — события из `nmcli monitor`, сохранённые профили, ошибки nmcli на экран ----
    property bool wifi: false
    property var nets: []      // { ssid, signal, sec, used, known }
    property var tunnels: []   // { name, type, on } — vpn/wireguard переключаются, tun (Mihomo и пр.) только показываем
    property string wifiCon    // имя активного wifi-профиля: бывает «SSID 1», удалять надо по нему, а не по SSID
    property string pick       // выбранная сеть: под ней строка пароля
    property string busy       // что сейчас делает nmcli
    property string err        // последняя ошибка nmcli
    readonly property var joined: nets.find(n => n.used) ?? null

    function parse(text) {
        const out = [], tun = [], saved = [];
        let w = false, con = "";
        for (const line of text.split("\n")) {
            const p = line.split(":");
            if (p[0] === "wifi") w = p[1] === "enabled";
            else if (p[0] === "con") {
                // con:NAME:TYPE:DEVICE — двоеточия в имени nmcli экранирует «\:»
                const f = line.slice(4).replace(/\\:/g, "\x01").split(":").map(x => x.replace(/\x01/g, ":"));
                const [name, type, dev] = f;
                if (type === "802-11-wireless") { saved.push(name); if (dev) con = name; }
                else if (["vpn", "wireguard", "tun"].includes(type) && (dev || type !== "tun")) tun.push({ name, type, on: !!dev });
            } else if (p[0] === "net") {
                // net:IN-USE:SIGNAL:SECURITY:SSID — SSID последним, чтобы двоеточия в нём ничего не ломали
                const ssid = p.slice(4).join(":").replace(/\\:/g, ":");
                if (!ssid) continue;
                const n = { ssid, signal: +p[2], sec: p[3], used: p[1] === "*" };
                const i = out.findIndex(o => o.ssid === ssid); // одна строка на SSID: активная, иначе самая сильная точка
                if (i < 0) out.push(n);
                else if (n.used || (!out[i].used && n.signal > out[i].signal)) out[i] = n;
            }
        }
        // ponytail: «известна» = профиль с именем SSID или «SSID N»; профиль с другим именем просто спросит пароль
        for (const n of out) n.known = saved.some(s => s === n.ssid || s.startsWith(n.ssid + " "));
        wifi = w;
        wifiCon = con;
        tunnels = tun;
        nets = w ? out.sort((x, y) => y.used - x.used || y.signal - x.signal) : [];
    }
    function nm(what, cmd) {
        if (act.running) return;
        busy = what;
        err = "";
        act.command = ["nmcli"].concat(cmd);
        act.running = true;
    }
    function join(n, password) {
        pick = "";
        nm(`connecting · ${n.ssid}`, ["dev", "wifi", "connect", n.ssid].concat(password ? ["password", password] : []));
    }
    function strength(s) { return s > 75 ? "\u{F0928}" : s > 50 ? "\u{F0925}" : s > 25 ? "\u{F0922}" : "\u{F091F}"; }

    Process {
        id: poll
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["sh", "-c", "echo \"wifi:$(nmcli -t radio wifi)\"; nmcli -t -f NAME,TYPE,DEVICE con show | sed 's/^/con:/'; "
                            + "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list | sed 's/^/net:/'"]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }
    function refresh() { if (!poll.running) poll.running = true; else again.restart(); }
    Timer { id: again; interval: 400; onTriggered: root.refresh() }

    // действие nmcli: ошибку — на экран; «нужен пароль» у защищённой сети — открыть строку пароля
    property string lastSsid
    Process {
        id: act
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: StdioCollector { id: actErr }
        onStarted: root.lastSsid = root.busy.startsWith("connecting") ? root.busy.split(" · ")[1] : ""
        onExited: code => {
            const e = actErr.text.trim().replace(/^Error: /, "");
            root.busy = "";
            if (code !== 0) {
                root.err = e || `nmcli exit ${code}`;
                if (root.lastSsid && /secret|password|802-11-wireless-security/i.test(e)) root.pick = root.lastSsid;
            }
            root.refresh();
        }
    }

    // события NM (подключился, отвалился, радио) — сразу перечитать; живёт, только пока открыта глава
    Process {
        running: root.visible && root.cur.page === "net"
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
    }
    Timer { id: debounce; interval: 300; onTriggered: if (!root.pick) root.refresh() }
    // результаты скана событий не дают — пересканировать раз в 15 с
    Process { id: rescan; command: ["nmcli", "dev", "wifi", "rescan"]; onExited: root.refresh() }
    Timer {
        running: root.visible && root.cur.page === "net" && root.wifi && !root.pick // пока вводят пароль, список не пересобираем
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: rescan.running = true
    }

    // ---- bluetooth: bluez через Quickshell.Bluetooth; ищем, только пока открыта глава ----
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDevs: bt?.devices.values ?? []
    Binding { target: root.bt; property: "discovering"; value: true; when: root.visible && root.cur.page === "bt" && (root.bt?.enabled ?? false) }
    function btIcon(i) {
        return /audio|head/.test(i) ? "\u{F02CB}" : /mouse/.test(i) ? "\u{F037D}" : /keyboard/.test(i) ? "\u{F030C}" : /phone/.test(i) ? "\u{F03F2}" : "\u{F00AF}";
    }

    // ---- звук: pipewire; приложения — потоки воспроизведения ----
    readonly property var audio: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: audio.filter(n => n.isSink && !n.isStream)
    readonly property var sources: audio.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: audio.filter(n => n.isSink && n.isStream)
    PwObjectTracker { objects: root.visible ? root.audio : [] }

    function mins(m) { return m ? String(m) : "never"; }

    // ---- система ----
    property string kernel
    Process { running: true; command: ["uname", "-r"]; stdout: StdioCollector { onStreamFinished: root.kernel = this.text.trim() } }
    // reload сбрасывает всё, что пришло через eval, — после него правила накатываются заново
    Process { id: hyprReload; command: ["hyprctl", "reload"]; onExited: Rules.applyAll() }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "demonshot-settings"

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Theme.fade(Theme.pit, 0.92)
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
            if ([Qt.Key_Left, Qt.Key_H, Qt.Key_PageUp].includes(e.key)) root.turn(root.sel - 1);
            else if ([Qt.Key_Right, Qt.Key_L, Qt.Key_PageDown].includes(e.key)) root.turn(root.sel + 1);
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        // ---- книга: 1640×944, как .bk в макете ----
        // появляется закрытой по центру, падает на стол и раскрывается: левая половина — обложка, она перекидывается через корешок
        Item {
            id: book
            x: 108 - 410 * root.cov / 180 // закрытая стоит по центру, раскрываясь, уезжает на место разворота
            y: 50
            width: 1640
            height: 944

            MouseArea { anchors.fill: parent } // клик по книге не закрывает, мимо — закрывает

            // хвостик закладки торчит из-под нижнего края переплёта
            Shape {
                x: 834
                y: 900
                width: 16
                height: 104
                opacity: 0.85
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; x2: 16
                        GradientStop { position: 0; color: Theme.mix(Theme.crimson, Theme.void_, 0.4) }
                        GradientStop { position: 0.4; color: Theme.crimson }
                        GradientStop { position: 0.55; color: Theme.mix(Theme.crimson, Theme.bone, 0.2) }
                        GradientStop { position: 1; color: Theme.mix(Theme.crimson, Theme.void_, 0.35) }
                    }
                    PathPolyline { path: [Qt.point(0, 0), Qt.point(16, 0), Qt.point(16, 104), Qt.point(8, 88), Qt.point(0, 104), Qt.point(0, 0)] }
                }
            }

            // тень под книгой: пока обложка закрыта — только под правой половиной
            RectangularShadow {
                x: 820 * root.cov / 180
                width: 1640 - x
                height: 944
                radius: 10
                blur: 120 - 80 * root.cov / 180 // закрытая — тень плотнее, без дымки сбоку
                offset.y: 50
                color: Qt.rgba(0, 0, 0, 0.85)
            }

            // правая половина: переплёт и правая страница
            Item {
                x: 820
                width: 820
                height: 944
                clip: true
                Leather { x: -820 }
            }
            // вкладки на обрезе: пройденные главы переезжают на левый обрез, как у настоящего справочника.
            // Лежат под страницами: переезжая на другой обрез, едут под листами, а не поверх
            Repeater {
                model: root.sections
                Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.sel
                    readonly property bool past: index < root.sel
                    readonly property bool hot: th.containsMouse
                    y: 30 + index * 98
                    width: on ? 70 : hot ? 64 : 56
                    height: 84
                    x: past ? 12 - width : 1628
                    opacity: past ? 1 - root.cov / 90 : 1 // левые живут на обложке — проявляются, когда она легла
                    Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0.1, 0.2, 1, 1, 1] } }
                    Behavior on width { NumberAnimation { duration: 200 } }

                    // скругление только снаружи: лишнее уходит под клип
                    Item {
                        anchors.fill: parent
                        clip: true
                        Rectangle {
                            x: tab.past ? 0 : -10
                            width: parent.width + 10
                            height: parent.height
                            radius: 8
                            color: tab.on ? Theme.crimson : Theme.mix(root.pg, Theme.bone, 0.06)
                            border { width: 1; color: tab.on ? Theme.crimson : root.rule }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: tab.past ? -5 : 5
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Theme.roman(tab.index + 1)
                            color: tab.on ? Theme.void_ : tab.hot ? Theme.bone : Theme.ash
                            font { family: Theme.goth; pixelSize: 17 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tab.modelData.icon
                            color: tab.on ? Theme.void_ : tab.hot ? Theme.bone : Theme.ash
                            font { family: Theme.mono; pixelSize: 14 }
                        }
                    }
                    Text {
                        x: tab.past ? -implicitWidth - 14 : tab.width + 14
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: tab.hot ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        text: tab.modelData.name
                        color: Theme.bone
                        font { family: Theme.goth; pixelSize: 22 }
                    }
                    MouseArea { id: th; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.turn(tab.index) }
                }
            }

            RightPage { x: 820; y: 20; k: root.shownR }

            // левая половина — она же обложка: при cov 180 лежит лицом вниз поверх правой, на 0 — раскрыта
            Item {
                id: lhalf
                width: 820
                height: 944
                transform: Rotation { origin.x: 820; origin.y: 472; axis { x: 0; y: 1; z: 0 } angle: root.cov; distanceToPlane: 2800 }

                Item {
                    anchors.fill: parent
                    visible: root.cov <= 90
                    Item { anchors.fill: parent; clip: true; Leather {} }
                    LeftPage { x: 24; y: 20; k: root.shownL }
                }
                // лицевая сторона обложки: зеркалим, чтобы после поворота на 180 читалась как надо
                Cover {
                    visible: root.cov > 90
                    transform: Scale { origin.x: 410; xScale: -1 }
                }
                // в полёте на обложку ложится тень
                Rectangle {
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: 0.7 * Math.sin(Math.PI * root.cov / 180)
                    radius: 10
                    color: "black"
                }
            }

            // корешок
            Rectangle {
                x: 790
                y: 20
                z: 4
                width: 60
                height: 880
                opacity: 1 - root.cov / 90
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.48; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 0.51; color: Theme.fade(Theme.bone, 0.05) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // лист в полёте: лицо — уходящая страница, оборот — та, что ляжет на её место
            Item {
                id: leaf
                visible: leafAnim.running
                enabled: false
                x: root.fwd ? 820 : 24
                y: 20
                z: 6
                width: 796
                height: 880
                readonly property real ang: (root.fwd ? -180 : 180) * root.flip
                readonly property bool back: Math.abs(ang) > 90
                transform: Rotation { origin.x: root.fwd ? 0 : 796; origin.y: 440; axis { x: 0; y: 1; z: 0 } angle: leaf.ang; distanceToPlane: 2800 }

                Loader { active: leaf.visible; visible: !leaf.back; sourceComponent: root.fwd ? rightFrom : leftFrom }
                Loader {
                    active: leaf.visible
                    visible: leaf.back
                    transform: Scale { origin.x: 398; xScale: -1 }
                    sourceComponent: root.fwd ? leftTo : rightTo
                }
                // в середине хода на лист ложится тень
                Rectangle {
                    anchors.fill: parent
                    opacity: Math.sin(Math.PI * root.flip)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.65) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
            // копии на листе — без живой карты: лишний FrameAnimation на каждый взмах ни к чему
            Component { id: leftFrom; LeftPage { k: root.from; live: false } }
            Component { id: rightFrom; RightPage { k: root.from } }
            Component { id: leftTo; LeftPage { k: root.sel; live: false } }
            Component { id: rightTo; RightPage { k: root.sel } }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 60
            y: 1080 - 72
            opacity: 1 - root.cov / 180
            textFormat: Text.StyledText
            text: "<b>←→</b> листать · <b>⏎</b> пароль · <b>esc</b> закрыть книгу"
            color: Theme.ash
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 2 }
        }
    }

    // появление: закрытая книга падает на стол с поворотом, отскакивает, обложка распахивается и ложится
    property real cov: 0 // угол обложки: 180 — закрыта, 0 — раскрыта
    SequentialAnimation {
        id: enter
        ScriptAction { script: { root.cov = 180; book.opacity = 0; } }
        ParallelAnimation {
            NumberAnimation { target: dim; property: "opacity"; from: 0; to: 1; duration: 260 }
            NumberAnimation { target: book; property: "opacity"; from: 0; to: 1; duration: 140 }
            NumberAnimation { target: book; property: "y"; from: -260; to: 50; duration: 460; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
            NumberAnimation { target: book; property: "rotation"; from: 9; to: 0; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
            NumberAnimation { target: book; property: "scale"; from: 1.12; to: 1; duration: 460; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
        }
        PauseAnimation { duration: 80 }
        NumberAnimation { target: root; property: "cov"; from: 180; to: 0; duration: 760; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0, 0.25, 1, 1, 1] }
    }

    // ---- главы: правая страница ----

    // I · Network
    Component {
        id: netCh
        Column {
            width: 636
            Sec { text: "Wi-Fi"; sub: root.busy || "nmcli" }
            Line { text: "Radio"; sub: root.wifi ? "on" : "off"; Seal { on: root.wifi; onToggled: root.nm(root.wifi ? "radio off" : "radio on", ["radio", "wifi", root.wifi ? "off" : "on"]) } }
            // ошибка nmcli — как есть, одной строкой; клик убирает
            Text {
                visible: !!root.err
                width: parent.width
                topPadding: 4
                bottomPadding: 4
                text: "† " + root.err
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.crimson
                font { family: Theme.mono; pixelSize: 12 }
                MouseArea { anchors.fill: parent; onClicked: root.err = "" }
            }
            Item {
                visible: !!root.joined
                width: parent.width
                height: 54
                Text { id: wc; y: 12; text: root.joined?.ssid ?? ""; color: Theme.bone; font { family: Theme.goth; pixelSize: 34 } }
                Small {
                    x: wc.implicitWidth + 16
                    anchors.baseline: wc.baseline
                    text: `${root.joined?.signal ?? 0}% · ${root.joined?.sec || "open"}${root.wifiCon && root.wifiCon !== root.joined?.ssid ? " · " + root.wifiCon : ""}`
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: wc.verticalCenter
                    spacing: 10
                    Btn { ghost: true; text: "Drop"; onClicked: root.nm("disconnecting", ["con", "down", "id", root.wifiCon]) }
                    // удаляем профиль по имени, а не по SSID: у NM он бывает «SSID 1»
                    Btn { ghost: true; text: "Forget"; onClicked: root.nm("forgetting", ["con", "delete", "id", root.wifiCon]) }
                }
            }
            Sec { text: "Nearby"; sub: !root.wifi ? "radio off" : rescan.running ? "scanning" : `${Theme.roman(root.nets.length - (root.joined ? 1 : 0)).toLowerCase()} found` }
            Repeater {
                model: root.nets.filter(n => !n.used).slice(0, 6)
                Column {
                    id: net
                    required property var modelData
                    width: parent.width
                    Opt {
                        text: net.modelData.ssid
                        sub: net.modelData.sec || "open"
                        on: root.pick === net.modelData.ssid
                        // открытая или сохранённая — сразу (NM возьмёт профиль); иначе строка пароля.
                        // Если сохранённый пароль не подошёл, act сам откроет строку по ошибке «secrets required»
                        onClicked: {
                            if (!net.modelData.sec || net.modelData.known) return root.join(net.modelData, "");
                            root.pick = root.pick === net.modelData.ssid ? "" : net.modelData.ssid;
                        }
                        Row {
                            spacing: 12
                            Text { text: root.strength(net.modelData.signal); color: Theme.ash; font { family: Theme.mono; pixelSize: 15 } }
                            // замок — нужен пароль; сохранённая — галочка Rose
                            Text {
                                text: net.modelData.known ? "\u{F012C}" : net.modelData.sec ? "\u{F033E}" : "\u{F033F}"
                                color: net.modelData.known ? Theme.rose : Theme.ash
                                font { family: Theme.mono; pixelSize: 15 }
                            }
                        }
                    }
                    Item {
                        visible: root.pick === net.modelData.ssid
                        // лист в полёте (enabled: false) — копия, фокус у неё не забираем
                        onVisibleChanged: if (visible && enabled) { pw.text = ""; pw.forceActiveFocus(); }
                        Component.onCompleted: if (visible && enabled) pw.forceActiveFocus()
                        width: parent.width
                        height: 50
                        Rectangle { x: 30; y: 38; width: connect.x - 50; height: 1.5; color: Theme.bone }
                        TextInput {
                            id: pw
                            x: 30; y: 6; width: connect.x - 50; height: 30
                            echoMode: TextInput.Password
                            passwordCharacter: "■"
                            color: Theme.bone
                            font { family: Theme.mono; pixelSize: 14; letterSpacing: 4 }
                            verticalAlignment: TextInput.AlignVCenter
                            Keys.onReturnPressed: connect.clicked()
                            Keys.onEscapePressed: { root.pick = ""; stage.forceActiveFocus(); }
                        }
                        Btn {
                            id: connect
                            anchors.right: parent.right
                            y: 6
                            text: "Connect"
                            onClicked: {
                                root.join(net.modelData, pw.text);
                                stage.forceActiveFocus();
                            }
                        }
                    }
                }
            }
            // vpn/wireguard из профилей NM; tun поднимает своё приложение (Mihomo и т.п.) — только показываем
            Sec { visible: root.tunnels.length > 0; text: "Wire & tunnels" }
            Grid {
                columns: 2
                columnSpacing: 40
                Repeater {
                    model: root.tunnels
                    Line {
                        id: tl
                        required property var modelData
                        width: 298
                        text: modelData.name
                        sub: modelData.type
                        Seal {
                            enabled: tl.modelData.type !== "tun"
                            on: tl.modelData.on
                            onToggled: root.nm(tl.modelData.on ? "down" : "up", ["con", tl.modelData.on ? "down" : "up", "id", tl.modelData.name])
                        }
                    }
                }
            }
        }
    }

    // IV · Display
    Component {
        id: dispCh
        Column {
            width: 636
            Sec { text: "Monitor"; sub: `${Rules.mon.name.toLowerCase()} · ${Rules.mon.w} × ${Rules.mon.h} · ${Rules.refreshHz} hz` }
            Line {
                text: "Scale"; sub: `${Math.round(Rules.mon.w / Rules.scale)} × ${Math.round(Rules.mon.h / Rules.scale)}`
                Pick { opts: Rules.scales; cur: Rules.scaleIdx; onPicked: i => Rules.setScale(i) }
            }
            Line {
                text: "Refresh"; sub: "vrr"
                Pick { opts: Rules.rates.map(String); cur: Rules.rates.indexOf(Rules.refreshHz); onPicked: i => { root.rules.refresh = Rules.rates[i]; Rules.monitor(); } }
            }
            Line { text: "Brightness"; visible: !!Backlight.dev; Sl { to: 100; value: root.rules.brightness; onCommitted: v => { root.rules.brightness = v; Rules.brightness(); } } }
            Line { text: "Night light"; sub: "hyprsunset"; Seal { on: root.rules.night; onToggled: { root.rules.night = !root.rules.night; Rules.night(); } } }
            Line { text: "Warmth"; Sl { from: 2500; to: 6500; step: 100; unit: "k"; value: root.rules.warmth; onCommitted: v => { root.rules.warmth = v; if (root.rules.night) Rules.night(); } } }
            Sec { text: "Windows"; sub: "hyprland" }
            Line { text: "Gaps in"; Sl { to: 30; value: root.rules.gapsIn; onCommitted: v => { root.rules.gapsIn = v; Rules.windows(); } } }
            Line { text: "Gaps out"; Sl { to: 60; value: root.rules.gapsOut; onCommitted: v => { root.rules.gapsOut = v; Rules.windows(); } } }
            Line { text: "Border"; Sl { to: 6; value: root.rules.border; onCommitted: v => { root.rules.border = v; Rules.windows(); } } }
            Line { text: "Rounding"; Sl { to: 20; value: root.rules.rounding; onCommitted: v => { root.rules.rounding = v; Rules.windows(); } } }
            Grid {
                columns: 2
                columnSpacing: 40
                Line { width: 298; text: "Blur"; Seal { on: root.rules.blur; onToggled: { root.rules.blur = !root.rules.blur; Rules.windows(); } } }
                Line { width: 298; text: "Shadow"; Seal { on: root.rules.shadow; onToggled: { root.rules.shadow = !root.rules.shadow; Rules.windows(); } } }
            }
            // ponytail: только вкл/выкл (Rules.motion); snap — когда Rules научится менять кривые
            Line { text: "Motion"; Pick { opts: ["slam", "off"]; cur: root.rules.motion ? 0 : 1; onPicked: i => { root.rules.motion = i === 0; Rules.motion(); } } }
        }
    }

    // V · Colors: клик по колоде — палитра сразу ложится на шелл, hypr и kitty (и на саму книгу)
    Component {
        id: colCh
        Column {
            width: 636
            Sec { text: "Decks"; sub: "normal · bright" }
            Repeater {
                model: Rules.palettes
                Opt {
                    id: deck
                    required property var modelData
                    required property int index
                    text: modelData.name
                    sub: modelData.what
                    on: index === root.rules.palette
                    onClicked: { root.rules.palette = deck.index; Rules.paint(); }
                    // ponytail: яркий ряд — тот же цвет светлее, как bright-цвета терминала
                    Item {
                        width: strip.width
                        height: strip.height
                        Grid {
                            id: strip
                            columns: 8
                            Repeater {
                                model: deck.modelData.c.concat(deck.modelData.c.map(x => Qt.lighter(x, 1.45)))
                                Rectangle { required property var modelData; width: 18; height: 9; color: modelData }
                            }
                        }
                        // выбранная колода — в костяной рамке
                        Rectangle {
                            visible: deck.on
                            anchors.fill: parent
                            anchors.margins: -4
                            color: "transparent"
                            border { width: 1; color: Theme.bone }
                        }
                    }
                }
            }
            Sec { text: "Paint over"; sub: "on apply" }
            Grid {
                columns: 2
                columnSpacing: 40
                Line { width: 298; text: "Hyprland"; Seal { on: root.rules.paintHypr; onToggled: { root.rules.paintHypr = !root.rules.paintHypr; Rules.paint(); } } }
                Line { width: 298; text: "Kitty"; Seal { on: root.rules.paintKitty; onToggled: { root.rules.paintKitty = !root.rules.paintKitty; Rules.paint(); } } }
            }
        }
    }

    // II · Bluetooth: связанные — клик соединяет и разрывает; чужие — клик знакомит (pair), дальше как со связанными
    Component {
        id: btCh
        Column {
            width: 636
            Sec { text: "Adapter"; sub: root.bt?.name ?? "none found" }
            Grid {
                columns: 2
                columnSpacing: 40
                Line { width: 298; text: "Power"; Seal { on: root.bt?.enabled ?? false; onToggled: if (root.bt) root.bt.enabled = !root.bt.enabled } }
                Line { width: 298; text: "Visible"; sub: "to others"; Seal { on: root.bt?.discoverable ?? false; onToggled: if (root.bt) root.bt.discoverable = !root.bt.discoverable } }
            }
            Sec { text: "Bound"; sub: { const n = root.btDevs.filter(d => d.paired).length; return n ? Theme.roman(n).toLowerCase() : "none"; } }
            Repeater {
                model: root.btDevs.filter(d => d.paired).slice(0, 5)
                Opt {
                    id: bd
                    required property var modelData
                    readonly property var d: modelData
                    text: d.name || d.address
                    sub: (d.state === BluetoothDeviceState.Connecting ? "calling" : d.state === BluetoothDeviceState.Disconnecting ? "parting" : d.connected ? "bound" : "apart")
                         + (d.batteryAvailable ? ` · ${Math.round(d.battery * 100)}%` : "")
                    on: d.connected
                    onClicked: d.connected ? d.disconnect() : d.connect()
                    Row {
                        spacing: 14
                        Text { anchors.verticalCenter: parent.verticalCenter; text: root.btIcon(bd.d.icon); color: bd.d.connected ? Theme.rose : Theme.ash; font { family: Theme.mono; pixelSize: 15 } }
                        Btn { ghost: true; text: "Forget"; onClicked: bd.d.forget() }
                    }
                }
            }
            Sec { text: "Strangers"; sub: !root.bt?.enabled ? "power off" : root.bt.discovering ? "searching" : "" }
            Repeater {
                // безымянные (только адрес) — шум эфира, не показываем
                model: root.btDevs.filter(d => !d.paired && d.deviceName).slice(0, 5)
                Opt {
                    id: sd
                    required property var modelData
                    readonly property var d: modelData
                    text: d.name
                    sub: d.pairing ? "pairing" : "pair"
                    on: d.pairing
                    onClicked: { if (d.pairing) return d.cancelPair(); d.trusted = true; d.pair(); }
                    Text { text: root.btIcon(sd.d.icon); color: Theme.ash; font { family: Theme.mono; pixelSize: 15 } }
                }
            }
        }
    }

    // III · Sound: громкость тянется ползунком, значок рядом глушит; выбранное устройство — крест на полях
    Component {
        id: sndCh
        Column {
            width: 636
            Sec { text: "Out"; sub: "pipewire" }
            Vol { node: Pipewire.defaultAudioSink; text: "Volume" }
            Repeater {
                model: root.sinks.length > 1 ? root.sinks.slice(0, 4) : []
                Opt {
                    required property var modelData
                    text: modelData.description || modelData.name
                    on: modelData === Pipewire.defaultAudioSink
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
            Sec { text: "In" }
            Vol { node: Pipewire.defaultAudioSource; text: "Voice"; icons: ["\u{F036C}", "\u{F036D}"] }
            Repeater {
                model: root.sources.length > 1 ? root.sources.slice(0, 3) : []
                Opt {
                    required property var modelData
                    text: modelData.description || modelData.name
                    on: modelData === Pipewire.defaultAudioSource
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
            Sec { text: "Apps"; sub: root.streams.length ? Theme.roman(root.streams.length).toLowerCase() + " playing" : "all quiet" }
            Repeater {
                model: root.streams.slice(0, 4)
                Vol {
                    required property var modelData
                    node: modelData
                    text: modelData.properties["application.name"] || modelData.description || modelData.name
                    sub: (modelData.properties["media.name"] ?? "").slice(0, 24)
                }
            }
        }
    }

    // VI · Input: применяется через hyprctl eval (Rules.input), как Display
    Component {
        id: inpCh
        Column {
            width: 636
            Sec { text: "Keys"; sub: "us · ru" }
            Line {
                text: "Switch layout"
                Pick { opts: Rules.switches.map(s => s[0]); cur: root.rules.kbSwitch; onPicked: i => { root.rules.kbSwitch = i; Rules.input(); } }
            }
            Line { text: "Repeat delay"; Sl { from: 150; to: 600; step: 10; unit: "ms"; value: root.rules.repeatDelay; onCommitted: v => { root.rules.repeatDelay = v; Rules.input(); } } }
            Line { text: "Repeat rate"; sub: "per second"; Sl { from: 10; to: 60; value: root.rules.repeatRate; onCommitted: v => { root.rules.repeatRate = v; Rules.input(); } } }
            Sec { text: "Touchpad" }
            Grid {
                columns: 2
                columnSpacing: 40
                Line { width: 298; text: "Natural scroll"; Seal { on: root.rules.natural; onToggled: { root.rules.natural = !root.rules.natural; Rules.input(); } } }
                Line { width: 298; text: "Tap to click"; Seal { on: root.rules.tap; onToggled: { root.rules.tap = !root.rules.tap; Rules.input(); } } }
            }
            Line { text: "Still while typing"; Seal { on: root.rules.typingOff; onToggled: { root.rules.typingOff = !root.rules.typingOff; Rules.input(); } } }
            Line { text: "Scroll"; Sl { from: 10; to: 100; step: 5; unit: "%"; value: root.rules.scroll; onCommitted: v => { root.rules.scroll = v; Rules.input(); } } }
            Sec { text: "Pointer" }
            Line { text: "Sensitivity"; Sl { from: -100; to: 100; step: 5; value: root.rules.sens; onCommitted: v => { root.rules.sens = v; Rules.input(); } } }
            Line { text: "Acceleration"; Pick { opts: ["adaptive", "flat"]; cur: root.rules.flat ? 1 : 0; onPicked: i => { root.rules.flat = i === 1; Rules.input(); } } }
        }
    }

    // VII · Idle: hypridle, конфиг пишет Rules.idle(); свеча в оберегах держит дом бодрствующим поверх этого
    Component {
        id: idleCh
        Column {
            width: 636
            Sec { text: "Watch"; sub: "hypridle · minutes" }
            Line { text: "Bar the door"; sub: "lock"; Pick { readonly property var m: [1, 3, 5, 10, 0]; opts: m.map(root.mins); cur: m.indexOf(root.rules.lockAfter); onPicked: i => { root.rules.lockAfter = m[i]; Rules.idle(); } } }
            Line { text: "Put out the light"; sub: "dpms"; Pick { readonly property var m: [3, 5, 10, 15, 0]; opts: m.map(root.mins); cur: m.indexOf(root.rules.dpmsAfter); onPicked: i => { root.rules.dpmsAfter = m[i]; Rules.idle(); } } }
            Line { text: "Fall asleep"; sub: "suspend"; Pick { readonly property var m: [10, 20, 30, 60, 0]; opts: m.map(root.mins); cur: m.indexOf(root.rules.sleepAfter); onPicked: i => { root.rules.sleepAfter = m[i]; Rules.idle(); } } }
            Sec { text: "Sleep" }
            Line { text: "Sleep into"; visible: Rules.canHibernate; Pick { opts: ["suspend", "hibernate later"]; cur: root.rules.hibernate ? 1 : 0; onPicked: i => { root.rules.hibernate = i === 1; Rules.idle(); } } }
            Kv { k: "before sleep"; v: "lock" }
            Kv { k: "config"; v: Rules.dir.replace(Quickshell.env("HOME"), "~") + "/hypridle.conf" }
        }
    }

    // VIII · Notices: тишина общая с оберегами
    Component {
        id: noteCh
        Column {
            width: 636
            Sec { text: "Silence"; sub: "also in wards" }
            Line { text: "Do not disturb"; sub: "the tower still calls"; Seal { on: root.rules.dnd; onToggled: root.rules.dnd = !root.rules.dnd } }
            Sec { text: "Omens" }
            Line { text: "Burn after"; sub: "seconds"; Pick { readonly property var m: [4, 6, 10, 0]; opts: m.map(root.mins); cur: m.indexOf(root.rules.noteTime); onPicked: i => root.rules.noteTime = m[i] } }
            Line { text: "Open in the deck"; Pick { readonly property var m: [3, 5, 8]; opts: m.map(String); cur: m.indexOf(root.rules.noteDeck); onPicked: i => root.rules.noteDeck = m[i] } }
        }
    }

    // IX · System
    Component {
        id: sysCh
        Column {
            width: 636
            Sec { text: "This machine"; sub: "uname" }
            Kv { k: "user"; v: `${Quickshell.env("USER")}@${Quickshell.env("HOSTNAME") || "arch"}` }
            Kv { k: "kernel"; v: root.kernel }
            Kv { k: "wm"; v: "hyprland" }
            Kv { k: "shell"; v: "quickshell · demonshot" }
            Kv { k: "rules"; v: Rules.dir.replace(Quickshell.env("HOME"), "~") + "/rules.json" }
            Sec { text: "Time & tongue" }
            Line { text: "Roman"; sub: "workspaces · clock · lists"; Seal { on: root.rules.roman; onToggled: root.rules.roman = !root.rules.roman } }
            Sec { text: "Shell" }
            Item { width: 1; height: 12 }
            Row {
                spacing: 16
                Btn { ghost: true; text: "Reload shell"; onClicked: Quickshell.reload(false) }
                Btn { ghost: true; text: "Reload Hyprland"; onClicked: hyprReload.running = true }
            }
        }
    }

    // ---- страницы ----

    // лист пергамента: обрез стопкой, тень к корешку, рамка набора с крестами, колонцифра, кустода, край для листания
    component Sheet: Item {
        id: sh
        property bool leftSide
        property string folio
        property string catchword // кустода: первое слово следующей страницы, как в старопечатных книгах
        default property alias content: body.data
        width: 796
        height: 880

        Repeater {
            model: [5, 4, 3, 2, 1]
            Rectangle {
                required property int modelData
                x: (sh.leftSide ? -1 : 1) * modelData
                y: 2 * modelData
                width: sh.width
                height: sh.height
                radius: 4
                color: modelData % 2 ? Theme.pit : Theme.mix(Theme.crimson, Theme.void_, modelData === 2 ? 0.45 : 0.55)
            }
        }
        Rectangle { anchors.fill: parent; radius: 4; color: root.pg }
        // пергамент темнеет к краям
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 398; centerY: 440; centerRadius: 600
                    focalX: 398; focalY: 440
                    GradientStop { position: 0.72; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.4) }
                }
                PathRectangle { width: 796; height: 880; radius: 4 }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: sh.leftSide ? 0.82 : 0; color: sh.leftSide ? "transparent" : Qt.rgba(0, 0, 0, 0.5) }
                GradientStop { position: sh.leftSide ? 1 : 0.18; color: sh.leftSide ? Qt.rgba(0, 0, 0, 0.5) : "transparent" }
            }
        }
        // рамка набора: двойная линейка, по углам кресты прерывают линию
        Rectangle { anchors.fill: parent; anchors.margins: 20; color: "transparent"; border { width: 1; color: root.frame } }
        Rectangle { anchors.fill: parent; anchors.margins: 22; color: "transparent"; border { width: 1; color: root.frame } }
        Repeater {
            model: [[21, 21], [775, 21], [775, 859], [21, 859]]
            Rectangle {
                required property var modelData
                x: modelData[0] - 13
                y: modelData[1] - 13
                width: 26
                height: 26
                color: root.pg
                Text { anchors.centerIn: parent; text: "†"; color: Theme.crimson; font { family: Theme.goth; pixelSize: 22 } }
            }
        }

        Item { id: body; anchors.fill: parent }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            text: sh.folio
            color: Theme.ash
            font { family: Theme.goth; pixelSize: 18 }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 80
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            text: sh.catchword
            color: Theme.ash
            font { family: Theme.goth; pixelSize: 17 }
        }
        // внешний обрез: под курсором край чуть светлеет, клик — перевернуть
        MouseArea {
            id: edge
            x: sh.leftSide ? 0 : parent.width - 56
            width: 56
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.turn(root.sel + (sh.leftSide ? -1 : 1))
            Rectangle {
                anchors.fill: parent
                visible: edge.containsMouse
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: sh.leftSide ? Theme.fade(Theme.bone, 0.07) : "transparent" }
                    GradientStop { position: 1; color: sh.leftSide ? "transparent" : Theme.fade(Theme.bone, 0.07) }
                }
            }
        }
    }

    // кожа переплёта во весь разворот; половины вырезаются клипом
    component Leather: Item {
        width: 1640
        height: 944
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1
                strokeColor: Theme.wine
                fillGradient: RadialGradient {
                    centerX: 820; centerY: 378; centerRadius: 900
                    focalX: 820; focalY: 378
                    GradientStop { position: 0; color: Theme.mix(Theme.void_, Theme.wine, 0.8) }
                    GradientStop { position: 1; color: Theme.mix(Theme.void_, Theme.wine, 0.45) }
                }
                PathRectangle { width: 1640; height: 944; radius: 10 }
            }
        }
        Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border { width: 7; color: Theme.mix(Theme.void_, Theme.wine, 0.6) } }
        Rectangle { anchors.fill: parent; anchors.margins: 7; radius: 4; color: "transparent"; border { width: 1; color: Theme.fade(Theme.bone, 0.12) } }
    }

    // лицевая сторона обложки (закрытая книга): тиснёная рамка, медные кресты, D фрактурой, название
    component Cover: Item {
        width: 820
        height: 944
        Item { anchors.fill: parent; clip: true; Leather { x: -820 } }
        // корешок обложки: матовая тёмная кожа, рёбра-бинты как у старых переплётов, кресты между ними, у сгиба бороздка
        Item {
            width: 58
            height: parent.height
            Rectangle { anchors.fill: parent; radius: 10; color: Theme.mix(Theme.void_, Theme.wine, 0.55) }
            Rectangle { x: 10; width: 48; height: parent.height; color: Theme.mix(Theme.void_, Theme.wine, 0.55) } // справа без скругления
            Rectangle { x: 7; y: 7; width: 1; height: parent.height - 14; color: Theme.fade(Theme.bone, 0.12) }
            Repeater {
                model: 5
                Item {
                    required property int index
                    x: 8
                    y: 100 + index * 186
                    width: 50
                    height: 10
                    Rectangle { y: -1; width: parent.width; height: 1; color: Theme.fade(Theme.bone, 0.12) }
                    Rectangle { width: parent.width; height: 6; color: Theme.mix(Theme.void_, Theme.wine, 0.85) }
                    Rectangle { y: 6; width: parent.width; height: 2; color: Qt.rgba(0, 0, 0, 0.5) }
                }
            }
            Repeater {
                model: 4
                Text {
                    required property int index
                    x: 33 - implicitWidth / 2
                    y: 193 + index * 186 - implicitHeight / 2
                    text: "†"
                    color: Theme.crimson
                    font { family: Theme.goth; pixelSize: 20 }
                }
            }
            // бороздка сгиба
            Rectangle { x: 58; width: 2; height: parent.height; color: Qt.rgba(0, 0, 0, 0.5) }
            Rectangle { x: 60; width: 1; height: parent.height; color: Theme.fade(Theme.bone, 0.08) }
        }
        Rectangle { x: 80; y: 60; width: 680; height: 824; color: "transparent"; border { width: 1; color: root.frame } }
        Rectangle { x: 86; y: 66; width: 668; height: 812; color: "transparent"; border { width: 1; color: root.frame } }
        Repeater {
            model: [[80, 60], [760, 60], [760, 884], [80, 884]]
            Rectangle {
                required property var modelData
                x: modelData[0] - 17
                y: modelData[1] - 17
                width: 34
                height: 34
                rotation: 45
                color: Theme.mix(Theme.wine, Theme.void_, 0.4)
                border { width: 1; color: Theme.crimson }
                Text { anchors.centerIn: parent; rotation: -45; text: "†"; color: Theme.crimson; font { family: Theme.goth; pixelSize: 22 } }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 18
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "LIBER"
                color: Theme.rose
                font { family: Theme.goth; pixelSize: 22; letterSpacing: 14 }
            }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: bigD.implicitWidth
                height: bigD.implicitHeight
                Text { x: -7; y: 7; text: "D"; color: Theme.bone; font: bigD.font }
                Text { id: bigD; text: "D"; color: Theme.crimson; font { family: Theme.frak; pixelSize: 260; bold: true } }
            }
            Swirl { anchors.horizontalCenter: parent.horizontalCenter; w: 320 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "regularum domus"
                color: Theme.bone
                font { family: Theme.goth; pixelSize: 46 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DEMON'S SHOT · HOUSE RULES"
                color: Theme.ash
                font { family: Theme.mono; pixelSize: 10; letterSpacing: 4 }
            }
        }
    }

    // колонтитул: слева и справа, под ним линейка
    component RunHead: Item {
        id: rh
        property string l
        property string r
        x: 80
        y: 36
        width: 636
        height: 22
        Text { text: rh.l.toUpperCase(); color: Theme.ash; font { family: Theme.mono; pixelSize: 10; letterSpacing: 3.5 } }
        Text { anchors.right: parent.right; textFormat: Text.StyledText; text: rh.r.toUpperCase(); color: Theme.ash; font { family: Theme.mono; pixelSize: 10; letterSpacing: 3.5 } }
        Rectangle { y: 21; width: parent.width; height: 1; color: root.rule }
    }

    // фронтиспис: номер главы, заголовок с буквицей, эпиграф из клипа, аркан вклеен уголками, подпись к таблице
    component LeftPage: Sheet {
        id: lp
        property int k
        property bool live: true // качается и тянется к курсору только карта на настоящей странице
        readonly property var sec: root.sections[k]
        leftSide: true
        folio: root.folio(13 + k * 4)
        catchword: (sec.pr ?? "").split(" ")[0]

        RunHead { l: "Liber regularum domus"; r: `caput <font color="${Theme.rose}">${Theme.roman(lp.k + 1)}</font>` }
        Text {
            y: 104
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "CAPUT " + Theme.roman(lp.k + 1)
            color: Theme.rose
            font { family: Theme.goth; pixelSize: 17; letterSpacing: 8.5 }
        }
        Item {
            y: 132
            anchors.horizontalCenter: parent.horizontalCenter
            width: rest.x + rest.implicitWidth
            height: rest.implicitHeight
            Text {
                id: rest
                x: cap.implicitWidth - 4
                text: lp.sec.name.slice(1)
                color: Theme.bone
                font { family: Theme.goth; pixelSize: 96; weight: Font.Black; letterSpacing: -2 }
            }
            // буквица фрактурой: Crimson с костяной тенью, чуть ниже строки
            Text { x: cap.x - 4; y: cap.y + 4; text: cap.text; color: Theme.bone; font: cap.font }
            Text {
                id: cap
                y: rest.baselineOffset - baselineOffset + 13
                text: lp.sec.name[0]
                color: Theme.crimson
                font { family: Theme.frak; pixelSize: 134; bold: true }
            }
        }
        Swirl { y: 250; anchors.horizontalCenter: parent.horizontalCenter; w: 280 }
        Text {
            y: 314
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: `«${lp.sec.lyr}»`
            color: Theme.rose
            font { family: Theme.goth; pixelSize: 21 }
        }
        Item {
            x: 288
            y: 364
            width: 220
            height: 380
            rotation: -2
            Card {
                live: lp.live
                up: true
                seed: lp.k
                num: lp.sec.num
                name: lp.sec.card
                raysY: 0.5 // одна иконка — по центру сцены
                ArcanaArt { glyph: lp.sec.page === "sys" ? "sigil" : lp.sec.icon; size: 80 }
            }
        }
        Column {
            y: 764
            width: parent.width
            spacing: 6
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: lp.sec.q; color: Theme.bone; font { family: Theme.goth; pixelSize: 30 } }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: `tab. ${lp.sec.num} · ${lp.sec.card} — ${lp.sec.ru}`
                color: Theme.ash
                font { family: Theme.mono; pixelSize: 10; letterSpacing: 3 }
            }
        }
    }

    // правая страница: вводный абзац с буквицей, параграфы §, строки через отточие — как оглавление
    component RightPage: Sheet {
        id: rp
        property int k
        readonly property var sec: root.sections[k]
        folio: root.folio(14 + k * 4)
        catchword: root.sections[k + 1]?.name ?? ""

        RunHead { l: `${rp.sec.name} · ${rp.sec.sub}`; r: `${Theme.roman(rp.k + 1)} of ${Theme.roman(root.sections.length).toLowerCase()}` }
        Column {
            x: 80
            y: 84
            width: 636
            Intro { text: rp.sec.pr ?? "" }
            Loader { sourceComponent: ({ net: netCh, bt: btCh, snd: sndCh, disp: dispCh, col: colCh, inp: inpCh, idle: idleCh, note: noteCh, sys: sysCh })[rp.sec.page] }
            // концовка под главой
            Item { width: 1; height: 26 }
            Swirl { anchors.horizontalCenter: parent.horizontalCenter; w: 230 }
        }
    }

    // ---- детали ----

    // вводный абзац: буквица фрактурой в двойной Crimson-рамке
    component Intro: Item {
        id: it
        property string text
        width: parent?.width ?? 0
        height: Math.max(62, body.implicitHeight) + 4
        Rectangle {
            id: dcap
            y: 3
            width: 58
            height: 58
            color: Theme.mix(root.pg, Theme.plum, 0.7)
            border { width: 1; color: Theme.crimson }
            Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border { width: 1; color: Theme.crimson } }
            Text { anchors.centerIn: parent; text: it.text[0] ?? ""; color: Theme.bone; font { family: Theme.frak; pixelSize: 52; bold: true } }
        }
        Text {
            id: body
            x: dcap.width + 12
            width: parent.width - x
            text: it.text.slice(1)
            wrapMode: Text.Wrap
            lineHeight: 1.3
            color: root.ink
            font { family: Theme.goth; pixelSize: 19 }
        }
    }
    // §, строки, печать, выбор словом — общие со свитком (components/Book.qml)
    component Sec: Book.Sec {}
    component Small: Book.Small {}
    component Leader: Book.Leader {}
    component Line: Book.Line {}
    component Opt: Book.Opt {}
    component Seal: Book.Seal {}
    component Pick: Book.Pick {}
    component Kv: Book.Kv {}
    component Sl: Item {
        id: sl
        property real from: 0
        property real to: 100
        property real step: 1
        property real value: 0
        property string unit
        property int len: 170
        signal committed(real v)
        // тянем свою копию: биндинг value не рвётся, и громкость с клавиш доезжает и после перетаскивания
        property real cur: value
        onValueChanged: cur = value
        readonly property real frac: Math.max(0, Math.min(1, (cur - from) / (to - from)))
        function at(x) { sl.cur = Math.round((from + Math.max(0, Math.min(1, x / len)) * (to - from)) / step) * step; }
        width: len + 80
        height: 22
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: sl.len
            height: 1.5
            color: Theme.fade(Theme.ash, 0.4)
            Rectangle { width: parent.width * sl.frac; height: parent.height; color: Theme.bone }
        }
        Rectangle { x: sl.len * sl.frac - 5.5; y: 5.5; width: 11; height: 11; rotation: 45; color: Theme.crimson; border { color: Theme.mix(Theme.crimson, Theme.bone, 0.4); width: 1.5 } }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(sl.cur) + sl.unit
            color: Theme.bone
            font { family: Theme.goth; pixelSize: 21 }
        }
        MouseArea {
            width: sl.len
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onPressed: m => sl.at(m.x)
            onPositionChanged: m => sl.at(m.x)
            onReleased: sl.committed(sl.cur)
            onWheel: w => {
                sl.cur = Math.max(sl.from, Math.min(sl.to, sl.cur + (w.angleDelta.y > 0 ? sl.step : -sl.step)));
                sl.committed(sl.cur);
            }
        }
    }
    // громкость узла pipewire: ползунок и значок, клик по значку глушит
    // база — Item, а не Book.Line: в наследнике чужого компонента свои Sl не находятся («is not a type»)
    component Vol: Item {
        id: vo
        property var node
        property string text
        property string sub
        property var icons: ["\u{F057E}", "\u{F075F}"] // звучит · заглушён
        readonly property bool muted: node?.audio?.muted ?? false
        width: parent?.width ?? 0
        height: 42
        Line {
            text: vo.text
            sub: vo.sub
            Row {
                spacing: 16
                Sl { to: 100; unit: "%"; value: Math.round((vo.node?.audio?.volume ?? 0) * 100); onCommitted: v => { if (vo.node?.audio) vo.node.audio.volume = v / 100; } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: vo.icons[vo.muted ? 1 : 0]
                    color: vo.muted ? Theme.crimson : Theme.ash
                    font { family: Theme.mono; pixelSize: 17 }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (vo.node?.audio) vo.node.audio.muted = !vo.muted }
                }
            }
        }
    }
    // кнопка — косой срез, как .btn в макете
    component Btn: Item {
        id: btn
        property string text
        property bool ghost: false
        signal clicked
        width: bt.implicitWidth + 44
        height: bt.implicitHeight + 8
        opacity: mb.containsMouse ? 1 : 0.88
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillColor: btn.ghost ? Theme.wine : Theme.crimson
                PathPolyline { path: [Qt.point(btn.width * 0.08, 0), Qt.point(btn.width, 0), Qt.point(btn.width * 0.92, btn.height), Qt.point(0, btn.height), Qt.point(btn.width * 0.08, 0)] }
            }
        }
        Text { id: bt; anchors.centerIn: parent; text: btn.text; color: btn.ghost ? Theme.pale : Theme.bone; font { family: Theme.goth; pixelSize: 18 } }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
    // орнамент swirl из макета (160×30): левая половина + зеркало, посередине крест с каплей. Штрих — 1px при любой ширине
    component Swirl: Item {
        id: sw
        property real w: 280
        width: w
        height: w * 30 / 160
        Item {
            width: 160
            height: 30
            scale: sw.w / 160
            transformOrigin: Item.TopLeft
            Repeater {
                model: 2
                Shape {
                    required property int index
                    width: 160
                    height: 30
                    preferredRendererType: Shape.CurveRenderer
                    transform: Scale { origin.x: 80; xScale: index ? -1 : 1 }
                    ShapePath {
                        strokeColor: Theme.rose
                        strokeWidth: 160 / sw.w
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: "M73 15 C64 15 58 21 46 19 C32 17 27 6 16 8 C8 9.5 7.5 19 15 19 C20 19 20 13 16 13 M69 11 C60 5 46 5 36 11 M65 19.5 C58 24 48 25 40 22" }
                    }
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Theme.rose
                        PathSvg { path: "M73 15 C70 11 66 10 62 11 C65 13.5 69 15 73 15 Z M36 9.8 A1.2 1.2 0 1 0 36 12.2 A1.2 1.2 0 1 0 36 9.8 Z M40 20.8 A1.2 1.2 0 1 0 40 23.2 A1.2 1.2 0 1 0 40 20.8 Z" }
                    }
                }
            }
            Shape {
                width: 160
                height: 30
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.rose
                    strokeWidth: 2.2 * 160 / sw.w
                    fillColor: "transparent"
                    PathSvg { path: "M80 2 V28 M75 9 H85" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.rose
                    PathSvg { path: "M80 24 L78 27 L80 30 L82 27 Z" }
                }
            }
        }
    }
}
