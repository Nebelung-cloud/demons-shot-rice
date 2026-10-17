import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// III · Performance: Priestess — память, Judgement — GPU, Justice — диски, Strength — сеть, Devil — процессы, Emperor — CPU
Hand {
    HandCard {
        i: 0
        num: "II"
        name: "The Priestess"
        rays: false
        scene: [Art.Curtain { side: -1 }, Art.Curtain { side: 1 }]

        Art.Orb {
            value: SysStats.mem
            Text { text: SysStats.memUsed.toFixed(1); color: Theme.bone; font { family: Theme.goth; pixelSize: 40; weight: Font.Bold } }
        }
        Art.T2 { Layout.topMargin: 12; text: `of ${Math.round(SysStats.memTotal)} gib · mem` }
        Art.T2 { text: `swap ${SysStats.swapUsed.toFixed(1)} · cache ${SysStats.cache.toFixed(1)}` }
    }

    HandCard {
        i: 1
        num: "XX"
        name: "Judgement"
        raysY: 0.24

        Art.Icon { text: "\u{F08AE}"; size: 64 }
        Art.Big { text: Math.round(SysStats.gpu * 100); small: "%" }
        Art.T2 { text: `gpu · ${Math.round(SysStats.gpuTemp)}°` }
        Art.T2 { text: `vram ${SysStats.vramUsed.toFixed(1)} / ${Math.round(SysStats.vramTotal)} gib` }
    }

    HandCard {
        i: 2
        num: "XI"
        name: "Justice"
        rays: false

        Art.Icon { text: "\u{F05D1}"; size: 44 }
        Art.Bars { model: SysStats.disks.map(d => [d.used * 100, d.mount.toUpperCase()]) }
        Art.T2 { Layout.topMargin: 12; text: SysStats.disks.length ? `nvme · ${Math.round(SysStats.disks[0].size / 1e9)} gb` : "" }
    }

    HandCard {
        i: 3
        num: "VIII"
        name: "Strength"
        rays: false

        Art.Icon { text: "\u{F095B}"; size: 64 }
        Art.Rows {
            Layout.topMargin: 16
            model: [[SysStats.rate(SysStats.rx).split(" ")[0], SysStats.rate(SysStats.rx).split(" ")[1], true, "\u{F01DA}"],
                [SysStats.rate(SysStats.tx).split(" ")[0], SysStats.rate(SysStats.tx).split(" ")[1], false, "\u{F0552}"]]
        }
        Art.T2 { Layout.topMargin: 12; text: SysStats.iface || "offline" }
        Art.Ripples {}
    }

    HandCard {
        i: 4
        num: "XV"
        name: "The Devil"
        rays: false

        Art.Icon { text: "\u{F0238}"; size: 54 }
        Art.T2 { Layout.topMargin: 8; text: "top · cpu %" }
        Art.Rows { model: SysStats.procs.map((p, k) => [p[0], p[1].toFixed(1), k === 0]) }
    }

    HandCard {
        i: 5
        num: "IV"
        name: "The Emperor"
        rays: false

        Art.Big { Layout.topMargin: 0; text: Math.round(SysStats.cpu * 100); small: "%" }
        Art.T2 { text: `cpu · ${Math.round(SysStats.cpuTemp)}° · ${SysStats.cpuFreq.toFixed(1)} ghz` }
        Art.Eq { values: SysStats.cores }
        Art.T2 { Layout.topMargin: 10; text: "load " + SysStats.load }
    }
}
