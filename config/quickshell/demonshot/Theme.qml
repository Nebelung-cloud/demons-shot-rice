pragma Singleton

import Quickshell
import QtQuick
import qs.settings

// палитра (из Rules), шрифты, движение — единственное место, где они живут
Singleton {
    // палитра — из house rules (Rules.palettes), по умолчанию Demon's Shot: от винного к кости. void — слово JS, поэтому void_
    readonly property color void_: Rules.pal.c[0]   // фон
    readonly property color crypt: Rules.pal.c[1]   // окна, бар
    readonly property color wine: Rules.pal.c[2]    // линии, рамки
    readonly property color plum: Rules.pal.c[3]    // выделение
    readonly property color rose: Rules.pal.c[4]    // свет, занятые ws
    readonly property color crimson: Rules.pal.c[5] // фокус, активное — одна вещь на экране
    readonly property color ash: Rules.pal.c[6]     // вторичный текст
    readonly property color bone: Rules.pal.c[7]    // текст
    // производные — тоже от палитры, чтобы смена темы красила всё
    readonly property color blush: mix(rose, bone, 0.6)  // светлый текст там, где белого быть не должно (уведомления)
    readonly property color dim: mix(ash, void_, 0.45)   // пустые ws
    readonly property color pale: mix(bone, ash, 0.23)   // приглушённый текст
    readonly property color line: fade(bone, 0.78)       // линии на картах
    readonly property color pit: Qt.darker(void_, 1.6)   // глубже фона: шторки, виньетки
    readonly property color cloak: mix(plum, void_, 0.5) // рубашка, низ поднятой карты
    readonly property color ember: mix(bone, crimson, 0.2) // сердце огонька
    // книга и свиток: пергамент, чернила, линейки, рамка набора
    readonly property color pg: mix(crypt, plum, 0.16)
    readonly property color ink: mix(bone, ash, 0.18)
    readonly property color rule: mix(wine, bone, 0.125, 0.8)
    readonly property color frame: mix(wine, bone, 0.25, 0.73)

    // Canvas сам за цветами не следит: в нём `readonly property var pal: Theme.pal; onPalChanged: requestPaint()`
    readonly property var pal: Rules.pal

    // mix(a, b, t) — как color-mix: t доли b
    function mix(a, b, t, al) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, al ?? 1); }
    function fade(c, al) { return Qt.rgba(c.r, c.g, c.b, al); }

    readonly property string frak: "UnifrakturCook" // лого, обои, лок — только крупно
    readonly property string goth: "Grenze Gotisch" // UI, часы, ws, меню
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string p3: "Montserrat"       // мелкие подписи на картах

    // slam: удар с перелётом, как bezier slam в hyprland
    readonly property var slam: [0.2, 1.4, 0.3, 1, 1, 1]
    readonly property var snap: [0.9, 0, 0.1, 1, 1, 1]
    readonly property int fast: 180
    readonly property int hit: 320
    readonly property int stagger: 40 // задержка между картами

    function roman(n) {
        if (!Rules.store.roman) return String(n);
        if (n <= 0) return "0";
        const t = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
                   [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let s = "";
        for (const [v, r] of t)
            while (n >= v) { s += r; n -= v; }
        return s;
    }
}
