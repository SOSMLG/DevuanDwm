#!/usr/bin/env bash
# DEBSWAY_DESC: Gaming: Heroic (Flatpak), Steam (with i386 arch), Wine
# DEBSWAY_DEFAULT: Y
# =======================================================
# Gaming
# -------------------------------------------------------
#   heroic          Epic/GOG/Amazon launcher (Flatpak, from Flathub)
#   steam           Steam (apt; needs the i386 architecture enabled —
#                   Steam's own postinst is picky about it on Devuan,
#                   so we add the architecture up front)
#   wine (+wine64)  generic Windows games/legacy apps
#
# Flatpak needs the Flathub remote from steps/40-desktop-apps.sh;
# this step adds it defensively too. GPU acceleration comes from the
# mesa-vulkan-drivers in the base install; Steam's own SteamOS
# runtime handles most compatibility.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Gaming"

# ---- i386 architecture for Steam ---------------------------------------------
if dpkg --print-foreign-architectures 2>/dev/null | grep -qx i386; then
    log_ok "i386 architecture already enabled."
else
    log_info "Enabling i386 foreign architecture (needed by Steam)..."
    if priv dpkg --add-architecture i386 && apt_update; then
        log_ok "i386 architecture enabled and package lists refreshed."
    else
        log_err "Could not enable i386 — Steam will not install cleanly."
    fi
fi

install_pkgs "Steam" steam
install_pkgs "Wine" wine wine64

if command -v flatpak >/dev/null 2>&1; then
    flatpak remotes 2>/dev/null | grep -q flathub \
        || flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null \
        || log_warn "Heroic Flatpak install skipped/failed (network)."
else
    log_warn "flatpak not installed — skipping Heroic (run steps/40-desktop-apps.sh first)."
fi

echo
log_ok "Gaming done."
log_info "  Heroic flatpak id: com.heroicgameslauncher.hgl"