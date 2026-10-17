import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "lock"

// блокировка — отдельный процесс: qs -p …/demonshot/lock.qml. Разблокировались — процесс выходит.
// Упал бар — лок живёт; упал лок — Hyprland держит экран закрытым, SUPER+ALT+L поднимает его заново
ShellRoot {
    id: shell
    // hot-reload пересоздаёт WlSessionLock: старый лок умирает, процесс висит без экрана и pgrep в lockCmd не даёт поднять новый
    settings.watchFiles: false

    // общее состояние для всех экранов
    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        readonly property bool busy: pam.active
        function submit() {
            if (!buffer || pam.active) return;
            pam.start();
        }
    }

    PamContext {
        id: pam
        config: "lock"
        configDirectory: Quickshell.shellPath("pam")
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(gate.buffer);
        }
        onCompleted: res => {
            gate.buffer = "";
            if (res === PamResult.Success) lock.locked = false;
            else gate.fail = true;
        }
    }

    // раскладка для модуля KB: начальная из hyprctl, дальше по событию activelayout
    property string layout: "EN"
    function short(name) { return name.slice(0, 2).toUpperCase(); }
    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) shell.layout = shell.short(text.trim()) }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") shell.layout = shell.short(e.data.split(",").pop()); }
    }

    WlSessionLock {
        id: lock
        locked: true
        // ponytail: lockedChanged после locked = false не приходит (quickshell 0.3.2), а secure падает — выходим по нему
        onSecureChanged: if (!secure) Qt.quit()

        LockSurface { auth: gate; layout: shell.layout }
    }
}
