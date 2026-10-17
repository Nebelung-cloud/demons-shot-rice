import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// скриншот: экран замирает (grim в файл, кадр под оверлеем), область берётся в видоискатель с сеткой третей,
// у курсора лупа ×14 с цветом пикселя. Выстрел: край вспыхивает Crimson, снимок уже в буфере и падает картой в угол,
// клик по карте — правка (Editor)
Scope {
    id: root

    readonly property var modes: ["Region", "Window", "Screen", "Record"]
    readonly property var delays: [0, 3, 13]
    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    property int mode: 0
    property int delay: 0
    property int count: 0       // снимков в папке — «vii of xiii shots»
    property string frozen: ""
    property var scr: null
    property var wins: []       // окна текущего ws в координатах экрана: { x, y, w, h }
    // выделение в координатах экрана; w = 0 — ничего не выбрано
    property rect drag: Qt.rect(0, 0, 0, 0)
    property real mx: 0
    property real my: 0
    readonly property var hover: wins.find(w => mx >= w.x && mx < w.x + w.w && my >= w.y && my < w.y + w.h) ?? null
    readonly property rect sel: mode === 2 ? Qt.rect(0, 0, aim.width, aim.height)
        : mode === 1 ? (hover ? Qt.rect(hover.x, hover.y, hover.w, hover.h) : Qt.rect(0, 0, 0, 0))
        : drag
    readonly property real k: frozenImg.sourceSize.width / Math.max(1, aim.width) // логические → физические

    // последний снимок: для карты
    property string shot: ""
    property string shotWhat: ""
    property int shotN: 0

    function roman(n) { return Theme.roman(n).toLowerCase(); }

    function open() {
        if (aim.visible) return;
        const mon = Hyprland.focusedMonitor;
        scr = Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0];
        Hyprland.refreshToplevels();
        picker.unloadImage(frozenImg.source); // холст держит кадр в памяти, пока не выгрузим
        freeze.next = `${run}/demonshot-frozen-${Date.now()}.ppm`; // ponytail: ppm без сжатия — grim 90 мс против 450 у png
        freeze.exec(["sh", "-c", 'rm -f "$3"/demonshot-frozen-*; grim -t ppm -o "$1" "$2" && ls "$(xdg-user-dir PICTURES)/shots" 2>/dev/null | wc -l',
            "sh", scr.name, freeze.next, run]);
    }
    function close() { aim.visible = false; }

    function fire() {
        const r = sel.width > 2 && sel.height > 2 ? sel : Qt.rect(0, 0, aim.width, aim.height);
        const full = r.width === aim.width && r.height === aim.height;
        shotWhat = `${["region", "window", "screen", "record"][mode]} · ${Math.round(r.width)} × ${Math.round(r.height)}`;
        const geo = `${Math.round(scr.x + r.x)},${Math.round(scr.y + r.y)} ${Math.round(r.width)}x${Math.round(r.height)}`;
        close();
        if (mode === 3) {
            const w = full ? `-w ${scr.name}` : `-w region -region ${Math.round(r.width)}x${Math.round(r.height)}+${Math.round(scr.x + r.x)}+${Math.round(scr.y + r.y)}`;
            Quickshell.execDetached(["sh", "-c", `sleep ${delay}; notify-send -a "shot · rec" "Recording." "ctrl+alt+r — стоп"; `
                + `gpu-screen-recorder ${w} -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"`]);
            return;
        }
        // без таймера режем замёрзший кадр — что видел, то и снял; с таймером снимаем живой экран
        // vips, в отличие от magick, падает на рамке за краем кадра на пиксель — дробный масштаб, поэтому зажимаем
        const x = Math.round(r.x * k), y = Math.round(r.y * k);
        const crop = `${x} ${y} ${Math.min(Math.round(r.width * k), frozenImg.sourceSize.width - x)} ${Math.min(Math.round(r.height * k), frozenImg.sourceSize.height - y)}`;
        take.exec(["sh", "-c", `d="$(xdg-user-dir PICTURES)/shots"; mkdir -p "$d"; f="$d/shot-$(date +%F_%H-%M-%S).png"
            if [ "$1" = 0 ]; then vips crop "$4" "$f[compression=1]" $2 2>/dev/null; else sleep "$1"; grim -g "$3" "$f"; fi \
                && wl-copy -t image/png < "$f" && printf '%s\\n%s' "$f" "$(ls "$d" | wc -l)"`,
            "sh", String(delay), crop, geo, frozen]);
    }

    Process {
        id: freeze
        property string next
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                root.frozen = freeze.next; // только теперь: файл дописан
                root.count = parseInt(text);
                root.mode = 0;
                root.drag = Qt.rect(0, 0, 0, 0);
                root.wins = Hyprland.toplevels.values
                    .filter(t => t.workspace?.id === Hyprland.focusedMonitor?.activeWorkspace?.id && t.lastIpcObject?.size)
                    .sort((a, b) => (b.lastIpcObject.floating ?? false) - (a.lastIpcObject.floating ?? false)) // плавающие сверху
                    .map(t => ({ x: t.lastIpcObject.at[0] - root.scr.x, y: t.lastIpcObject.at[1] - root.scr.y,
                                 w: t.lastIpcObject.size[0], h: t.lastIpcObject.size[1] }));
                aim.visible = true;
                keys.forceActiveFocus();
            }
        }
    }
    Process {
        id: take
        stdout: StdioCollector {
            onStreamFinished: {
                const [f, n] = text.split("\n");
                if (!f) return;
                root.shot = f;
                root.shotN = parseInt(n) || 1;
                fired.visible = true;
                fall.restart();
            }
        }
    }

    Editor { id: editor }

    // ============ прицел ============
    PanelWindow {
        id: aim
        screen: root.scr
        visible: false
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "demonshot-shot"

        Image {
            id: frozenImg
            anchors.fill: parent
            source: root.frozen ? "file://" + root.frozen : "" // кэш общий с лупой и пипеткой: кадр декодится раз, не трижды
        }

        // всё вне рамки гаснет; пока рамки нет — гаснет слегка
        Item {
            anchors.fill: parent
            readonly property color c: Theme.fade(Theme.pit, root.sel.width ? 0.74 : 0.35)
            readonly property rect r: root.sel.width ? root.sel : Qt.rect(0, 0, 0, 0)
            Rectangle { width: parent.width; height: parent.r.y; color: parent.c }
            Rectangle { y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: parent.c }
            Rectangle { y: parent.r.y; width: parent.r.x; height: parent.r.height; color: parent.c }
            Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: parent.c }
        }

        // перекрестье через весь экран
        Rectangle { y: Math.round(root.my); width: parent.width; height: 1; color: Theme.crimson; opacity: 0.55 }
        Rectangle { x: Math.round(root.mx); width: 1; height: parent.height; color: Theme.crimson; opacity: 0.55 }

        // видоискатель: рамка, сетка третей, уголки Rose
        Item {
            visible: root.sel.width > 0
            x: root.sel.x; y: root.sel.y
            width: root.sel.width; height: root.sel.height

            Rectangle { anchors.fill: parent; color: "transparent"; border { width: 1; color: Theme.fade(Theme.bone, 0.45) } }
            Repeater {
                model: 2
                Item {
                    required property int index
                    anchors.fill: parent
                    Rectangle { x: parent.width * (index + 1) / 3; width: 1; height: parent.height; color: Theme.fade(Theme.bone, 0.12) }
                    Rectangle { y: parent.height * (index + 1) / 3; width: parent.width; height: 1; color: Theme.fade(Theme.bone, 0.12) }
                }
            }
            Repeater {
                model: 4
                Item {
                    required property int index
                    readonly property bool r: index % 2
                    readonly property bool b: index > 1
                    x: r ? parent.width + 7 - 48 : -7
                    y: b ? parent.height + 7 - 48 : -7
                    width: 48; height: 48
                    Rectangle { y: parent.b ? 45 : 0; width: 48; height: 3; color: Theme.rose }
                    Rectangle { x: parent.r ? 45 : 0; width: 3; height: 48; color: Theme.rose }
                }
            }
            Text {
                x: -7
                y: -20 - height
                text: "AIM<"
                font { family: Theme.mono; pixelSize: 22; weight: Font.Bold; letterSpacing: 3 }
                color: Theme.bone
            }
            Row {
                anchors { right: parent.right; rightMargin: -7; bottom: parent.top; bottomMargin: 14 }
                spacing: 16
                Text {
                    anchors.baseline: size.baseline
                    text: `${Math.round(root.sel.width * root.k)}×${Math.round(root.sel.height * root.k)} px`
                    font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                    color: Theme.ash
                }
                Text {
                    id: size
                    textFormat: Text.StyledText
                    text: `${Math.round(root.sel.width)} <font color="${Theme.rose}">×</font> ${Math.round(root.sel.height)}`
                    font { family: Theme.goth; pixelSize: 40 }
                    color: Theme.bone
                }
            }
        }

        // лупа: пиксели под курсором ×14 без сглаживания, снизу координаты и цвет
        Item {
            id: loupe
            readonly property int px: Math.floor(root.mx * root.k)
            readonly property int py: Math.floor(root.my * root.k)
            x: root.mx + 13 + 154 > aim.width ? root.mx - 13 - 154 : root.mx + 13
            y: root.my + 13 + 210 > aim.height ? root.my - 13 - 210 : root.my + 13
            width: 154
            height: 210

            // цвет пикселя: читаем из 1×1 холста, он прячется под лупой
            Canvas {
                id: picker
                property string hex: "#000000"
                x: 77; y: 77
                width: 1; height: 1
                onImageLoaded: requestPaint()
                onPaint: {
                    const g = getContext("2d"), src = frozenImg.source.toString();
                    if (!isImageLoaded(src)) return loadImage(src);
                    g.drawImage(src, loupe.px, loupe.py, 1, 1, 0, 0, 1, 1);
                    const d = g.getImageData(0, 0, 1, 1).data;
                    hex = "#" + [d[0], d[1], d[2]].map(v => v.toString(16).padStart(2, "0")).join("").toUpperCase();
                }
                Connections { target: loupe; function onPxChanged() { picker.requestPaint(); } function onPyChanged() { picker.requestPaint(); } }
            }

            Rectangle { x: -6; y: -6; width: 166; height: 166; radius: 83; color: Theme.void_ }
            Item {
                id: lens
                width: 154; height: 154
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: lensMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }

                Image {
                    source: frozenImg.source
                    smooth: false
                    width: frozenImg.sourceSize.width * 14
                    height: frozenImg.sourceSize.height * 14
                    x: 77 - (loupe.px + 0.5) * 14
                    y: 77 - (loupe.py + 0.5) * 14
                }
                Repeater {
                    model: 11
                    Item {
                        required property int index
                        Rectangle { x: index * 14 + 13; width: 1; height: 154; color: Theme.fade(Theme.pit, 0.6) }
                        Rectangle { y: index * 14 + 13; width: 154; height: 1; color: Theme.fade(Theme.pit, 0.6) }
                    }
                }
                Rectangle { x: 70; width: 14; height: 154; color: Theme.crimson; opacity: 0.25 }
                Rectangle { y: 70; width: 154; height: 14; color: Theme.crimson; opacity: 0.25 }
                Rectangle { x: 68; y: 68; width: 18; height: 18; color: "transparent"; border { width: 2; color: Theme.bone } }
            }
            Rectangle { id: lensMask; width: 154; height: 154; radius: 77; visible: false; layer.enabled: true }
            Rectangle { width: 154; height: 154; radius: 77; color: "transparent"; border { width: 2; color: Theme.bone } }

            Column {
                y: 169
                width: 154
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Math.round(root.mx)} · ${Math.round(root.my)}`
                    font { family: Theme.goth; pixelSize: 20 }
                    color: Theme.bone
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; color: picker.hex; border { width: 1; color: Theme.ash } }
                    Text { text: picker.hex; font { family: Theme.mono; pixelSize: 11; letterSpacing: 2.75 } color: Theme.ash }
                }
            }
        }

        Text {
            anchors { right: parent.right; rightMargin: 60; top: parent.top; topMargin: 44 }
            text: `${root.roman(root.count % 13 + 1)} of xiii shots · can't slow down`
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 4.4 }
            color: Theme.rose
        }

        // низ гаснет под фишками
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.68; color: "transparent" }
                GradientStop { position: 0.85; color: Theme.fade(Theme.pit, 0.96) }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            property point from
            onPositionChanged: e => {
                root.mx = e.x;
                root.my = e.y;
                if (pressed && (root.mode === 0 || root.mode === 3))
                    root.drag = Qt.rect(Math.min(from.x, e.x), Math.min(from.y, e.y), Math.abs(e.x - from.x), Math.abs(e.y - from.y));
            }
            onPressed: e => {
                if (root.mode === 1 || root.mode === 2) return root.fire(); // окно или экран — снимаем по клику
                from = Qt.point(e.x, e.y);
                root.drag = Qt.rect(e.x, e.y, 0, 0);
            }
        }

        // режимы — те же фишки казино, что в алтаре
        Row {
            x: (aim.width + 64 - width) / 2 // по центру стола, правее бара
            anchors { bottom: parent.bottom; bottomMargin: 100 }
            spacing: 46
            Repeater {
                model: root.modes
                Chip {
                    required property string modelData
                    text: modelData
                    on: index === root.mode
                    onClicked: root.mode = index
                }
            }
        }

        Text {
            x: (aim.width + 64 - width) / 2
            anchors { bottom: parent.bottom; bottomMargin: 44 }
            textFormat: Text.StyledText
            readonly property string b: `<font color="${Theme.bone}">`
            text: `${b}DRAG</font> ОБЛАСТЬ · ${b}SPACE</font> ОКНО · ${b}TAB</font> РЕЖИМ · ${b}T</font> ТАЙМЕР `
                + root.delays.map((d, i) => i === root.delay ? `${b}${Theme.roman(d)}</font>` : Theme.roman(d)).join("·")
                + ` · ${b}⏎</font> ВЫСТРЕЛ · ${b}ESC</font> ОТМЕНА`
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 3 }
            color: Theme.ash
        }

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                else if (e.key === Qt.Key_Space) root.mode = 1;
                else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                else if (e.key === Qt.Key_T) root.delay = (root.delay + 1) % 3;
                else return;
                e.accepted = true;
            }
        }
    }

    // ============ выстрел: вспышка по краю, снимок падает картой ============
    PanelWindow {
        id: fired
        screen: root.scr
        visible: false
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: card } // мимо карты клики проходят насквозь
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "demonshot-shot-fired"

        Item {
            id: body
            anchors.fill: parent

            Item {
                id: flash
                anchors.fill: parent
                Rectangle { anchors.fill: parent; color: "transparent"; border { width: 3; color: Theme.crimson } }
                Glow {
                    cx: parent.width / 2; cy: parent.height / 2
                    rx: parent.width * 0.72; ry: parent.height * 0.72
                    color: "transparent"
                    fade: 0.6
                    edge: Theme.fade(Theme.crimson, 0.32)
                }
            }

            Card {
                id: card
                x: fired.width - 150 - width
                scale: 1.12
                transformOrigin: Item.TopLeft
                up: true
                seed: root.shotN
                raysY: 0.34
                num: Theme.roman(root.shotN)
                name: "The Hermit"

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 176
                    implicitHeight: 96
                    color: Theme.crypt
                    border { width: 1.5; color: Theme.line }
                    Image {
                        anchors { fill: parent; margins: 1.5 }
                        source: root.shot ? "file://" + root.shot : ""
                        sourceSize: Qt.size(352, 192)
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                }
                Art.T1 { Layout.topMargin: 18; text: root.shotWhat.split(" · ")[1] ?? "" }
                Art.T2 { text: `${root.shotWhat.split(" · ")[0]} · ${Qt.formatTime(new Date(), "hh:mm")}` }
                Art.T2 { text: `${root.roman((root.shotN - 1) % 13 + 1)} of xiii`; color: Theme.rose }

                under: MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { fall.stop(); fadeOut.stop(); fired.visible = false; editor.open(root.shot, root.scr, root.shotN); }
                }
            }
        }

        // падает сверху с кувырком и бьётся в правый верхний угол со slam; через пару секунд гаснет
        SequentialAnimation {
            id: fall
            PropertyAction { target: body; property: "opacity"; value: 1 }
            ParallelAnimation {
                NumberAnimation { target: flash; property: "opacity"; from: 1; to: 0; duration: 1100; easing.type: Easing.OutQuad }
                NumberAnimation { target: card; property: "y"; from: -520; to: 60; duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                NumberAnimation { target: card; property: "rotation"; from: -28; to: 7; duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
            }
            PauseAnimation { duration: 1800 }
            ScriptAction { script: fadeOut.start() }
        }
        SequentialAnimation {
            id: fadeOut
            NumberAnimation { target: body; property: "opacity"; to: 0; duration: 300 }
            PropertyAction { target: fired; property: "visible"; value: false }
        }
    }
}
