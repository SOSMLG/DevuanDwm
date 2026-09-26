#!/bin/sh

# dwm autostart — runs at session start and again on dwm SIGHUP restart
# (Mod+Shift+r). Every daemon is guarded with `pgrep -x` so re-runs are
# no-ops instead of spawning duplicates.

# ---- wallpaper (one-shot: feh exits after setting the bg) ----
feh --bg-fill "$HOME/.config/suckless/wallpaper/andromeda-2.png" &

# ---- polkit agent ----
pgrep -x lxpolkit >/dev/null || lxpolkit &

# ---- native-bar status text (dwm reads the root window name) ----
pgrep -x slstatus >/dev/null || slstatus &

# ---- compositor (shadows, fading, rounded corners) ----
pgrep -x picom >/dev/null || picom --config "$HOME/.config/suckless/picom/picom.conf" -b &

# ---- notifications ----
pgrep -x dunst >/dev/null || dunst -config "$HOME/.config/suckless/dunst/dunstrc" &

# ---- night light (geoclue2, as configured for XFCE) ----
pgrep -x redshift-gtk >/dev/null || redshift-gtk &

# ---- power / battery / brightness (ThinkPad) ----
pgrep -x xfce4-power-manager >/dev/null || xfce4-power-manager &

# ---- hotkey daemon (sxhkd — app shortcuts; dwm owns window management) ----
pgrep -x sxhkd >/dev/null || sxhkd -c "$HOME/.config/suckless/sxhkd/sxhkdrc" &
