import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// IV · Weather: Wheel — 5 дней, Fool — ветер, Empress — влажность, Sun — восход/закат, Moon — фаза луны, Star — сейчас
Hand {
    id: tab

    readonly property var w: Weather.now
    readonly property real phase: Weather.moonPhase(new Date())
    function hm(d) { return d ? Qt.formatTime(d, "hh:mm") : "--:--"; }

    HandCard {
        i: 0
        num: "X"
        name: "The Wheel"
        rays: false

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Five days"
            font { family: Theme.frak; pixelSize: 26 }
            color: Theme.bone
        }
        Art.Rows {
            model: Weather.days.length
                ? Weather.days.map((d, k) => [Qt.locale("en_US").dayName(d.date.getDay(), Locale.ShortFormat),
                    `${Math.round(d.max)}° · ${Math.round(d.min)}°`, k === 0, Weather.glyph(d.code)])
                : [["no omens", "", false]]
        }
    }

    HandCard {
        i: 1
        num: "0"
        name: "The Fool"
        rays: false

        Art.Icon { text: "\u{F059D}"; size: 84 }
        Art.Big { text: tab.w ? Math.round(tab.w.wind) : "--"; small: "m/s" }
        Art.T2 { text: tab.w ? `${Weather.compass(tab.w.windDir)} · gusts ${Math.round(tab.w.gusts)}` : "no omens" }
        Art.Ripples {}
    }

    HandCard {
        i: 2
        num: "III"
        name: "The Empress"
        rays: false
        scene: Art.Water {}

        Art.Icon { text: "\u{F058E}"; size: 56 }
        Art.Big { text: tab.w ? tab.w.humidity : "--"; small: "%" }
        Art.T2 { text: tab.w ? `humidity · rain ${tab.w.rain}%` : "no omens" }
        Art.T2 {
            Layout.bottomMargin: 34 // над водой: столбик центруется вместе с отступом и уходит вверх
            text: tab.w ? `${Math.round(tab.w.pressure)} hpa` : ""
        }
    }

    HandCard {
        i: 3
        num: "XIX"
        name: "The Sun"
        raysY: 0.26

        Art.Icon { text: "\u{F0599}"; size: 76 }
        Art.Rows {
            Layout.topMargin: 22
            model: [[tab.hm(Weather.sun?.rise), "rise", false, "\u{F059C}"], [tab.hm(Weather.sun?.set), "set", true, "\u{F059B}"]]
        }
        Art.T2 {
            Layout.topMargin: 8
            text: Weather.sun ? (m => `day ${Math.floor(m / 60)} h ${m % 60} m`)(Math.round((Weather.sun.set - Weather.sun.rise) / 60000)) : "no omens"
        }
    }

    HandCard {
        i: 4
        num: "XVIII"
        name: "The Moon"
        rays: false
        scene: Art.Water {}

        // освещённость по фазе: 0 — новолуние, 0.5 — полнолуние
        Art.Moon { lit: 1 - Math.abs(0.5 - tab.phase) * 2 }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            text: ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"][Math.round(tab.phase * 8) % 8]
            font { family: Theme.frak; pixelSize: 24 }
            color: Theme.bone
        }
        Art.T2 { text: `${Math.round((1 - Math.cos(tab.phase * 2 * Math.PI)) * 50)}% lit · day ${Math.floor(tab.phase * 29.53) + 1} of 29` }
    }

    HandCard {
        i: 5
        num: "XVII"
        name: "The Star"
        rays: false

        Art.Icon { text: tab.w ? Weather.glyph(tab.w.code, tab.w.day) : "\u{F0AE2}"; size: 84 }
        Art.Ripples {}
        Art.Big { Layout.topMargin: 12; size: 44; text: tab.w ? Math.round(tab.w.temp) + "°" : "--°" }
        Art.T2 { text: tab.w ? `${Weather.name(tab.w.code)} · feels ${Math.round(tab.w.feels)}°` : "no omens" }
    }
}
