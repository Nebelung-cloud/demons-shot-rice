import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// правка снимка: тот же стол, что у прицела — снимок в видоискателе с Rose-уголками, инструменты — фишки.
// Метки живут в пикселях снимка; ⏎ запекает их поверх файла (grabToImage сцены в родном размере) и кладёт в буфер
Scope {
    id: root

    readonly property var tools: ["Pen", "Arrow", "Frame", "Veil", "Word"]
    readonly property var hotkeys: [Qt.Key_P, Qt.Key_A, Qt.Key_R, Qt.Key_B, Qt.Key_T]
    readonly property var inks: [Theme.crimson, Theme.rose, Theme.bone, Theme.void_]
    readonly property var sizes: [3, 6, 12] // толщина в логических пикселях; в снимке — × dpr

    property string shot: ""
    property int n: 0
    property var scr: null
    property int tool: 0
    property int ink: 0
    property int size: 1
    property var marks: []  // { k: "pen", c, w, pts } · { k: "arrow" | "frame" | "veil", c, w, x1, y1, x2, y2 } · { k: "word", c, s, x, y, t }
    property var live: null // метка, которую тянут прямо сейчас
    readonly property real dpr: scr?.devicePixelRatio ?? 1
    readonly property real w: sizes[size] * dpr

    function open(path, screen, num) {
        shot = path;
        scr = screen;
        n = num;
        marks = [];
        live = null;
        typing.visible = false;
        win.visible = true;
        land.restart();
        keys_.forceActiveFocus();
    }
    function close() { win.visible = false; }

    function commitWord() {
        if (!typing.visible) return;
        if (typing.text.trim())
            marks = marks.concat([{ k: "word", c: inks[ink], s: typing.font.pixelSize, x: typing.x, y: typing.y, t: typing.text }]);
        typing.visible = false;
        keys_.forceActiveFocus();
    }

    function save() {
        commitWord();
        // ponytail: снимок перезаписывается; оригинал рядом — если захочется откатывать правки
        stage.grabToImage(r => {
            if (!r.saveToFile(root.shot)) return;
            Quickshell.execDetached(["sh", "-c", 'wl-copy -t image/png < "$1"', "sh", root.shot]);
            root.close();
        }, Qt.size(img.implicitWidth, img.implicitHeight));
    }

    PanelWindow {
        id: win
        screen: root.scr
        visible: false
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "demonshot-shot-edit"

        Rectangle { anchors.fill: parent; color: Theme.void_; opacity: 0.94 }
        Glow {
            cx: parent.width / 2; cy: parent.height / 2
            rx: parent.width * 0.6; ry: parent.height * 0.6
            color: "transparent"
            fade: 0.5
            edge: Theme.fade(Theme.crimson, 0.14)
        }

        // видоискатель: снимок вписан между шапкой и фишками, крупнее 1:1 не растёт
        Item {
            id: frame
            readonly property real fit: Math.min(1 / root.dpr, (win.width - 64 - 240) / Math.max(1, img.implicitWidth),
                                                 (win.height - 150 - 220) / Math.max(1, img.implicitHeight))
            width: img.implicitWidth * fit
            height: img.implicitHeight * fit
            x: 64 + (win.width - 64 - width) / 2 // правее бара
            y: 150 + (win.height - 150 - 220 - height) / 2

            Item {
                id: stage
                width: img.implicitWidth
                height: img.implicitHeight
                scale: frame.fit
                transformOrigin: Item.TopLeft

                Image {
                    id: img
                    source: root.shot ? "file://" + root.shot : ""
                    cache: false // после сохранения тот же путь — перечитать
                    smooth: true
                    mipmap: true
                }
                Repeater {
                    // живая метка — последней; её делегат пересоздаётся на каждый шаг мыши, остальные — только при фиксации
                    model: root.marks
                    Mark { required property var modelData; m: modelData; src: img }
                }
                Repeater {
                    model: root.live ? [root.live] : []
                    Mark { required property var modelData; m: modelData; src: img }
                }

                TextInput {
                    id: typing
                    visible: false
                    font { family: Theme.goth; pixelSize: root.w * 6 }
                    color: root.inks[root.ink]
                    selectionColor: Theme.plum
                    cursorDelegate: Rectangle { width: 2 * root.dpr; color: Theme.crimson }
                    onAccepted: root.commitWord()
                    Keys.onEscapePressed: { visible = false; keys_.forceActiveFocus(); }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.tool === 4 ? Qt.IBeamCursor : Qt.CrossCursor
                    onPressed: e => {
                        root.commitWord();
                        const c = root.inks[root.ink];
                        if (root.tool === 0) root.live = { k: "pen", c, w: root.w, pts: [Qt.point(e.x, e.y)] };
                        else if (root.tool === 4) {
                            typing.text = "";
                            typing.x = e.x;
                            typing.y = e.y - typing.height / 2;
                            typing.visible = true;
                            typing.forceActiveFocus();
                        } else root.live = { k: ["", "arrow", "frame", "veil"][root.tool], c, w: root.w, x1: e.x, y1: e.y, x2: e.x, y2: e.y };
                    }
                    onPositionChanged: e => {
                        const l = root.live;
                        if (!l) return;
                        // ponytail: штрих копируется на каждый шаг — O(n²), хватает на штрихи в тысячи точек
                        if (l.k === "pen") root.live = Object.assign({}, l, { pts: l.pts.concat([Qt.point(e.x, e.y)]) });
                        else root.live = Object.assign({}, l, { x2: e.x, y2: e.y });
                    }
                    onReleased: {
                        const l = root.live;
                        root.live = null;
                        if (l && (l.k === "pen" ? l.pts.length > 1 : Math.hypot(l.x2 - l.x1, l.y2 - l.y1) > 4 * root.dpr))
                            root.marks = root.marks.concat([l]);
                    }
                }
            }

            // рамка и уголки — как у прицела
            Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border { width: 1; color: Theme.fade(Theme.bone, 0.45) } }
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
                text: "INK<"
                font { family: Theme.mono; pixelSize: 22; weight: Font.Bold; letterSpacing: 3 }
                color: Theme.bone
            }
            Row {
                anchors { right: parent.right; rightMargin: -7; bottom: parent.top; bottomMargin: 14 }
                spacing: 16
                Text {
                    anchors.baseline: dims.baseline
                    text: `${root.marks.length} ${root.marks.length === 1 ? "mark" : "marks"}`
                    font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                    color: Theme.ash
                }
                Text {
                    id: dims
                    textFormat: Text.StyledText
                    text: `${img.implicitWidth} <font color="${Theme.rose}">×</font> ${img.implicitHeight}`
                    font { family: Theme.goth; pixelSize: 40 }
                    color: Theme.bone
                }
            }

            // влетает, как карта: с её наклона и со slam
            ParallelAnimation {
                id: land
                NumberAnimation { target: frame; property: "rotation"; from: 7; to: 0; duration: Theme.hit * 2; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                NumberAnimation { target: frame; property: "scale"; from: 0.6; to: 1; duration: Theme.hit * 2; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam }
                NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1; duration: Theme.hit }
            }
        }

        Text {
            anchors { right: parent.right; rightMargin: 60; top: parent.top; topMargin: 44 }
            text: `${Theme.roman((root.n - 1) % 13 + 1).toLowerCase()} of xiii · mark the shot`
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 4.4 }
            color: Theme.rose
        }

        // инструменты — фишки; справа чернила ромбами и толщина точками
        Row {
            x: (win.width + 64 - width) / 2
            anchors { bottom: parent.bottom; bottomMargin: 100 }
            spacing: 46
            Repeater {
                model: root.tools
                Chip {
                    required property string modelData
                    text: modelData
                    on: index === root.tool
                    onClicked: { root.commitWord(); root.tool = index; }
                }
            }
            Rectangle { width: 1; height: 44; color: Theme.dim }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                Repeater {
                    model: root.inks
                    Rectangle {
                        required property color modelData
                        required property int index
                        readonly property bool on: index === root.ink
                        anchors.verticalCenter: parent.verticalCenter
                        width: on ? 20 : 14; height: width
                        rotation: 45
                        color: modelData
                        border { width: on ? 2 : 1; color: on ? Theme.bone : Theme.ash }
                        Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.ink = index }
                    }
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Repeater {
                    model: root.sizes
                    Rectangle {
                        required property int modelData
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: modelData + 4; height: width; radius: width / 2
                        color: index === root.size ? Theme.bone : Theme.dim
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.size = index }
                    }
                }
            }
        }

        Text {
            x: (win.width + 64 - width) / 2
            anchors { bottom: parent.bottom; bottomMargin: 44 }
            textFormat: Text.StyledText
            readonly property string b: `<font color="${Theme.bone}">`
            text: `${b}P A R B T</font> ИНСТРУМЕНТ · ${b}1–4</font> ЧЕРНИЛА · ${b}[ ]</font> ТОЛЩИНА · ${b}CTRL+Z</font> НАЗАД`
                + ` · ${b}⏎</font> ЗАПЕЧЬ В БУФЕР · ${b}ESC</font> БРОСИТЬ`
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 3 }
            color: Theme.ash
        }

        Item {
            id: keys_
            focus: true
            Keys.onPressed: e => {
                const t = root.hotkeys.indexOf(e.key);
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (e.key === Qt.Key_S && e.modifiers & Qt.ControlModifier)) root.save();
                else if (e.key === Qt.Key_Z && e.modifiers & Qt.ControlModifier) root.marks = root.marks.slice(0, -1);
                else if (t >= 0) root.tool = t;
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) root.ink = e.key - Qt.Key_1;
                else if (e.key === Qt.Key_BracketLeft) root.size = Math.max(0, root.size - 1);
                else if (e.key === Qt.Key_BracketRight) root.size = Math.min(2, root.size + 1);
                else return;
                e.accepted = true;
            }
        }
    }

    // одна метка в пикселях снимка
    component Mark: Item {
        id: mk
        property var m
        property Item src // снимок для вуали: id файла внутрь inline-компонента не видны
        readonly property real x0: Math.min(m.x1, m.x2)
        readonly property real y0: Math.min(m.y1, m.y2)
        readonly property real w0: Math.abs(m.x2 - m.x1)
        readonly property real h0: Math.abs(m.y2 - m.y1)

        Loader {
            sourceComponent: ({ pen: pen, arrow: arrow, frame: frameC, veil: veil, word: word })[mk.m.k]
        }

        Component {
            id: pen
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mk.m.c
                    strokeWidth: mk.m.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: mk.m.pts }
                }
            }
        }
        Component {
            id: arrow
            Shape {
                id: ar
                // наконечник — треугольник длиной 4 толщины, древко до его основания
                readonly property real a: Math.atan2(mk.m.y2 - mk.m.y1, mk.m.x2 - mk.m.x1)
                readonly property real hl: mk.m.w * 4
                readonly property point base: Qt.point(mk.m.x2 - Math.cos(a) * hl * 0.8, mk.m.y2 - Math.sin(a) * hl * 0.8)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mk.m.c
                    strokeWidth: mk.m.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: [Qt.point(mk.m.x1, mk.m.y1), ar.base] }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: mk.m.c
                    PathPolyline {
                        path: [Qt.point(mk.m.x2, mk.m.y2),
                               Qt.point(mk.m.x2 - Math.cos(ar.a - 0.45) * ar.hl, mk.m.y2 - Math.sin(ar.a - 0.45) * ar.hl),
                               Qt.point(mk.m.x2 - Math.cos(ar.a + 0.45) * ar.hl, mk.m.y2 - Math.sin(ar.a + 0.45) * ar.hl),
                               Qt.point(mk.m.x2, mk.m.y2)]
                    }
                }
            }
        }
        Component {
            id: frameC
            Rectangle {
                x: mk.x0 - mk.m.w / 2; y: mk.y0 - mk.m.w / 2
                width: mk.w0 + mk.m.w; height: mk.h0 + mk.m.w
                color: "transparent"
                border { width: mk.m.w; color: mk.m.c }
            }
        }
        // вуаль: кусок снимка крупными пикселями — пароли, лица, адреса
        Component {
            id: veil
            ShaderEffectSource {
                readonly property real px: mk.m.w * 3
                x: mk.x0; y: mk.y0
                width: mk.w0; height: mk.h0
                sourceItem: mk.src
                sourceRect: Qt.rect(mk.x0, mk.y0, mk.w0, mk.h0)
                textureSize: Qt.size(Math.max(1, Math.ceil(mk.w0 / px)), Math.max(1, Math.ceil(mk.h0 / px)))
                smooth: false
            }
        }
        Component {
            id: word
            Text {
                x: mk.m.x; y: mk.m.y
                text: mk.m.t
                font { family: Theme.goth; pixelSize: mk.m.s }
                color: mk.m.c
                style: Text.Outline
                styleColor: Theme.void_
            }
        }
    }
}
