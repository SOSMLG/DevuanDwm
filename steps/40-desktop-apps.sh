#!/usr/bin/env bash
# DEBSWAY_DESC: Desktop apps: Flatpak, CUPS, firewall, office-lite, media, torrent, mpv/zathura, TLP + battery cap, TUI tools
# DEBSWAY_DEFAULT: Y
# =======================================================
# 40-desktop-apps.sh — day-to-day applications (lean set)
# -------------------------------------------------------
# Everything a general-purpose laptop needs that isn't the WM
# shell itself:
#
#   flatpak + Flathub        user-space apps (secondary source)
#   cups + printer drivers   printing
#   gufw                     firewall, enabled with sane defaults
#   mpv  (VLC as fallback)   video
#   zathura + mupdf          PDF
#   qbittorrent              torrents
#   TLP + 80% battery cap    battery care (thinkpad_acpi)
#   btop/eza/bat/zoxide/fd   everyday TUI tools
#
# Heavy or niche apps live in their own steps (43-47). This one is
# the "works everywhere" baseline.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Desktop applications (lean set)"

install_pkgs "Utility apps" \
    flatpak gparted qbittorrent gufw \
    cups cups-pdf printer-driver-gutenprint \
    mpv vlc \
    zathura zathura-pdf-mupdf \
    btop eza bat zoxide fd-find ripgrep

# ---- Flatpak + Flathub (devuan ships flatpak; add the remote if missing) ----
if command -v flatpak >/dev/null 2>&1; then
    flatpak remotes 2>/dev/null | grep -q flathub \
        || flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    log_ok "Flathub remote ensured."
else
    log_warn "flatpak not on PATH after install."
fi

# ---- TLP + charge cap (even when not on a ThinkPad, TLP is a no-op) ----------
install_pkgs "Battery care" tlp tlp-rdw powertop
start_service tlp
if [ -d "/sys/class/power_supply" ] && [ -n "$(ls /sys/class/power_supply 2>/dev/null | head -1)" ]; then
    for bat in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
        if [ -w "$bat/charge_control_end_threshold" ]; then
            printf '%s' 80 > "$bat/charge_control_end_threshold" 2>/dev/null \
                && log_ok "Battery charge cap set to 80% ($bat)."
        fi
    done
fi

echo
log_ok "Desktop apps installed."
log_info "  Updates here are plain apt:  doas apt-get update && doas apt-get upgrade"
log_info "  Flatpak apps update with:    flatpak update"
log_info "  TLP status:                  doas tlp-stat -s"