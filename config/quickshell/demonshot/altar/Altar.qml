import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// алтарь: Super+Space — низ темнеет, над веером фишки-вкладки, рука из шести карт сдаётся снизу.
// Открывается и закрывается только клавишами (Super+Space, Esc), на курсор не реагирует
Scope {
    id: root

    property bool open: false
    property int tab: 0
    readonly property var tabs: ["Dashboard", "Media", "Performance", "Weather"]

    function toggle() { open ? close() : show(); }
    function show() {
        if (open) return;
        open = true;
    }
    function close() { open = false; }
    function pick(k) {
        if (k === tab) return;
        tab = k;
    }

    Binding { target: SysStats; property: "detailed"; value: root.open }
    Binding { target: SysStats; property: "perf"; value: root.open && root.tab === 2 }
    Binding { target: Cava; property: "active"; value: root.open && root.tab === 1 }

    PanelWindow {
        id: win

        // макет: рука в нижних 810 из 1080, ширина 1856.
        // окно на весь экран, размеры — свои (их выдаёт композитор): screen.width/height не обновляются, если вывод поменял размер
        readonly property real s: width > 64 && height > 0 ? Math.min((width - 64) / 1856, height / 1080) : 1

        visible: root.open
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "demonshot-altar"
        // мышь ловит только стол (фишки и карты), прозрачный верх градиента пропускает клики.
        // Явные x/y, не item: Region следит только за x/y/size самого item, а окно пересчитывает маску на resize
        // раньше, чем stage переедет: маска застревала на старом месте и часть руки была «мёртвой»
        mask: Region { x: stage.x; y: stage.y; width: stage.width * win.s; height: stage.height * win.s }

        // низ темнеет: 95% у края → 70% → прозрачно на трёх четвертях экрана
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 810 * win.s
            // окно прячется сразу при закрытии, так что плавно только наползает
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.25; color: Theme.fade(Theme.pit, 0.7) }
                GradientStop { position: 1; color: Theme.fade(Theme.pit, 0.95) }
            }
        }

        Item {
            id: stage
            x: (win.width - width * win.s) / 2
            y: win.height - height * win.s
            width: 1856
            height: 810
            scale: win.s
            transformOrigin: Item.TopLeft
            focus: true

            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) root.pick(e.key - Qt.Key_1);
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) root.pick((root.tab + 1) % 4);
                else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) root.pick((root.tab + 3) % 4);
                else return;
                e.accepted = true;
            }

            // фишки казино: клик — фишка крутится, рука сдаётся заново
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                spacing: 46
                scale: 1.3
                transformOrigin: Item.Top

                Repeater {
                    model: root.tabs
                    Chip {
                        required property string modelData
                        text: modelData
                        on: index === root.tab
                        onClicked: root.pick(index)
                    }
                }
            }

            // руки: видна только выбранная
            Repeater {
                id: hands
                model: [dashboard, media, perf, weather]
                Loader {
                    required property var modelData
                    required property int index
                    x: stage.width / 2 - 110
                    y: 130
                    // рука крупнее макета карты: масштаб от верхнего центра, низ крайних карт как раз у края экрана
                    scale: 1.25
                    transformOrigin: Item.Top
                    active: root.open && index === root.tab
                    sourceComponent: modelData
                    onLoaded: item.deal() // загрузилась — значит открыли или сменили вкладку
                }
            }
        }
    }

    Component { id: dashboard; Dashboard {} }
    Component { id: media; MediaTab {} }
    Component { id: perf; PerfTab {} }
    Component { id: weather; WeatherTab {} }
}
