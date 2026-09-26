#!/usr/bin/env bash
# =======================================================
# Verify Setup — end-state audit (read-only)
# -------------------------------------------------------
# One-pass check of the toolkit's expected end state:
# group membership, dwm/slstatus/st builds, the Darkmatter
# config set, engineering stack, app defaults, and services.
# Run via `run.sh --verify` or standalone after a run.
#
# Prints PASS/FAIL/WARN and exits non-zero on any critical
# failure, so it can gate CI/validation.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PASS=0; FAIL=0; WARN=0

report() {  # report <name> <status> <detail>
    case "$2" in
        ok)
            printf '  PASS  %-44s %s\n' "$1" "${3:-}"
            PASS=$((PASS + 1))
            ;;
        fail)
            printf '  FAIL  %-44s %s\n' "$1" "${3:-}"
            FAIL=$((FAIL + 1))
            ;;
        warn)
            printf '  WARN  %-44s %s\n' "$1" "${3:-}"
            WARN=$((WARN + 1))
            ;;
    esac
}

pkg() {  # pkg <name> [critical|optional]
    local name="$1" level="${2:-critical}"
    local state detail
    if is_installed "$name"; then
        state="ok"; detail="installed"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "$name" "$state" "$detail"
}

bin() {  # bin <command> [critical|optional]
    local name="$1" level="${2:-critical}"
    local state detail
    if command -v "$name" >/dev/null 2>&1; then
        state="ok"; detail="$(command -v "$name")"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "bin: $name" "$state" "$detail"
}

cfg() {  # cfg <label> <path> [critical|optional]
    local label="$1" path="$2" level="${3:-critical}"
    local state detail
    if [ -f "$path" ]; then
        state="ok"; detail="present"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="missing (optional)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "cfg: $label" "$state" "$detail"
}

# service_state: enabled under systemd OR OpenRC; running via process name.
service_state() {
    local svc="$1" procname="$2" level="${3:-fail}"
    local enabled="" running=""
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        systemctl is-enabled "$svc" >/dev/null 2>&1 && enabled="systemd"
        systemctl is-enabled "${svc}.service" >/dev/null 2>&1 && enabled="systemd"
    elif { command -v rc-update >/dev/null 2>&1 || [ -x /usr/sbin/rc-update ]; } \
            && [ -d /run/openrc/softlevel ]; then
        /usr/sbin/rc-update show 2>/dev/null | awk -v s="$svc" '$1==s{found=1} END{exit !found}' && enabled="openrc"
    fi
    pgrep -x "$procname" >/dev/null 2>&1 && running="yes"

    if [ -n "$running" ]; then
        report "$svc (service)" ok "${enabled:-running, not enabled}"
    elif [ "$level" = "optional" ]; then
        report "$svc (service)" warn "not running"
    else
        report "$svc (service)" fail "not running"
    fi
}

log_head "dwm-setup verification"

echo -e "  (user: ${CYAN}${ACTUAL_USER}${NC})\n"

# --- 1. Groups --------------------------------------------------------------
for g in input video render plugdev; do
    if id -nG "$ACTUAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$g"; then
        report "group: $g" ok
    else
        report "group: $g" warn "user not in $g (re-run steps/12-user-groups.sh)"
    fi
done

# --- 2. Core dwm shell (install.sh + steps) ---------------------------------
for p in dwm st slstatus tabbed; do
    if [ -x "/usr/local/bin/$p" ]; then
        report "suckless: $p" ok "/usr/local/bin/$p"
    else
        report "suckless: $p" fail "not built — re-run install.sh"
    fi
done
if [ -x /usr/local/bin/dmenu ]; then
    report "suckless: dmenu" ok "/usr/local/bin/dmenu"
else
    report "suckless: dmenu" warn "/usr/local/bin/dmenu missing (re-run install.sh)"
fi

# --- 3. Darkmatter config set (suckless dir) ---------------------------------
SC="$HOME/.config/suckless"
cfg "dwm/config.def.h" "$SC/dwm/config.def.h"
cfg "slstatus/config.h" "$SC/slstatus/config.h"
cfg "dunst dunstrc" "$SC/dunst/dunstrc"
cfg "rofi config.rasi" "$SC/rofi/config.rasi"
cfg "kitty kitty.conf" "$SC/kitty/kitty.conf"
cfg "picom/picom.conf" "$SC/picom/picom.conf"
cfg "sxhkdrc" "$SC/sxhkd/sxhkdrc"

# Darkmatter does not just expect files — the colors are the identity.
# Spot-check the two most recognizable hexes in the shipped configs.
if grep -q "121113" "$SC/dunst/dunstrc" 2>/dev/null; then
    report "darkmatter: dunst bg" ok
