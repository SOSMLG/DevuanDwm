#!/usr/bin/env bash

# dwm-setup — Devuan 6 (Excalibur) + dwm
# https://github.com/SOSMLG/dwm-setup
#
# One-command, unattended installer: packages, config, suckless builds,
# session wrapper, lightdm, Thunar helper. App phases (engineering,
# desktop apps, media, gaming, chat, editors) run separately via
# `./run.sh --full` — this file owns the base system only.
#
# Devuan-safe by construction: no `apt upgrade` (you pick the upgrade
# moment), no systemctl (OpenRC/sysvinit via start_service), no install
# scripts fetched over the network (everything runs from a file on disk),
# no bare sudo (doas first, sudo fallback).

set -uo pipefail

# --- Command line options ----------------------------------------------------
ONLY_CONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --only-config)
            ONLY_CONFIG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --only-config      Only copy config + rebuild suckless (skip packages/services)"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root

CONFIG_DIR="$HOME/.config/suckless"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dwm-setup-install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# --- OS check (packages are named for trixie; excalibur is binary-compatible) --
if [ "$ONLY_CONFIG" = false ]; then
    . /etc/os-release 2>/dev/null || die "Cannot read /etc/os-release to verify OS"
    case " $ID ${ID_LIKE:-} " in
        *" ubuntu "*) die "Unsupported OS: ${PRETTY_NAME:-unknown}. Ubuntu-based systems are not supported." ;;
    esac
    # Devuan (excalibur) carries no /etc/debian_version; accept it by ID
    # before falling back to the numeric Debian check.
    if [ "$ID" != "devuan" ]; then
        DEBIAN_BASE=$(cat /etc/debian_version 2>/dev/null || true)
        case "$DEBIAN_BASE" in
            13|13.*) ;;
            *) die "Unsupported OS: ${PRETTY_NAME:-unknown}. This installer requires a Debian 13 (trixie) base, or Devuan 6 (excalibur) (found: ${DEBIAN_BASE:-no /etc/debian_version})." ;;
        esac
    else
        msg "Devuan detected: ${PRETTY_NAME:-unknown} — OpenRC service handling active."
    fi
fi

# --- Banner -----------------------------------------------------------------
clear
msg "\n  dwm-setup — the Darkmatter dwm daily driver\n"
msg "  https://github.com/SOSMLG/dwm-setup\n"
msg "  Packaging for Devuan 6 (excalibur) / Debian 13 (trixie)\n"

if [ -z "${DEBSWAY_ASSUME_YES:-}" ]; then
    read -p "Install DWM? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# --- Packages (dwm/slstatus/st/tabbed/dmenu built from source below) ---------
PACKAGES=(
    # core
    xorg xorg-dev xbacklight xbindkeys xvkbd xinput
    build-essential sxhkd xdotool dbus-x11
    libnotify-bin libnotify-dev

    # ui
    picom rofi dunst feh
    nwg-look xsettingsd network-manager-gnome lxpolkit

    # display manager (greeter + session wiring)
    lightdm lightdm-gtk-greeter

    # file manager
    thunar thunar-archive-plugin thunar-volman
    gvfs-backends gvfs-fuse dialog mtools smbclient cifs-utils unzip

    # audio (pulseaudio-utils: pactl/paplay for the bar's mic pill + chime)
    pavucontrol pulsemixer pamixer pipewire-audio pulseaudio-utils

    # utilities (redshift: night light · brightnessctl: panel slider on
    # laptops · sound-theme-freedesktop: pomodoro alarm sound)
    avahi-daemon acpi acpid xfce4-power-manager
    flameshot qimgv xdg-user-dirs-gtk fd-find
    redshift brightnessctl sound-theme-freedesktop

    # terminal tools
    eza firefox-esr kitty

    # fonts
    fonts-recommended fonts-font-awesome fonts-terminus

    # build deps
    cmake meson ninja-build curl pkg-config wget
)

# Bluetooth stack only where hardware exists (kernel exposes the adapter in
# sysfs without bluez). Added a dongle later? apt install bluez
# libspa-0.2-bluetooth
if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
    PACKAGES+=(bluez libspa-0.2-bluetooth)
