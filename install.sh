#!/usr/bin/env bash
# Demon's Shot: ставит всё на чистый Arch и линкует конфиги из этого репо.
#   ./install.sh          пакеты + сервисы + симлинки
#   ./install.sh --links  только симлинки (на уже готовой системе)
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"

PACMAN=(
    # база
    base-devel git curl jq
    # сессия
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    # звук, сеть, bluetooth
    pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils
    # утилиты, которые зовут бинды и шелл
    brightnessctl playerctl wl-clipboard cliphist wtype grim slurp swappy imagemagick
    gpu-screen-recorder ydotool libnotify trash-cli
    # терминал и консоль
    kitty fish starship fastfetch btop cava eza zoxide direnv
    # приложения из variables.lua
    thunar pavucontrol
    # шрифты, иконки
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji papirus-icon-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    zen-browser-bin clash-verge-rev-bin
)

# репо-путь → путь в $HOME
LINKS=(
    "config/hypr                                .config/hypr"
    "config/quickshell/demonshot                .config/quickshell/demonshot"
    "config/kitty                               .config/kitty"
    "config/btop                                .config/btop"
    "config/cava                                .config/cava"
    "config/fastfetch                           .config/fastfetch"
    "config/qtengine                            .config/qtengine"
    "config/starship.toml                       .config/starship.toml"
    "config/gtk-3.0/gtk.css                     .config/gtk-3.0/gtk.css"
    "config/gtk-4.0/gtk.css                     .config/gtk-4.0/gtk.css"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fontconfig/60-demonshot-cyrillic.conf .config/fontconfig/conf.d/60-demonshot-cyrillic.conf"
    "config/fonts                               .local/share/fonts/demonshot"
)

say() { printf '\e[38;2;199;48;61m✝\e[0m %s\n' "$*"; }

packages() {
    say "pacman"
    sudo pacman -Syu --needed --noconfirm "${PACMAN[@]}"

    if ! command -v yay >/dev/null; then
        say "yay"
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "aur"
    yay -S --needed --noconfirm "${AUR[@]}"
}

services() {
    say "сервисы"
    sudo systemctl enable NetworkManager bluetooth
    systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
    systemctl --user enable pipewire-pulse.socket wireplumber ydotool
    sudo usermod -aG input,video "$USER" # ydotool (uinput), brightnessctl
    xdg-user-dirs-update
}

links() {
    say "симлинки (старое → $BACKUP)"
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        [ "$(readlink "$dst")" = "$src" ] && continue
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
            mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        fi
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        echo "  $dst"
    done
    mkdir -p "$HOME/.config/demonshot" # rules.json шелл создаст сам
    fc-cache -f >/dev/null
}

[ "$EUID" -eq 0 ] && { echo "запускай от пользователя, sudo спросит сам"; exit 1; }

case "${1:-}" in
    --links) links ;; # на любом дистрибутиве (NixOS, Fedora…): пакеты тогда свои, список — в README
    "") command -v pacman >/dev/null || { echo "пакеты ставлю только на Arch; на другом дистрибутиве: $0 --links"; exit 1; }
        packages; services; links
        say "готово. перезагрузись и выбери Hyprland в sddm" ;;
    *) echo "usage: $0 [--links]"; exit 1 ;;
esac
