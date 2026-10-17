import QtQuick
import Quickshell
import Quickshell.Hyprland
import "altar"
import "bar"
import "charms"
import "clip"
import "launcher"
import "notifications"
import "osd"
import "pact"
import "power"
import qs.settings
import "shot"
import "wallpaper"
import "ward"

// demonshot: обои, бар, барабан, лаунчер, алтарь, меню питания, настройки, обереги (угол справа снизу), буфер обмена, чары, скриншоты,
// vpn-договор (clash verge), уведомления, OSD, глобалки.
// Блокировка — отдельный процесс (lock.qml): падение шелла не роняет лок
ShellRoot {
    id: shell

    PowerMenu { id: power }
    Launcher { id: launcher; onSettingsRequested: settings.open() }
    Settings { id: settings }
    Altar { id: altar }
    Clip { id: clip }
    Charms { id: charms }
    Shot { id: shot }
    Pact { id: pact }
    Ward { id: ward; onSettingsRequested: settings.open() }
    Notifications { lift: ward.open ? ward.size : 0 }

    // house rules из rules.json — поверх значений hypr-конфига
    Component.onCompleted: Rules.applyAll()
    Osd {}

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Wallpaper { screen: s.modelData }
            Bar {
                screen: s.modelData
                powerOpen: power.visible
                onPowerClicked: power.visible ? power.close() : power.open()
            }
        }
    }

    // тап Super — лаунчер на отпускании; любой Super+<key> по пути шлёт interrupt, и лаунчер не открывается
    property bool interrupted: false
    Shortcut {
        name: "launcher"
        description: "лаунчер (тап Super)"
        // release-бинд Hyprland шлёт released, не pressed (hyprctl dispatch шлёт pressed — тут не сработает)
        onReleased: {
            if (!shell.interrupted) launcher.toggle();
            shell.interrupted = false;
        }
    }
    Shortcut { name: "launcherArm"; description: "нажатие Super — сброс interrupt"; onPressed: shell.interrupted = false }
    Shortcut { name: "launcherInterrupt"; description: "Super+<key> — не открывать лаунчер"; onPressed: shell.interrupted = true }
    Shortcut { name: "altar"; description: "алтарь"; onPressed: altar.toggle() }
    Shortcut { name: "power"; description: "меню питания"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "clip"; description: "буфер обмена"; onPressed: clip.toggle() }
    Shortcut { name: "charms"; description: "каомодзи, эмодзи, ascii, символы, стикеры"; onPressed: charms.toggle() }
    Shortcut { name: "shot"; description: "скриншот"; onPressed: shot.open() }
    Shortcut { name: "settings"; description: "настройки"; onPressed: settings.toggle() }
    Shortcut { name: "pact"; description: "vpn-договор: clash verge"; onPressed: pact.toggle() }
    Shortcut { name: "ward"; description: "обереги: тумблеры, свеча, запись"; onPressed: ward.toggle() }

    component Shortcut: GlobalShortcut { appid: "demonshot" }
}