fi

if [ "$ONLY_CONFIG" = false ]; then
    # === One password prompt, cached for the whole run =====================
    msg "Priming privilege escalation (doas persist) — one prompt, then cached..."
    ensure_doas_persist "$ACTUAL_USER"

    # !== no bare apt upgrade ================================================
    # The user picks the upgrade moment; boxes that want updates run
    # `run.sh`'s daily-list refresh + their own upgrade on demand.
    msg "Updating package lists only (no upgrade) ..."
    apt_update || { log_warn "apt-get update failed — continuing anyway (stale lists may break installs)."; }

    # Purge the distro dwm (6.5) so /usr/bin/dwm never shadows our build
    # in /usr/local/bin, and no upgrade resurrects stock dwm.desktop.
    if is_installed dwm; then
        msg "Purging distro 'dwm' package (our source build supersedes it)..."
        priv apt-get purge -y dwm
    fi

    msg "Installing packages..."
    install_pkgs "dwm-setup base packages" "${PACKAGES[@]}" \
        || log_warn "Some packages failed to install — see the log."

    # === Services (OpenRC on Devuan) ========================================
    start_service avahi-daemon
    start_service acpid
    start_service bluetooth  # no-op where the hardware check skipped bluez

    # Display manager: exactly one DM owns the console. Ensure lightdm is
    # the one (SLiM/greetd must not be enabled alongside).
    start_service lightdm

    # Daily apt list refresh (download only, never installs) so slstatus'
    # pending-updates check can discover upgrades on its own. Guarded: don't
    # clobber existing periodic config (e.g. unattended-upgrades).
    if [ ! -f /etc/apt/apt.conf.d/02periodic ]; then
        echo 'APT::Periodic::Update-Package-Lists "1";' \
            | priv tee /etc/apt/apt.conf.d/02periodic >/dev/null
        msg "Enabled daily apt list refresh (02periodic)"
    fi

    # lightdm user-session: dwm. Ships as a conf.d snippet so the packaged
    # lightdm.conf defaults stay intact.
    LIGHTDM_CONF="/etc/lightdm/lightdm.conf.d/50-dwm-session.conf"
    if [ ! -f "$LIGHTDM_CONF" ]; then
        if priv mkdir -p /etc/lightdm/lightdm.conf.d; then
            printf '[Seat:*]\nuser-session=dwm\n' | priv tee "$LIGHTDM_CONF" >/dev/null
            msg "lightdm user-session set to dwm ($LIGHTDM_CONF)"
        fi
    else
        msg "lightdm session snippet already present ($LIGHTDM_CONF)"
    fi
else
    msg "Skipping package installation (--only-config mode)"
fi

# === Config =================================================================
# Shipped configs carry the static Darkmatter look; the wallpaper picker
# (wallpaper-theme) re-applies it from any of the bundled wallpapers.

# Handle existing config: always back up before touching it.
if [ -d "$CONFIG_DIR" ]; then
    read -p "Found existing suckless config. Backup? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv "$CONFIG_DIR" "$CONFIG_DIR.bak.$(date +%s)"
        msg "Backed up existing config"
    else
        read -p "Overwrite without backup? (y/n) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || die "Installation cancelled"
        rm -rf "$CONFIG_DIR"
    fi
fi

