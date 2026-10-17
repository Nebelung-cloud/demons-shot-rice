import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// II · Media: Hermit — плееры, Hierophant — текст песни, Tower — cava, Lovers — вывод, Temperance — громкости, World — плеер
Hand {
    id: tab

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isSink && n.isStream && n.audio)

    PwObjectTracker { objects: [tab.sink, tab.source, ...tab.streams] }

    // IX · очереди у mpris нет — отшельник держит список плееров
    // ponytail: mpris не отдаёт очередь трека; если появится плеер с TrackList — показать её здесь
    HandCard {
        i: 0
        num: "IX"
        name: "The Hermit"
        rays: false

        Art.Icon { text: "\u{F0CB8}"; size: 54 }
        Art.T2 { Layout.topMargin: 8; text: "players" }
        Art.Rows {
            model: Media.players.length
                ? Media.players.slice(0, 4).map(p => [p.trackTitle || p.identity, p.isPlaying ? "plays" : "rests", p === Media.player])
                : [["silence", "", false]]
        }
    }

    // V · текст песни из lrclib: текущая строка Rose
    HandCard {
        i: 1
        num: "V"
        name: "The Hierophant"
        rays: false

        Art.Icon { text: "\u{F0757}"; size: 40 }
        Repeater {
            model: Media.lyrics.length ? [-2, -1, 0, 1, 2] : [0]
            Text {
                required property int modelData
                readonly property var l: Media.lyrics[Media.line + modelData]
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 180
                Layout.topMargin: modelData === -2 ? 10 : 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                text: Media.lyrics.length ? (l?.[1] ?? "") : (Media.player ? "no words for this one" : "can't stop\ncan't slow down")
                font { family: Theme.goth; pixelSize: modelData === 0 ? 21 : 15; weight: modelData === 0 ? Font.Bold : Font.Normal }
                lineHeight: 1.2
                color: modelData === 0 && Media.lyrics.length ? Theme.rose : Theme.ash
                opacity: modelData === 2 ? 0.5 : 1
            }
        }
    }

    // XVI · cava
    HandCard {
        i: 2
        num: "XVI"
        name: "The Tower"
        raysY: 0.3
        // cava внизу сцены, вне колонки: в колонке скачущие столбики меняли её высоту и дёргали эмблему
        scene: Art.Eq {
            values: Cava.bars
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6; bottomMargin: 0 }
        }

        // эмблема из клипа Demon's Shot (4:15), белая на альфе — красим в rose как TintIcon
        AnimatedImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 170
            Layout.topMargin: -106 // колонка центрована: поднимает эмблему к центру лучей
            Layout.preferredHeight: 150
            source: Qt.resolvedUrl("demons-shot.webp")
            paused: !Media.playing // крутится только пока играет музыка, на паузе замирает на текущем кадре
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
            layer.effect: MultiEffect { colorization: 1; colorizationColor: Theme.rose }
        }
        Art.T2 { Layout.topMargin: 10; text: "cava · " + (Media.player?.identity ?? "silence") }
    }

    // VI · устройство вывода; клик — следующее
    HandCard {
        i: 3
        num: "VI"
        name: "The Lovers"
        rays: false
        scene: Art.Water {}
        onClicked: {
            const k = tab.sinks.indexOf(tab.sink);
            if (tab.sinks.length > 1) Pipewire.preferredDefaultAudioSink = tab.sinks[(k + 1) % tab.sinks.length];
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            PixelIcon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F02CB}"; size: 70 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "☾"; color: Theme.ash; font { family: Theme.goth; pixelSize: 26 } }
            PixelIcon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F04C3}"; size: 40; color: Theme.ash }
        }
        Art.T1 {
            Layout.topMargin: 18
            Layout.maximumWidth: 180
            elide: Text.ElideRight
            font.pixelSize: 22
            text: (tab.sink?.description ?? "no sink").split(" ").slice(0, 3).join(" ")
        }
        Art.T2 { text: `${tab.sinks.length} outputs · tap to switch` }
    }

    // XIV · громкости
    HandCard {
        i: 4
        num: "XIV"
        name: "Temperance"
        rays: false
        scene: Art.Water {}

        Art.Bars {
            model: [[(tab.sink?.audio.volume ?? 0) * 100, "OUT"], [(tab.source?.audio.volume ?? 0) * 100, "MIC"],
                [(tab.streams[0]?.audio.volume ?? 0) * 100, "APP"]]
        }
        Art.T2 { Layout.topMargin: 12; text: "pipewire" }
    }

    PlayerCard { i: 5; full: true }
}
