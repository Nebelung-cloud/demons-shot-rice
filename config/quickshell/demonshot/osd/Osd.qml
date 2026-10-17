import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// OSD громкости и яркости: у бара по центру высоты, как модуль бара, только крупно
PanelWindow {
    id: root

    property string kind: "VOL"
    property real value: 0
    property bool muted: false
    property bool shown: false
    property bool armed: false // первые значения при старте не показываем

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    function show(k, v, m) {
        if (!armed) return;
        kind = k;
        value = v;
        muted = m ?? false;
        if (!shown) enter.restart();
        shown = true;
        hide.restart();
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.show("VOL", root.sink.audio.volume, root.sink.audio.muted); }
        function onMutedChanged() { root.show("VOL", root.sink.audio.volume, root.sink.audio.muted); }
    }

    // яркость: Backlight (общий с glyph) шлёт moved на каждый uevent, даже если значение то же
    Connections {
        target: Backlight
        function onMoved() { root.show("BRI", Backlight.value); }
    }

    Timer { running: true; interval: 1500; onTriggered: root.armed = true }
    Timer { id: hide; interval: 1400; onTriggered: root.shown = false }

    visible: shown || out.running
    anchors.left: true
    margins.left: 14
    implicitWidth: 92
    implicitHeight: 280
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "demonshot-osd"

    Rectangle {
        id: plate
        width: 64
        height: 260
        y: 10
        color: Theme.crypt
        border { width: 1; color: Theme.wine }
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: out; duration: 150 } }

        NumberAnimation on x {
            id: enter
            from: -80; to: 0
            duration: Theme.hit
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.slam
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 8

            PixelIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 22
                text: root.kind === "BRI" ? "\u{F00DF}" : root.muted ? "\u{F075F}" : "\u{F057E}"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.kind
                font { family: Theme.mono; pixelSize: 9; letterSpacing: 1.8 }
                color: Theme.ash
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.muted ? "×" : Math.round(root.value * 100)
                font { family: Theme.goth; pixelSize: 30 }
                color: Theme.bone
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 14
                height: 130
                color: "transparent"
                border { width: 1; color: Theme.line }
                Rectangle {
                    x: 2; width: 10
                    anchors { bottom: parent.bottom; bottomMargin: 2 }
                    height: (parent.height - 4) * (root.muted ? 0 : Math.min(1, root.value))
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.rose }
                        GradientStop { position: 1; color: Theme.crimson }
                    }
                    Behavior on height { NumberAnimation { duration: 120 } }
                }
            }
        }
    }
}
