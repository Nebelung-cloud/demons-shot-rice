import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// I · Dashboard: Magician, Moon/Sun, Wheel, Chariot, Star, World
Hand {
    id: hand

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date
    // только время суток: sun с прошлой удачной загрузки может быть вчерашним
    readonly property bool day: {
        const m = t => t.getHours() * 60 + t.getMinutes(), s = Weather.sun;
        return s ? m(now) > m(s.rise) && m(now) < m(s.set) : now.getHours() >= 7 && now.getHours() < 19;
    }

    // I · пользователь: аватар (~/.face пикселями, иначе ascii-D) в лучах, имя, система; на столе кубок, меч и фишка
    HandCard {
        i: 0
        num: "I"
        name: "The Magician"
        raysY: 0.2   // по центру аватара
        raysR: 100

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -10
            implicitWidth: 84
            implicitHeight: 84
            Image {
                id: face
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.face"
                sourceSize: Qt.size(28, 28) // пиксель-арт: 28×28, растянуто без сглаживания
                smooth: false
                fillMode: Image.PreserveAspectCrop
            }
            AsciiD {
                visible: face.status !== Image.Ready
                anchors.centerIn: parent
                font.pixelSize: 6
                color: Theme.bone
            }
        }
        Art.T1 { Layout.topMargin: 22; text: Quickshell.env("USER") }
        Art.T2 { text: "arch · hyprland" }
        Item {
            Layout.fillWidth: true
            Layout.topMargin: 16
            implicitHeight: 34
            Rectangle { width: parent.width; height: 1.5; color: Theme.line }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                spacing: 24
                Repeater {
                    model: ["\u{F0176}", "\u{F04E5}", "\u{F1074}"]
                    // одинаковые ячейки: у глифов разная ширина, иначе шаг пляшет
                    Item {
                        required property string modelData
                        width: 24
                        height: icon.height
                        PixelIcon { id: icon; anchors.centerIn: parent; text: parent.modelData; size: 18 }
                    }
                }
            }
        }
        Art.T2 {
            textFormat: Text.StyledText
            text: `up <font color="${Theme.bone}">${Math.floor(SysStats.uptime / 3600) ? Math.floor(SysStats.uptime / 3600) + " h " : ""}${Math.floor(SysStats.uptime / 60) % 60} min</font>`
        }
    }

    // XVIII / XIX · часы: ночью луна над водой, днём солнце с лучами
    HandCard {
        i: 1
        num: hand.day ? "XIX" : "XVIII"
        name: hand.day ? "The Sun" : "The Moon"
        rays: hand.day
        raysY: 0.3
        scene: Art.Water { visible: !hand.day }

        Art.Moon { visible: !hand.day; lit: 0.3 }
        Art.Icon { visible: hand.day; text: "\u{F0599}"; size: 80 }
        // у Grenze над цифрами пустой ascent — время ближе к луне; дата приподнята над водой
        Art.Big { Layout.topMargin: 0; text: Qt.formatTime(hand.now, "hh:mm AP").slice(0, 5); small: Qt.formatTime(hand.now, "AP") }
        Art.T2 { Layout.topMargin: 2; Layout.bottomMargin: hand.day ? 0 : 40; text: Qt.formatDate(hand.now, "ddd · d · MMM").toLowerCase() }
    }

    // X · календарь: месяц фрактурой, сегодня — Crimson, выходные Rose, каждое 13-е — красная точка
    HandCard {
        id: cal
        i: 2
        num: "X"
        name: "The Wheel"
        rays: false
        sparks: false

        // от месяца, а не от минуты: иначе 42 клетки пересоздаются каждую минуту
        readonly property int ym: hand.now.getFullYear() * 12 + hand.now.getMonth()
        readonly property var cells: {
            const y = Math.floor(ym / 12), m = ym % 12;
            const first = (new Date(y, m, 1).getDay() + 6) % 7; // с понедельника
            return Array.from({ length: 42 }, (_, k) => new Date(y, m, 1 - first + k));
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.locale("en_US").monthName(hand.now.getMonth())
            font { family: Theme.frak; pixelSize: 28 }
            color: Theme.bone
        }
        Art.T2 { Layout.topMargin: 4; text: Theme.roman(hand.now.getFullYear()) }
        Grid {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            columns: 7
            Repeater {
                model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                Text {
                    required property string modelData
                    width: 23; height: 18
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: modelData.toUpperCase()
                    font { family: Theme.p3; pixelSize: 7; weight: Font.DemiBold }
                    color: Theme.ash
                }
            }
            Repeater {
                model: cal.cells
                Rectangle {
                    required property date modelData
                    required property int index
                    readonly property bool today: modelData.toDateString() === hand.now.toDateString()
                    readonly property bool out: modelData.getMonth() !== hand.now.getMonth()
                    width: 23; height: 25
                    color: today ? Theme.crimson : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.getDate()
                        font { family: Theme.goth; pixelSize: 14; weight: Font.Medium }
                        color: parent.today ? Theme.bone : parent.out ? Theme.mix(Theme.ash, Theme.void_, 0.6) : parent.index % 7 >= 5 ? Theme.rose : Theme.bone
                    }
                    Rectangle {
                        visible: parent.modelData.getDate() === 13 && !parent.out && !parent.today
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                        width: 3; height: 3
                        color: Theme.crimson
                    }
                }
            }
        }
    }

    // VII · ресурсы: занавеси по бокам, четыре столбика
    HandCard {
        i: 3
        num: "VII"
        name: "The Chariot"
        rays: false
        scene: [Art.Curtain { side: -1 }, Art.Curtain { side: 1 }]

        Art.Bars {
            Layout.topMargin: 30
            model: [[SysStats.cpu * 100, "CPU"], [SysStats.mem * 100, "MEM"], [SysStats.gpu * 100, "GPU"],
                [(SysStats.disks[0]?.used ?? 0) * 100, "DSK"]]
        }
    }

    // XVII · погода: звезда над кругами на воде; нет данных — «no omens»
    HandCard {
        i: 4
        num: "XVII"
        name: "The Star"
        rays: false

        Art.Icon { Layout.topMargin: -6; size: 84; text: "\u{F0AE2}" } // The Star — всегда звезда, погода словом ниже
        Art.Ripples {}
        Art.Big { Layout.topMargin: 12; size: 34; text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--°" }
        Art.T2 { text: Weather.ok ? Weather.name(Weather.now.code) : "no omens" }
    }

    // XXI · плеер: уроборос с обложкой (или ascii-D), прогресс по кругу, кнопки
    PlayerCard { i: 5 }
}
