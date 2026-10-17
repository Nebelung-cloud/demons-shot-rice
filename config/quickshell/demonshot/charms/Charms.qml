import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import "charms.js" as Data

// чары: каомодзи, эмодзи, ascii-арты, символы и стикеры — картинки из ~/Pictures/stickers.
// ⏎ — в буфер и сразу вставить в окно, как выстрел у Clip
PanelWindow {
    id: root

    readonly property var tabs: ["kaomoji", "emoji", "ascii", "symbols", "stickers"]
    readonly property var cells: [[268, 84], [92, 92], [356, 236], [88, 88], [178, 178]] // ячейка на вкладку
    property int tab: 0
    property int sel: 0
    readonly property string query: input.text.toLowerCase()

    // { t: текст, f: файл стикера, k: по чему искать }
    readonly property var view: {
        const src = tab === 4
            ? Array.from({ length: stickers.count }, (_, i) => ({ f: stickers.get(i, "filePath"), k: stickers.get(i, "fileBaseName") }))
            : [Data.KAOMOJI, Data.EMOJI, Data.ASCII, Data.SYMBOLS][tab].map(([t, k]) => ({ t, k }));
        return src.filter(e => `${e.k} ${e.t ?? ""}`.toLowerCase().includes(query));
    }
    readonly property var cur: view[sel] ?? null

    function go(i) {
        if (view.length) sel = Math.max(0, Math.min(i, view.length - 1));
    }

    function open() {
        input.text = "";
        sel = 0;
        visible = true;
        input.forceActiveFocus();
        enter.restart();
    }
    function close() { visible = false; }
    function toggle() { visible ? close() : open(); }

    function fire() {
        const it = cur;
        if (!it) return;
        // терминалы вставляют по Ctrl+Shift+V
        const term = /kitty|foot|alacritty|wezterm|ghostty|konsole/i.test(ToplevelManager.activeToplevel?.appId ?? "");
        close();
        Quickshell.execDetached(["sh", "-c", `{ if [ -n "$2" ]; then wl-copy < "$2"; else wl-copy -- "$1"; fi; } && sleep 0.15 && wtype -M ctrl ${term ? "-M shift -k v -m shift" : "-k v"} -m ctrl`,
            "sh", it.t ?? "", it.f ?? ""]);
    }

    onQueryChanged: sel = 0
    onTabChanged: { sel = 0; enter.restart(); }
    onSelChanged: grid.positionViewAtIndex(sel, GridView.Contain)

    FolderListModel {
        id: stickers
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/stickers"
        nameFilters: ["*.png", "*.webp", "*.gif", "*.jpg", "*.jpeg"]
        showDirs: false
    }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "demonshot-charms"

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.pit, 0.84)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // холст макета 1856 в ширину, высота — сколько влезет
    Item {
        id: stage
        readonly property real s: Math.min(root.width / 1856, root.height / 1080)
        width: 1856
        height: root.height / s
        scale: s
        transformOrigin: Item.TopLeft

        Outline {
            x: stage.width + 40 - width
            y: stage.height - 380
            rotation: -6
            text: root.tabs[root.tab]
            font { family: Theme.frak; pixelSize: 300 }
            color: Theme.fade(Theme.bone, 0.09)
            stroke: 1
            layer.enabled: true
            layer.effect: Glitch {}
        }

        // шапка — та же, что у лаунчера и буфера
        Item {
            x: 76
            width: 612
            Text {
                y: 56
                text: "HEXED<"
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

                    // ponytail: ←→ ходят по сетке, а не по тексту — запросы тут в одно слово
                    Keys.onPressed: e => {
                        const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
                        if (e.key === Qt.Key_Left) root.go(root.sel - 1);
                        else if (e.key === Qt.Key_Right) root.go(root.sel + 1);
                        else if (e.key === Qt.Key_Up) root.go(root.sel - cols);
                        else if (e.key === Qt.Key_Down) root.go(root.sel + cols);
                        else if (e.key === Qt.Key_Tab) root.tab = (root.tab + 1) % root.tabs.length;
                        else if (e.key === Qt.Key_Backtab) root.tab = (root.tab + root.tabs.length - 1) % root.tabs.length;
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                        else if (e.key === Qt.Key_Escape) root.close();
                        else return;
                        e.accepted = true;
                    }
                }
            }
            Row {
                id: tabRow
                y: field.y + field.height + 18
                spacing: 28
                Repeater {
                    model: root.tabs
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData.toUpperCase()
                        font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                        color: index === root.tab ? Theme.bone : Theme.ash
                        Rectangle { visible: index === root.tab; y: parent.height + 3; width: parent.width - 3; height: 2; color: Theme.rose }
                        MouseArea { anchors.fill: parent; onClicked: root.tab = index }
                    }
                }
            }
            Text {
                anchors { right: parent.right; verticalCenter: tabRow.verticalCenter }
                text: `${Theme.roman(root.sel + 1).toLowerCase()} of ${root.view.length}`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 2 }
                color: Theme.ash
            }
        }

        GridView {
            id: grid
            x: 76
            y: 300
            width: 1104
            height: stage.height - y - 110
            clip: true
            cellWidth: root.cells[root.tab][0]
            cellHeight: root.cells[root.tab][1]
            model: root.view
            opacity: 1 - enter.v
            transform: Translate { y: 60 * enter.v }

            delegate: Item {
                id: d
                required property var modelData
                required property int index
                readonly property bool on: index === root.sel
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors { fill: parent; margins: 6 }
                    color: d.on ? Theme.crimson : Theme.crypt
                    border { width: d.on ? 2 : 1; color: d.on ? Theme.bone : Theme.wine }
                    scale: d.on ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam } }

                    Text {
                        visible: !d.modelData.f
                        anchors { fill: parent; margins: 10 }
                        text: d.modelData.t ?? ""
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 6
                        font { family: Theme.mono; pixelSize: root.tab === 1 || root.tab === 3 ? 40 : 22 }
                        color: Theme.bone
                    }
                    Image {
                        visible: !!d.modelData.f
                        anchors { fill: parent; margins: 10 }
                        source: d.modelData.f ? "file://" + d.modelData.f : ""
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.sel = d.index; root.fire(); }
                    }
                }
            }
        }

        Text {
            x: 76
            y: 300
            visible: root.tab === 4 && stickers.count === 0
            text: "пусто — кинь картинки в ~/Pictures/stickers"
            font { family: Theme.goth; pixelSize: 34 }
            color: Theme.ash
        }

        // превью выбранного: крупно справа от сетки
        Column {
            x: 1260
            y: 300
            width: 520
            spacing: 24
            visible: root.cur !== null
            Text {
                text: `${Theme.roman(root.sel + 1)} · ${root.tabs[root.tab]}` + (root.cur?.k ? ` · ${root.cur.k.split(" ")[0]}` : "")
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3; capitalization: Font.AllUppercase }
                color: Theme.ash
            }
            Rectangle {
                width: parent.width
                height: 520
                color: "transparent"
                border { width: 1; color: Theme.wine }
                Text {
                    visible: !root.cur?.f
                    anchors { fill: parent; margins: 28 }
                    text: root.cur?.t ?? ""
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                    font { family: Theme.mono; pixelSize: 160 }
                    color: Theme.bone
                }
                Image {
                    visible: !!root.cur?.f
                    anchors { fill: parent; margins: 28 }
                    source: root.cur?.f ? "file://" + root.cur.f : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
        }

        Text {
            anchors { right: parent.right; rightMargin: 60; bottom: parent.bottom; bottomMargin: 44 }
            textFormat: Text.StyledText
            text: `<font color="${Theme.bone}">←↑↓→</font> ВЫБРАТЬ · <font color="${Theme.bone}">⏎</font> ВСТАВИТЬ · `
                + `<font color="${Theme.bone}">TAB</font> ВКЛАДКА · <font color="${Theme.bone}">ESC</font> ЗАКРЫТЬ`
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 3 }
            color: Theme.ash
        }

        NumberAnimation {
            id: enter
            property real v: 0
            target: enter; property: "v"
            from: 1; to: 0
            duration: Theme.hit
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
        }
    }
}
