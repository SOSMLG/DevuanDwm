#!/usr/bin/env bash
# DEBSWAY_DESC: Shell extras: night-light (redshift), auto display (autorandr), media/brightness keys
# DEBSWAY_DEFAULT: Y
# =======================================================
# 20-shell-tools.sh — ambient shell affordances
# -------------------------------------------------------
# The small daemons and helpers that make a laptop desktop feel
# complete without heavyweight extras:
#
#   autorandr       automatic display profiles (docked/undocked)
#   brightnessctl   backlight control (XF86MonBrightness*)
#   playerctl       media key transport (XF86Audio*Play/Next/Prev)
#   iio-sensor-proxy auto-rotate via the laptop accelerometer
#
# Night light on this stack is redshift, which the dwm autostart
# already brings up (see suckless/scripts/autostart.sh); nothing
# to install here. Volume/mute live in the slstatus bar via pactl.
# Nothing in this step starts at login by itself — autostart.sh
# only launches what the session actually uses.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Shell extras — displays, media keys, sensors"

install_pkgs "Shell extras" \
    autorandr brightnessctl playerctl iio-sensor-proxy

# Record resolved paths for doctor/verify.
command -v autorandr >/dev/null 2>&1 && log_ok "autorandr: $(command -v autorandr)"
command -v playerctl >/dev/null 2>&1 && log_ok "playerctl: $(command -v playerctl)"

# ~/.local/bin is where the power-user commands and any per-user
# wrappers land; make sure it exists even on a lean base.
mkdir -p "$HOME/.local/bin"

echo
log_ok "Shell extras installed."
log_info "  Display profiles:   autorandr --save docked / --change"
log_info "  Backlight up/down:  brightnessctl set 10%+ / 10%-"
log_info "  Media keys:         playerctl play-pause / next / previous"