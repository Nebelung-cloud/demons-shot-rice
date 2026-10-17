pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// подсветка экрана, как в caelestia — устройство не зашито: то, что берёт brightnessctl по умолчанию (первое backlight).
// Значение — из sysfs: inotify на нём молчит, но запись в brightness шлёт uevent change — ждём его от udev, а не опрашиваем.
// Нет подсветки (настольный ПК) — dev пустой, value 0. ponytail: внешние мониторы по DDC (ddcutil, как у caelestia) — нет
Singleton {
    id: root

    property string dev: ""       // /sys/class/backlight/<имя>
    property real value: 0        // 0…1
    signal moved()                // каждый uevent, даже если значение то же (клавиша на максимуме) — для OSD

    function read() {
        cur.reload();
        const v = parseInt(cur.text());
        if (!isNaN(v)) value = v / (parseInt(max.text()) || 1);
    }
    function set(v) {
        if (dev) Quickshell.execDetached(["brightnessctl", "-q", "-d", dev.slice(dev.lastIndexOf("/") + 1), "set", Math.round(Math.max(0.01, Math.min(1, v)) * 100) + "%"]);
    }

    FileView { id: cur; path: root.dev ? root.dev + "/brightness" : ""; blockLoading: true; printErrors: false }
    FileView { id: max; path: root.dev ? root.dev + "/max_brightness" : ""; blockLoading: true; printErrors: false }

    // brightnessctl -m: «имя,класс,текущее,процент,максимум»
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim().split(",")[0];
                if (!name) return;
                root.dev = "/sys/class/backlight/" + name;
                root.read();
            }
        }
    }
    Process {
        running: !!root.dev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser { onRead: l => { if (l.includes(" change ")) { root.read(); root.moved(); } } }
    }
}