else
    report "darkmatter: dunst bg" warn "not #121113 — re-run the theme step"
fi
if grep -q "e75353" "$SC/rofi/colors.rasi" 2>/dev/null; then
    report "darkmatter: rofi accent" ok
else
    report "darkmatter: rofi accent" warn "not #e75353 — re-run the theme step"
fi

# --- 3b. Screenshot / lock self-clean (the sticky-overlay fix) --------------
# The bare `flameshot gui` Print binding could leave the daemon alive and
# re-showing its selection window ("screenshot menu won't die"). Bound keys
# now run wrappers that kill the daemon afterwards, and slock runs through
# a lock script that does the same cleanup on lock.
pkg suckless-tools   # provides slock (dmenu/tabbed come from the suckless builds)
pkg flameshot
cfg "shot wrapper" "$SC/scripts/screenshot"
cfg "lock script" "$SC/scripts/lock"
if [ -x "$SC/scripts/screenshot" ] && [ -x "$SC/scripts/lock" ]; then
    report "shot/lock exec bit" ok
else
    report "shot/lock exec bit" fail "chmod +x $SC/scripts/{screenshot,lock}"
fi
if grep -q "pkill -x flameshot" "$SC/scripts/screenshot" 2>/dev/null; then
    report "shot self-clean" ok
else
    report "shot self-clean" fail "wrapper must kill the flameshot daemon"
fi
if grep -q "sxhkd" "$SC/scripts/autostart.sh" 2>/dev/null; then
    report "sxhkd autostarted" ok
else
    report "sxhkd autostarted" fail "autostart.sh must launch sxhkd"
fi

# --- 4. Devuan-safe init wiring ----------------------------------------------
if command -v rc-update >/dev/null 2>&1 || [ -x /usr/sbin/rc-update ]; then
    report "init: OpenRC" ok "rc-update present"
else
    report "init: OpenRC" fail "no rc-update — Devuan expected, check install"
fi
cfg "dwm session desktop" "/usr/share/xsessions/dwm.desktop"
cfg "dwm-session wrapper" "/usr/local/bin/dwm-session"

# --- 4b. Hardware support (13) ----------------------------------------------
for p in fwupd lm-sensors; do
    pkg "$p" optional
done
# firmware/microcode presence is hardware-dependent; just note what's there.
if [ -d /lib/firmware ] && ls /lib/firmware/*/ >/dev/null 2>&1; then
    report "firmware blobs (13)" ok "/lib/firmware populated"
else
    report "firmware blobs (13)" warn "no firmware blobs under /lib/firmware"
fi

# --- 4c. Desktop shell extras (20) -------------------------------------------
for p in autorandr brightnessctl playerctl iio-sensor-proxy; do
    pkg "$p" optional
done

# --- 4d. Firefox hardening (16) ----------------------------------------------
cfg "firefox policies.json" "/usr/lib/firefox-esr/distribution/policies.json" optional
cfg "betterfox user.js" "$HOME/.local/share/butterscripts/firefox/user.js" optional

# --- 5. Engineering stack (30-32) -------------------------------------------
for p in octave jupyter-notebook python3-scipy python3-sympy python3-pandas \
         scilab qucs kicad matlab-support cmake gcc g++ make git; do
    pkg "$p" optional
done
if [ -x "$HOME/.local/venv/eng/bin/python" ]; then
    if "$HOME/.local/venv/eng/bin/python" -c 'import control' >/dev/null 2>&1; then
        report "eng venv python-control" ok
    else
        report "eng venv python-control" warn "venv present, python-control missing (re-run steps/30-eng-math.sh)"
    fi
else
    report "eng venv ~/.local/venv/eng" warn "not created (re-run steps/30-eng-math.sh)"
fi

# --- 6. App defaults (40-47, optional roll = warn) ---------------------------
pkg flatpak optional
pkg timeshift optional
pkg opencode optional
pkg libreoffice-writer optional
pkg thunderbird optional
pkg keepassxc optional
pkg obs-studio optional
pkg kdenlive optional
pkg gimp optional
pkg steam optional
pkg wine optional
pkg codium optional
pkg neovim optional

# --- 7. Services -----------------------------------------------------------
# lightdm is the install.sh default, but a startx-launched dwm session
# (dwm-session wrapper) is equally supported — a missing DM is a warning,
# not a failure.
service_state lightdm lightdm optional
service_state bluetooth bluetoothd optional
service_state tlp tlp optional
service_state cups cupsd optional
service_state NetworkManager NetworkManager optional

echo
echo -e "${GREEN}  ${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
if [ "$FAIL" -gt 0 ]; then
    echo
    log_err "Some checks failed — see lines above, then re-run the relevant step."
    exit 1
fi
exit 0