msg "Setting up configuration..."
mkdir -p "$CONFIG_DIR"
cp -r "$SCRIPT_DIR"/suckless/* "$CONFIG_DIR"/ || die "Failed to copy configs"
# The wallpaper dir is part of the config tree now (bundled, not cloned from
# a remote); wallpaper-theme writes relative to the same root.

# === Build suckless tools ===================================================
# dwm, slstatus, st, tabbed and dmenu all build from the repo copy. The
# xresources patch reads ~/.Xresources at dwm startup, so a bare install
# (no wallpaper-theme run yet) still gets the Darkmatter colors compiled in.
msg "Building suckless tools..."
for tool in dwm slstatus st tabbed dmenu; do
    cd "$CONFIG_DIR/$tool" || die "Cannot find $tool"
    if make >/dev/null && priv make install >/dev/null; then
        msg "  ✓ built $tool"
    else
        die "Failed to build $tool"
    fi
done

# === Session wrapper ========================================================
# Exports session-scoped env (KITTY_CONFIG_DIRECTORY) before dwm starts —
# autostart.sh can't reach dwm's own spawn() children.
priv install -m755 "$CONFIG_DIR/scripts/dwm-session" /usr/local/bin/dwm-session

# === Desktop entries ========================================================
# Skip in --only-config mode since they likely already exist.
if [ "$ONLY_CONFIG" = false ]; then
    priv mkdir -p /usr/share/xsessions
    cat <<EOF | priv tee /usr/share/xsessions/dwm.desktop >/dev/null
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager
Exec=dwm-session
Type=XSession
EOF

    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/st.desktop" <<EOF
[Desktop Entry]
Name=st
Comment=Simple Terminal
Exec=st
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF
else
    msg "Skipping desktop entry creation (--only-config mode)"
fi

# === User dirs ==============================================================
xdg-user-dirs-update 2>/dev/null || true
mkdir -p "$HOME/Screenshots"

# === Thunar "Open Terminal Here" via exo's TerminalEmulator helper ==========
# Register kitty as that helper so it doesn't fall back to a chooser dialog.
mkdir -p "$HOME/.config/xfce4" "$HOME/.local/share/xfce4/helpers"
cat > "$HOME/.local/share/xfce4/helpers/kitty.desktop" <<EOF
[Desktop Entry]
NoDisplay=true
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
X-XFCE-Category=TerminalEmulator
X-XFCE-Commands=kitty
X-XFCE-CommandsWithParameter=kitty -e %s
Icon=kitty
Name=kitty
EOF
if grep -q '^TerminalEmulator=' "$HOME/.config/xfce4/helpers.rc" 2>/dev/null; then
    sed -i 's/^TerminalEmulator=.*/TerminalEmulator=kitty/' "$HOME/.config/xfce4/helpers.rc"
else
    echo 'TerminalEmulator=kitty' >> "$HOME/.config/xfce4/helpers.rc"
fi

# Thunar custom action (right-click menu) — only seeded if the user has none,
# so existing custom actions are never clobbered.
if [ ! -f "$HOME/.config/Thunar/uca.xml" ]; then
    mkdir -p "$HOME/.config/Thunar"
    cat > "$HOME/.config/Thunar/uca.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
	<icon>utilities-terminal</icon>
	<name>Open Terminal Here</name>
	<submenu></submenu>
	<unique-id>$(date +%s%N)-1</unique-id>
	<command>kitty --directory %f</command>
	<description>Open kitty in this folder</description>
	<range></range>
	<patterns>*</patterns>
	<startup-notify/>
	<directories/>
</action>
</actions>
EOF
fi

# === Asset packages =========================================================
# Nerd Fonts + codecs + bluetooth audio etc. are step-scoped (17/15/14) so
# the base install stays lean; run `./run.sh --full` (or --phase core,apps)
# after this to bring the box to the full daily-driver state.
if [ "$ONLY_CONFIG" = false ]; then
    msg "Base system installed."
    msg "App phases run separately:  ./run.sh --full"
    msg "  (engineering math/EDA, desktop apps, media, gaming, chat, editors)"
fi

# Ensure ~/.local/bin is on PATH for display-manager logins.
# DM sessions source ~/.xsessionrc but never ~/.profile, so user-built tools
# in ~/.local/bin would otherwise be unfindable when launched from the WM.
if ! grep -qs '.local/bin' "$HOME/.xsessionrc" 2>/dev/null; then
    msg "Ensuring ~/.local/bin is on PATH via ~/.xsessionrc..."
    cat >> "$HOME/.xsessionrc" <<'XSESSIONRC_EOF'

# Added by dwm-setup: ensure ~/.local/bin is on PATH
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
esac
XSESSIONRC_EOF
fi

# === Done ===================================================================
echo -e "\n${GREEN}Installation complete!${NC}"
echo "1. Log out and select 'dwm' from lightdm (user-session is already set)"
echo "2. Press Super + / for keybindings"
echo "3. App phases: ./run.sh --full"
echo "   Install log: $LOG_FILE"