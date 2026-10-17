import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// буфер обмена: барабан револьвера на XIII камор выкатывается из правого края. Камора = запись cliphist,
// у ствола — выбранная; дальше по кругу заряжаются следующие, так что барабан крутится по всей истории.
// ⏎ — выстрел: в буфер и сразу вставить в окно
PanelWindow {
    id: root

    readonly property real step: 360 / 13
    readonly property int bigR: 600   // барабан
    readonly property int chR: 440    // круг камор
    // тип: иконка, аркан, имя карты, смысл, по-русски, клеймо на гильзе
    readonly property var types: ({
        code:  ["\u{F0169}", "I", "The Magician", "Same trick twice.", "код", "CODE"],
        text:  ["\u{F09A8}", "V", "The Hierophant", "Say it again.", "текст", "TXT"],
        link:  ["\u{F0337}", "0", "The Fool", "Step through.", "ссылка", "URL"],
        image: ["\u{F02E9}", "XVIII", "The Moon", "Still right before your eyes.", "картинка", "IMG"],
        color: ["\u{F03D8}", "III", "The Empress", "Paint it red.", "цвет", "HEX"],
        file:  ["\u{F0214}", "VIII", "Strength", "Carry it over.", "файл", "FILE"]
    })
    readonly property var filters: ["all", "text", "links", "images"]

    property var entries: [] // { id, text, type }
    property var held: []
    property int filter: 0
    property int sel: 0
    property int last: 0
    property real angle: 0
    property real enter: 0
    property real pvS: 0
    readonly property string query: input.text.toLowerCase()

    readonly property var view: entries.filter(e =>
        (filter === 0 || filter === 2 && e.type === "link" || filter === 3 && e.type === "image"
            || filter === 1 && e.type !== "link" && e.type !== "image")
        && e.text.toLowerCase().includes(query))
    readonly property var cur: view[sel] ?? null
    readonly property var ty: types[cur?.type ?? "text"]
    // полное содержимое выбранной записи (для картинки — путь к файлу); пока не пришло — превью из списка
    property string full: ""
    property string fullId: ""
    property string decId: ""
    readonly property string body: cur && fullId === cur.id ? full : cur?.text ?? ""

    function kind(t) {
        if (/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) \d+x\d+ \]\]$/.test(t)) return "image";
        if (t.startsWith("[[ binary data")) return "file";
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t)) return "color";
        if (/^https?:\/\/\S+$/.test(t)) return "link";
        if (/^(file:\/\/|~?\/)\S+$/.test(t)) return "file";
        // ponytail: код угадываем по скобкам и знакомым командам; промахнулись — покажется текстом
        if (/[{};]|^(sudo|git|cd|qs|hyprctl|pacman|paru|yay|npm|cargo|systemctl|sh|bash|curl) /.test(t)) return "code";
        return "text";
    }
    function label(e) {
        const img = e.text.match(/(\d+x\d+) \]\]$/);
        const s = e.type === "image" ? `image · ${img[1].replace("x", "×")}` : e.text.replace(/\s+/g, " ");
        return s.length > 34 ? s.slice(0, 33) + "…" : s;
    }
    // какая запись заряжена в камору i: шесть до выбранной и шесть после
    function at(i) {
        const k = sel % 13;
        return sel + (i - k + 19) % 13 - 6;
    }

    // поворот коротким путём: барабан всегда докручивает выбранную камору к стволу
    function turn(i) {
        i = Math.max(0, Math.min(i, view.length - 1));
        let d = ((i - last) % 13 + 13) % 13;
        if (d > 6) d -= 13;
        angle += d * step;
        last = i;
        sel = i;
        pvIn.restart();
    }

    function open() {
        list.running = true;
        input.text = "";
        filter = 0;
        sel = last = 0;
        angle = 0;
        visible = true;
        input.forceActiveFocus();
        drumIn.restart();
        pvIn.restart();
    }
    function close() { visible = false; }
    function toggle() { visible ? close() : open(); }

    function fire() {
        const it = cur;
        if (!it) return;
        // терминалы вставляют по Ctrl+Shift+V
        const term = /kitty|foot|alacritty|wezterm|ghostty|konsole/i.test(ToplevelManager.activeToplevel?.appId ?? "");
        close();
        Quickshell.execDetached(["sh", "-c", `cliphist decode "$1" | wl-copy && sleep 0.15 && wtype -M ctrl ${term ? "-M shift -k v -m shift" : "-k v"} -m ctrl`, "sh", it.id]);
    }
    // ponytail: «держать» только защищает от сжигания; max-items у cliphist всё равно вытеснит старое
    function hold() {
        const id = cur?.id;
        if (!id) return;
        held = held.includes(id) ? held.filter(h => h !== id) : [...held, id];
        heldFile.setText(held.join("\n"));
    }
    function burn() {
        const it = cur;
        if (!it || held.includes(it.id)) return;
        del.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", it.id]);
    }

    onQueryChanged: turn(0)
    onFilterChanged: turn(0)
    onCurChanged: if (cur) decode.restart()

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const t = l.slice(l.indexOf("\t") + 1);
                    return { id: l.slice(0, l.indexOf("\t")), text: t, type: root.kind(t) };
                });
                root.turn(root.sel);
            }
        }
    }
    Process { id: del; onExited: list.running = true }
    Process {
        id: dec
        stdout: StdioCollector { onStreamFinished: { root.full = text; root.fullId = root.decId; } }
    }
    // пока барабан крутится, не дёргаем cliphist на каждую камору
    Timer {
        id: decode
        interval: 80
        onTriggered: {
            if (!root.cur) return;
            root.decId = root.cur.id;
            dec.exec(["sh", "-c", 'if [ "$2" = image ]; then f="${XDG_RUNTIME_DIR:-/tmp}/demonshot-clip-$1"; [ -s "$f" ] || cliphist decode "$1" > "$f"; printf %s "$f"; else cliphist decode "$1" | head -c 4000; fi',
                "sh", root.cur.id, root.cur.type]);
        }
    }
    FileView {
        id: heldFile
        path: Quickshell.statePath("clip-held")
        printErrors: false
        onLoaded: root.held = text().split("\n").filter(l => l)
    }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "demonshot-clip"

    // ponytail: клик мимо не закрывает — только Esc или хоткей
    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.pit, 0.84)
    }

    // холст макета 1856 в ширину, высота — сколько влезет
    Item {
        id: stage
        readonly property real s: Math.min(root.width / 1856, root.height / 1080)
        readonly property real cy: height / 2
        width: 1856
        height: root.height / s
        scale: s
        transformOrigin: Item.TopLeft

        // колесо: щелчок на каждые 120 (тачпад шлёт мелкими порциями)
        WheelHandler {
            property real acc: 0
            onWheel: e => {
                acc += e.angleDelta.y;
                while (Math.abs(acc) >= 120) {
                    root.turn(root.sel + (acc < 0 ? 1 : -1));
                    acc -= Math.sign(acc) * 120;
                }
            }
        }

        Outline {
            x: -4
            y: stage.cy + 20
            rotation: -6
            text: Theme.roman(root.sel + 1)
            font { family: Theme.frak; pixelSize: 300 }
            color: Theme.fade(Theme.bone, 0.09)
            stroke: 1
            layer.enabled: true
            layer.effect: Glitch {}
        }

        // шапка — та же, что у лаунчера: метка, ввод-фильтр, режимы
        Item {
            x: 76
            width: 612
            Text {
                y: 56
                text: "LOADED<"
                font { family: Theme.mono; pixelSize: 22; weight: Font.Bold; letterSpacing: 3 }
                color: Theme.bone
            }
            Item {
                id: field
                y: 112
                width: parent.width
                height: 76
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1.5; color: Theme.bone }
                Text {
                    id: mark
                    anchors.verticalCenter: parent.verticalCenter
                    text: "☾"
                    font { family: Theme.goth; pixelSize: 36 }
                    color: Theme.rose
                }
                TextInput {
                    id: input
                    anchors { left: mark.right; leftMargin: 18; right: parent.right; verticalCenter: parent.verticalCenter }
                    font { family: Theme.goth; pixelSize: 54 }
                    color: Theme.bone
                    selectionColor: Theme.plum
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 22
                        height: 46
                        y: 8
                        color: Theme.bone
                        SequentialAnimation on opacity {
                            running: root.visible // делегат живёт и при скрытом окне
                            loops: Animation.Infinite
                            PropertyAction { value: 1 }
                            PauseAnimation { duration: 500 }
                            PropertyAction { value: 0.25 }
                            PauseAnimation { duration: 500 }
                        }
                    }

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Up || ctrl && e.key === Qt.Key_K) root.turn(root.sel - 1);
                        else if (e.key === Qt.Key_Down || ctrl && e.key === Qt.Key_J) root.turn(root.sel + 1);
                        else if (e.key === Qt.Key_Tab) root.hold();
                        else if (e.key === Qt.Key_Backtab) root.filter = (root.filter + 1) % 4;
                        else if (e.key === Qt.Key_Delete) root.burn();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                        else if (e.key === Qt.Key_Escape) root.close();
                        else return;
                        e.accepted = true;
                    }
                }
            }
            Row {
                id: tabs
                y: field.y + field.height + 18
                spacing: 28
                Repeater {
                    model: root.filters
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData.toUpperCase()
                        font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                        color: index === root.filter ? Theme.bone : Theme.ash
                        Rectangle { visible: index === root.filter; y: parent.height + 3; width: parent.width - 3; height: 2; color: Theme.rose }
                        MouseArea { anchors.fill: parent; onClicked: root.filter = index }
                    }
                }
            }
            Text {
                anchors { right: parent.right; verticalCenter: tabs.verticalCenter }
                text: `${Theme.roman(Math.min(13, root.view.length)).toLowerCase()} of ${root.view.length}`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 2 }
                color: Theme.ash
            }
        }

        // превью выбранной записи: влетает от ствола
        Column {
            id: pv
            x: 76 + root.pvS
            y: stage.cy - height / 2
            width: 860
            spacing: 24
            opacity: 1 - root.pvS / 220
            visible: root.cur !== null

            Text {
                textFormat: Text.StyledText
                text: root.cur ? `${Theme.roman(root.sel + 1)} · ${root.cur.type} · ${root.ty[4]}`
                    + (root.held.includes(root.cur.id) ? ` · <font color="${Theme.rose}">☾ held</font>` : "") : ""
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3; capitalization: Font.AllUppercase }
                color: Theme.ash
            }
            Loader {
                width: pv.width
                sourceComponent: ({ text: textPv, code: codePv, link: linkPv, color: colorPv, image: imagePv, file: filePv })[root.cur?.type ?? "text"]
            }
        }

        Column {
            x: 76
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            spacing: 8
            visible: root.cur !== null
            Text { text: root.ty[3]; color: Theme.bone; font.family: Theme.goth; font.pixelSize: 34 }
            Text {
                text: `${root.ty[1]} · ${root.ty[2]} — ${root.ty[4]}`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                color: Theme.ash
            }
        }

        // ствол: тонкая Crimson-черта от превью до барабана
        Rectangle {
            x: 980
            y: stage.cy - 1
            width: stage.width + 60 - root.bigR - x
            height: 2
            color: Theme.crimson
            Rectangle { x: -14; y: -4; width: 9; height: 9; rotation: 45; color: "transparent"; border { width: 1.5; color: Theme.crimson } }
        }

        // барабан: центр за правым краем, видна левая половина
        Item {
            id: drum
            x: stage.width + 60 + 460 * root.enter
            y: stage.cy

            NumberAnimation {
                id: drumIn
                target: root; property: "enter"
                from: 1; to: 0
                duration: 700
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
            }


            Item {
                id: spin
                property real a: root.angle
                Behavior on a { NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }
                rotation: a - 160 * root.enter

                // контур барабана: дуги по краю, между каморами — долы, полукруглые выемки r=48
                Shape {
                    z: -1
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Theme.crypt
                        strokeColor: Theme.wine
                        strokeWidth: 3
                        PathSvg {
                            path: {
                                const R = root.bigR, f = 48, al = 2 * Math.asin(f / 2 / R), pt = a => `${R * Math.cos(a)} ${R * Math.sin(a)}`;
                                let d = "";
                                for (let j = 0; j < 13; j++) {
                                    const c = (180 + (j + 0.5) * root.step) * Math.PI / 180, n = c + root.step * Math.PI / 180;
                                    d += (j ? "" : `M ${pt(c - al)} `) + `A ${f} ${f} 0 0 0 ${pt(c + al)} A ${R} ${R} 0 0 1 ${pt(n - al)} `;
                                }
                                return d + "Z";
                            }
                        }
                    }
                }

                Rectangle {
                    x: -root.bigR + 36; y: x
                    width: (root.bigR - 36) * 2; height: width; radius: width / 2
                    color: "transparent"
                    border { width: 1; color: Theme.fade(Theme.bone, 0.07) }
                }

                // храповик экстрактора и ось
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Theme.wine
                        strokeColor: Theme.fade(Theme.bone, 0.12)
                        strokeWidth: 1
                        PathPolyline {
                            path: {
                                const p = [], r = d => d * Math.PI / 180;
                                for (let j = 0; j <= 13; j++) {
                                    const a = r(j * root.step), b = r((j + 0.1) * root.step);
                                    p.push(Qt.point(118 * Math.cos(a), 118 * Math.sin(a)), Qt.point(82 * Math.cos(b), 82 * Math.sin(b)));
                                }
                                return p;
                            }
                        }
                    }
                }
                Rectangle { x: -24; y: -24; width: 48; height: 48; radius: 24; color: Theme.void_; border { width: 4; color: Theme.bone } }
                Rectangle { x: -13; y: -13; width: 26; height: 26; radius: 13; color: "transparent"; border { width: 1.5; color: Theme.bone } }

                Repeater {
                    model: 13
                    Item {
                        id: k
                        required property int index
                        readonly property int e: root.at(index)
                        readonly property var it: root.view[e] ?? null
                        readonly property int d: Math.abs(e - root.sel)
                        readonly property bool on: d === 0 && it !== null
                        readonly property bool isHeld: it !== null && root.held.includes(it.id)
                        rotation: 180 - index * root.step

                        // фиксатор: прорезь на краю напротив каморы
                        Rectangle { x: root.bigR - 30; y: -6; width: 16; height: 12; color: Theme.void_ }

                        Rectangle {
                            x: root.chR - 75; y: -75
                            width: 150; height: 150; radius: 75
                            color: Theme.void_
                            border { width: 2; color: Theme.wine }

                            // донце гильзы; повёрнуто так, чтобы у ствола клеймо читалось прямо
                            Rectangle {
                                visible: k.it !== null
                                anchors.centerIn: parent
                                width: 124; height: 124; radius: 62
                                rotation: 180
                                color: k.on ? Theme.crimson : Theme.crypt
                                border { width: k.on || k.isHeld ? 3 : 1.5; color: k.on ? Theme.bone : k.isHeld ? Theme.rose : Theme.ash }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 100; height: 100; radius: 50
                                    color: "transparent"
                                    border { width: 1; color: k.isHeld ? Theme.rose : k.on ? Theme.fade(Theme.bone, 0.5) : Theme.wine }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 17
                                    text: k.it ? root.types[k.it.type][5] : ""
                                    font { family: Theme.mono; pixelSize: 9; letterSpacing: 2 }
                                    color: k.on ? Theme.bone : Theme.ash
                                }
                                Text {
                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
                                    text: Theme.roman(k.e + 1)
                                    font { family: Theme.goth; pixelSize: 14 }
                                    color: k.on ? Theme.bone : Theme.ash
                                }
                                // капсюль; иконка всегда стоит прямо, барабан крутится под ней
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 54; height: 54; radius: 27
                                    color: Theme.void_
                                    border { width: k.on ? 3 : 1.5; color: k.on ? Theme.bone : Theme.dim }
                                    Text {
                                        anchors.centerIn: parent
                                        rotation: -(k.rotation + spin.rotation + 180)
                                        text: k.it ? root.types[k.it.type][0] : ""
                                        font { family: Theme.mono; pixelSize: 24 }
                                        color: k.on ? Theme.bone : Theme.ash
                                    }
                                }
                            }
                            MouseArea { anchors.fill: parent; enabled: k.it !== null; onClicked: k.on ? root.fire() : root.turn(k.e) }
                        }

                        // подпись за краем барабана; развёрнута на 180°, чтобы у ствола читалась прямо и прижималась к барабану
                        Item {
                            x: root.bigR + 30; y: -15
                            width: 460; height: 30
                            rotation: 180
                            visible: k.it !== null
                            opacity: [0, 0.9, 0.55, 0.25][k.d] ?? 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Row {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: k.it ? root.label(k.it) : ""
                                    font { family: Theme.mono; pixelSize: 15 }
                                    color: Theme.pale
                                }
                                Text {
                                    visible: k.isHeld
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "☾"
                                    font { family: Theme.goth; pixelSize: 20 }
                                    color: Theme.rose
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Theme.roman(k.e + 1)
                                    font { family: Theme.goth; pixelSize: 20 }
                                    color: Theme.ash
                                }
                            }
                            MouseArea { anchors.fill: parent; enabled: k.d > 0 && k.d < 4; onClicked: root.turn(k.e) }
                        }
                    }
                }
            }
        }

        Text {
            anchors { right: parent.right; rightMargin: 60; bottom: parent.bottom; bottomMargin: 44 }
            textFormat: Text.StyledText
            text: `<font color="${Theme.bone}">↑↓</font> КРУТИТЬ · <font color="${Theme.bone}">⏎</font> ВЫСТРЕЛ · <font color="${Theme.bone}">TAB</font> ДЕРЖАТЬ · `
                + `<font color="${Theme.bone}">⇧TAB</font> РЕЖИМ · <font color="${Theme.bone}">DEL</font> СЖЕЧЬ · <font color="${Theme.bone}">ESC</font> ЗАКРЫТЬ`
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 3 }
            color: Theme.ash
        }

        NumberAnimation {
            id: pvIn
            target: root; property: "pvS"
            from: 220; to: 0
            duration: Theme.hit
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
        }
    }

    component Sub: Text {
        width: parent?.width ?? 0
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 3
        elide: Text.ElideRight
        font { family: Theme.mono; pixelSize: 16 }
        color: Theme.rose
    }
    component Big: Text {
        width: parent?.width ?? 0
        elide: Text.ElideRight
        font { family: Theme.goth; pixelSize: 72; weight: Font.Bold }
        color: Theme.bone
    }

    Component {
        id: textPv
        Text {
            text: `«${root.body.trim()}»`
            wrapMode: Text.Wrap
            maximumLineCount: 7
            elide: Text.ElideRight
            font { family: Theme.goth; pixelSize: 50 }
            lineHeight: 1.08
            color: Theme.bone
        }
    }
    Component {
        id: codePv
        Rectangle {
            height: code.height + 44
            color: Theme.crypt
            Rectangle { width: 3; height: parent.height; color: Theme.crimson }
            Text {
                id: code
                x: 26; y: 22
                width: parent.width - 52
                text: root.body.replace(/\s+$/, "")
                textFormat: Text.PlainText
                maximumLineCount: 14
                elide: Text.ElideRight
                font { family: Theme.mono; pixelSize: 18 }
                lineHeight: 1.3
                color: Theme.pale
            }
        }
    }
    Component {
        id: linkPv
        Column {
            spacing: 14
            Big { text: root.body.match(/^\w+:\/\/([^\/?#]+)/)?.[1] ?? root.body }
            Sub { text: root.body.trim() }
        }
    }
    Component {
        id: colorPv
        Row {
            readonly property color c: root.body.trim()
            spacing: 48
            Rectangle {
                width: 256; height: 256
                color: "transparent"
                border { width: 1; color: Theme.wine }
                Rectangle { x: 9; y: 9; width: 238; height: 238; color: parent.parent.c }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                Big { width: 560; text: root.body.trim().toUpperCase(); font.pixelSize: 110 }
                Sub { width: 560; text: `rgb ${[c.r, c.g, c.b].map(v => Math.round(v * 255)).join(" ")}` }
            }
        }
    }
    Component {
        id: imagePv
        // пиксельной миниатюрой: грузим в 5 раз мельче и растягиваем без сглаживания
        Rectangle {
            readonly property var wh: (root.cur?.text.match(/(\d+)x(\d+) \]\]$/) ?? [0, 16, 9]).slice(1).map(Number)
            width: img.width + 18
            height: img.height + 18
            color: "transparent"
            border { width: 1; color: Theme.wine }
            Image {
                id: img
                x: 9; y: 9
                height: Math.min(380, 840 * parent.wh[1] / parent.wh[0])
                width: height * parent.wh[0] / parent.wh[1]
                source: root.fullId === root.cur?.id ? "file://" + root.full : ""
                sourceSize: Qt.size(Math.round(width / 5), Math.round(height / 5))
                fillMode: Image.PreserveAspectCrop
                smooth: false
                // декод PNG в UI-потоке подвешивал барабан; миниатюры мелкие — кэш дешёвый
                asynchronous: true
            }
        }
    }
    Component {
        id: filePv
        Row {
            spacing: 30
            PixelIcon { anchors.verticalCenter: parent.verticalCenter; size: 96; text: root.types.file[0] }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 700
                spacing: 14
                Big { text: root.body.trim().replace(/\/$/, "").split("/").pop(); font.pixelSize: 60 }
                Sub { text: root.body.trim() }
            }
        }
    }
}
