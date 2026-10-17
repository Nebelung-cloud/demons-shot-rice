import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import "../components/arcana.js" as Arcana

// лаунчер: панель 600px выезжает из бара со slam, остальное гаснет до Void 78%.
// apps / run / windows, «13 shots» — не больше тринадцати строк, у каждой строки свой аркан
PanelWindow {
    id: root

    property int mode: 0 // 0 apps, 1 run, 2 windows
    property int sel: 0
    readonly property var modes: ["apps", "run", "windows"]
    readonly property string query: input.text
    property var uses: ({}) // id приложения → сколько раз открыли; топ наверху
    signal settingsRequested

    // приложения с арканами — раз на смену списка, а не на каждую букву запроса
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
        id: e.id, key: e.name, icon: e.icon, extra: `${e.id} ${e.genericName} ${(e.keywords ?? []).join(" ")}`,
        arc: Arcana.forApp(e.id, e.name, (e.categories ?? []).filter(c => !/^(GTK|Qt|KDE|GNOME)$/.test(c))[0]?.toLowerCase()),
        run: () => e.execute() })).concat([{ id: "settings", key: "Settings", icon: "", extra: "house rules demonshot",
        arc: Arcana.forApp("settings", "Settings", "system"), run: () => root.settingsRequested() }])
    // окна — только пока лаунчер открыт: иначе каждая смена заголовка где угодно пересобирала бы список
    readonly property var wins: !visible || mode !== 2 ? [] : Hyprland.toplevels.values.map(t => {
        const cls = t.lastIpcObject?.class ?? "";
        return { key: t.title, extra: cls, icon: DesktopEntries.heuristicLookup(cls)?.icon ?? "", arc: Arcana.forApp(cls, t.title, cls.toLowerCase().split(".").pop()),
            run: () => Hyprland.dispatch(`hl.dsp.focus({ window = "address:${t.address}" })`) };
    })

    // строка: { name, what, glyph, arc, icon, hl (индексы совпавших букв), run() }
    readonly property var all: {
        const q = query.toLowerCase();
        if (mode === 1) {
            if (!q) return [];
            const a = Arcana.forApp(query.split(" ")[0], "", "run");
            return [{ name: query, what: "run", arc: a, hl: [], run: () => Quickshell.execDetached(["sh", "-c", query]) }];
        }
        const src = mode === 0 ? apps : wins;
        const out = [];
        for (const it of src) {
            const m = match(it.key, q);
            const score = m ? m.score : (q && it.extra.toLowerCase().includes(q) ? 1 : -1);
            if (score < 0) continue;
            out.push({ id: it.id, name: it.key, what: it.arc.what, arc: it.arc, icon: it.icon, hl: m ? m.hl : [], score, uses: uses[it.id] ?? 0, run: it.run });
        }
        return out.sort((a, b) => b.score - a.score || b.uses - a.uses || a.name.localeCompare(b.name));
    }
    readonly property var shown: all.slice(0, 13)
    readonly property var cur: shown[sel] ?? null

    // подпоследовательность: начало слова и подряд — выше
    function match(s, q) {
        if (!q) return { score: 1, hl: [] };
        const l = s.toLowerCase(), hl = [];
        let score = l.startsWith(q) ? 100 : l.includes(q) ? 50 : 10, i = 0;
        const at = l.indexOf(q);
        if (at >= 0) { for (let k = 0; k < q.length; k++) hl.push(at + k); return { score: score - at, hl }; }
        for (const c of q) {
            i = l.indexOf(c, i);
            if (i < 0) return null;
            hl.push(i++);
        }
        return { score, hl };
    }

    function marked(s, hl) {
        const esc = c => c === "<" ? "&lt;" : c === "&" ? "&amp;" : c;
        return [...s].map((c, i) => hl.includes(i) ? `<font color="${Theme.rose}">${esc(c)}</font>` : esc(c)).join("");
    }

    function open() {
        input.text = "";
        mode = 0;
        sel = 0;
        visible = true;
        input.forceActiveFocus();
        enter.restart();
        slam.restart();
    }
    function close() { visible = false; }
    function toggle() { visible ? close() : open(); }
    function pick(i) {
        if (!shown.length) return;
        sel = (i + shown.length) % shown.length;
        slam.restart();
    }
    function launch() {
        const it = cur;
        close();
        if (it?.id) {
            uses = Object.assign({}, uses, { [it.id]: (uses[it.id] ?? 0) + 1 });
            usesFile.setText(JSON.stringify(uses));
        }
        it?.run();
    }

    FileView {
        id: usesFile
        path: Quickshell.statePath("launcher-uses.json")
        printErrors: false
        onLoaded: try { root.uses = JSON.parse(text()); } catch (e) {}
    }

    onQueryChanged: { sel = 0; slam.restart(); }
    onModeChanged: { sel = 0; slam.restart(); }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "demonshot-launcher"

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.pit, 0.78)
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
            y: 330
            rotation: -8
            text: root.cur?.name ?? ""
            font { family: Theme.frak; pixelSize: 300 }
            color: Theme.fade(Theme.bone, 0.09)
            stroke: 1
            layer.enabled: true
            layer.effect: Glitch {}
        }

        Card {
            x: 766
            y: 190
            scale: 1.45
            rotation: 6
            transformOrigin: Item.TopLeft
            visible: root.cur !== null
            up: true
            seed: root.sel
            num: root.cur?.arc.num ?? ""
            name: root.cur?.arc.name ?? ""

            TintIcon { id: cardIcon; Layout.alignment: Qt.AlignHCenter; size: 100; name: root.cur?.icon ?? ""; visible: ok }
            ArcanaArt { glyph: root.cur?.arc.glyph ?? ""; size: 100; visible: !cardIcon.ok }
            Art.T2 { Layout.topMargin: 18; text: root.cur?.what ?? "" }
        }

        Column {
            x: 726
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            spacing: 8
            visible: root.cur !== null
            Text { text: root.cur?.arc.q ?? ""; color: Theme.bone; font.family: Theme.goth; font.pixelSize: 34 }
            Text {
                text: root.cur ? `${root.cur.arc.num} · ${root.cur.arc.name} — ${root.cur.name.toLowerCase()}` : ""
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                color: Theme.ash
            }
        }

        // панель
        Rectangle {
            id: panel
            width: 600
            height: stage.height
            color: Theme.crypt
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.wine }
            MouseArea { anchors.fill: parent } // клики по панели не закрывают

            NumberAnimation on x {
                id: enter
                from: -600; to: 0
                duration: 350
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
            }

            Text {
                x: 44; y: 56
                text: "POUR ONE<"
                font { family: Theme.mono; pixelSize: 22; weight: Font.Bold; letterSpacing: 3 }
                color: Theme.bone
            }

            // ввод: Rose-☾, готика 54, мигающий Bone-блок, тонкая линия — как пароль на локе
            Item {
                id: field
                x: 44; y: 56 + 30 + 26
                width: parent.width - 88
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
                        if (e.key === Qt.Key_Up || ctrl && e.key === Qt.Key_K) root.pick(root.sel - 1);
                        else if (e.key === Qt.Key_Down || ctrl && e.key === Qt.Key_J) root.pick(root.sel + 1);
                        else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 3;
                        else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 2) % 3;
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch();
                        else if (e.key === Qt.Key_Escape) root.close();
                        else return;
                        e.accepted = true;
                    }
                }
            }

            Row {
                id: tabs
                x: 44
                y: field.y + field.height + 18
                spacing: 28
                Repeater {
                    model: root.modes
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData.toUpperCase()
                        font { family: Theme.mono; pixelSize: 11; letterSpacing: 3.3 }
                        color: index === root.mode ? Theme.bone : Theme.ash
                        Rectangle { visible: index === root.mode; y: parent.height + 3; width: parent.width - 3; height: 2; color: Theme.rose }
                        MouseArea { anchors.fill: parent; onClicked: root.mode = index }
                    }
                }
            }
            Text {
                anchors { right: parent.right; rightMargin: 44; verticalCenter: tabs.verticalCenter }
                text: `${Theme.roman(root.shown.length).toLowerCase()} of ${root.all.length}`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 2 }
                color: Theme.ash
            }

            Item {
                id: list
                y: tabs.y + tabs.height + 22
                width: parent.width
                height: 13 * 52

                // выделение: Plum со штрихом Crimson, влетает со slam
                Rectangle {
                    id: hl
                    property real s: 0
                    visible: root.cur !== null
                    x: s
                    y: root.sel * 52
                    width: parent.width - 1
                    height: 52
                    opacity: 1 - s / 160
                    color: Theme.plum
                    Rectangle { width: 3; height: parent.height; color: Theme.crimson }
                    NumberAnimation on s {
                        id: slam
                        from: 160; to: 0
                        duration: Theme.hit
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
                    }
                }

                Repeater {
                    model: root.shown
                    Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: index === root.sel
                        y: index * 52
                        width: list.width
                        height: 52

                        Text {
                            x: 44
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.roman(row.index + 1)
                            font { family: Theme.goth; pixelSize: 20 }
                            color: row.on ? Theme.bone : Theme.dim
                        }
                        // иконка приложения, перекрашенная в палитру; нет иконки — глиф аркана
                        TintIcon {
                            id: icon
                            x: 44 + 64 - 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon ?? ""
                            color: row.on ? Theme.bone : Theme.rose
                            opacity: row.on ? 1 : 0.75
                        }
                        Text {
                            x: 44 + 64
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !icon.ok
                            text: ["sigil", "moon"].includes(row.modelData.arc.glyph) ? "\u{F0AE2}" : row.modelData.arc.glyph
                            font { family: Theme.mono; pixelSize: 20 }
                            color: row.on ? Theme.bone : Theme.ash
                        }
                        Text {
                            x: 44 + 64 + 34
                            width: what.x - x - 12
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: root.marked(row.modelData.name, row.modelData.hl)
                            font { family: Theme.mono; pixelSize: 16 }
                            color: row.on ? Theme.bone : Theme.pale
                        }
                        Text {
                            id: what
                            anchors { right: parent.right; rightMargin: 44; verticalCenter: parent.verticalCenter }
                            text: row.modelData.what.toUpperCase()
                            font { family: Theme.mono; pixelSize: 10; letterSpacing: 2.5 }
                            color: row.on ? Theme.rose : Theme.ash
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.sel = row.index; root.launch(); }
                        }
                    }
                }
            }

            Text {
                x: 44
                anchors { bottom: parent.bottom; bottomMargin: 40 }
                textFormat: Text.StyledText
                text: `<font color="${Theme.bone}">↑↓</font> ВЫБОР · <font color="${Theme.bone}">⏎</font> НАЛИТЬ · <font color="${Theme.bone}">TAB</font> РЕЖИМ · <font color="${Theme.bone}">ESC</font> ЗАКРЫТЬ`
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 2.7 }
                color: Theme.ash
            }
        }
    }
}
