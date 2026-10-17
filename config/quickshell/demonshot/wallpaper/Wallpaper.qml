import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// обои: пустота с тёплым свечением, свечи, два часовых колеса по углам, рваное лого по диагонали,
// контурное эхо строк, уголки видоискателя, виньетка и зерно.
// Видно на пустом столе; пока на ws есть окна, всё замирает — батарея не греется зря
PanelWindow {
    id: root

    readonly property bool idle: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) === 0
    property real spin: 0
    property date time: new Date()

    anchors { left: true; right: true; top: true; bottom: true }
    color: Theme.void_
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "demonshot-wallpaper"

    // шестерни: оборот за 240 с (как в концепте); стрелки — раз в минуту со slam.
    // ~30 кадров/с, а не каждый vsync: колесо ползёт ~1 физ. пиксель за кадр, а каждый кадр — перерисовка всего экрана.
    // Круг 1800°: нижнее колесо крутится на 0.8 и текстом повторяется через 120° — на 360° оно прыгало на 48°
    // ponytail: interval — ручка плавности
    Timer {
        running: root.idle // остановка не сбрасывает угол — колесо продолжает с того же места
        interval: 33
        repeat: true
        onTriggered: root.spin = (root.spin + 360 * interval / 240000) % 1800
    }
    Timer {
        running: root.idle
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.time = new Date()
    }

    // холст 1920×1080, растянут на экран по меньшей стороне; углы привязаны к краям
    Item {
        id: stage
        readonly property real s: Math.min(root.width / 1920, root.height / 1080)
        width: root.width / s
        height: root.height / s
        scale: s
        transformOrigin: Item.TopLeft

        Glow { cx: stage.width * 0.52; cy: stage.height * 0.5; rx: stage.width * 0.4; ry: stage.height * 0.45; color: Theme.fade(Theme.plum, 0.55) }
        Glow { cx: stage.width * 0.5; cy: stage.height * 1.1; rx: stage.width * 0.7; ry: stage.height * 0.4; color: Theme.fade(Theme.wine, 0.9) }

        Candle { x: stage.width / 2 + 220; y: 110 }
        Candle { x: stage.width / 2 + 310; y: 170; scale: 0.6 }
        Candle { x: stage.width - 360; y: stage.height - 200 }
        Candle { x: stage.width - 270; y: stage.height - 140; scale: 0.6 }

        ClockRing {
            x: stage.width - 180
            y: 110
            spin: root.spin
            time: root.time
        }
        ClockRing {
            x: 300
            y: stage.height - 80
            r: 560
            band: 60
            big: "CAN'T SLOW DOWN · "
            small: "xiii shots · demon's shot · "
            bigPad: 68
            smallPad: 186
            hourLen: 280
            minLen: 440
            spin: -root.spin * 0.8
            time: root.time
            tiltX: 28
            tiltY: 20
            tiltZ: -10
        }

        // эхо лого: две контурные строки параллельно диагонали
        Outline {
            x: stage.width / 2 + 190 - width / 2
            y: stage.height / 2 - 180 - height / 2
            rotation: 40
            opacity: 0.45
            text: "let it slide · get loose"
            font { family: Theme.goth; pixelSize: 58; weight: Font.Black }
        }
        Outline {
            x: stage.width / 2 - 110 - width / 2
            y: stage.height / 2 + 180 - height / 2
            rotation: 40
            opacity: 0.45
            text: "can't slow down · xiii shots"
            font { family: Theme.goth; pixelSize: 58; weight: Font.Black }
        }

        GlitchText {
            id: logo
            x: stage.width / 2 + 40 - width / 2
            y: stage.height / 2 - height / 2
            rotation: 40
            text: "Demon's Shot"
            font { family: Theme.frak; pixelSize: 230; letterSpacing: -6 }
            color: Theme.crimson
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.fade(Theme.crimson, 0.45)
                shadowBlur: 1
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 64
            }
        }

        // уголки видоискателя
        Item {
            x: 130; y: 90
            width: 220; height: 230
            opacity: 0.8
            Rectangle { width: parent.width; height: 2; color: Theme.rose }
            Rectangle { width: 2; height: parent.height; color: Theme.rose }
            Text {
                x: 4
                y: -height - 12
                text: "CAN'T STOP<"
                font { family: Theme.mono; pixelSize: 22; weight: Font.Bold; letterSpacing: 3 }
                color: Theme.bone
            }
        }
        Item {
            x: stage.width - 46 - width
            y: stage.height - 46 - height
            width: 220; height: 230
            opacity: 0.8
            Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: Theme.rose }
            Rectangle { x: parent.width - 2; width: 2; height: parent.height; color: Theme.rose }
        }
    }

    // виньетка и зерно — поверх всего, на весь экран
    Item {
        anchors.fill: parent
        clip: true
        Glow {
            cx: root.width * 0.55
            cy: root.height * 0.5
            rx: root.width * 0.8 // эллипс 80%×75%, как в концепте
            ry: root.height * 0.75
            color: "transparent"
            fade: 0.45
            edge: Theme.fade(Theme.pit, 0.85)
        }
    }
    // свеча: тёплая точка с красным ореолом
    component Candle: Item {
        width: 0
        height: 0
        Glow { cx: 0; cy: 0; rx: 110; ry: 110; fade: 1; color: Theme.fade(Theme.rose, 0.12) }
        Glow { cx: 0; cy: 0; rx: 34; ry: 34; fade: 1; color: Theme.fade(Theme.crimson, 0.4) }
        Rectangle { x: -3; y: -3; width: 6; height: 6; radius: 3; color: Theme.ember }
    }
}
