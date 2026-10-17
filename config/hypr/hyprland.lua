-- Monitor: scale 2, как было в основном конфиге
hl.monitor({ output = "", mode = "highres", position = "auto", scale = "auto" })

-- unscale XWayland
hl.config({
    xwayland = {
        force_zero_scaling = true
    }
})

-- toolkit-specific scale
hl.env("GDK_SCALE", "2")

-- Configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")
