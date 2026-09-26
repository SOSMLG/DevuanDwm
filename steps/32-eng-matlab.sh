#!/usr/bin/env bash
# DEBSWAY_DESC: Matlab prep: matlab-support + `matlab-install` helper for a MathWorks .deb
# DEBSWAY_DEFAULT: Y
# =======================================================
# 32-eng-matlab.sh — the proprietary bridge
# -------------------------------------------------------
# MathWorks doesn't publish Matlab in apt, and its installer needs
# your account credentials — so this step cannot fetch the bits for
# you. What it DOES do is make the day you download them trivial:
#
#   * installs `matlab-support` — integrates a Matlab .deb (the
#     mex/LD_BRIDGE, launcher, icon, /usr/local/bin/matlab) cleanly
#     into a Debian/Devuan system
#   * drops a tiny `matlab-install` helper in ~/.local/bin that takes a
#     MathWorks .deb you downloaded, verifies it and installs it with
#     dpkg -i (recommends frobbing the run script so it binds the
#     venv'd numpy/scipy, but leaves your system python alone)
#
# The toolkit never fetches MathWorks content — download the Linux
# installer from <https://www.mathworks.com/downloads/> in your browser,
# unpack it, and run `./install` inside — or grab the pre-built
# `R20XXxUpdateX_<hash>.deb` when the MathWorks page offers one.
#
# Idempotent: safe to re-run.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Matlab preparation"

install_pkgs "Matlab support" matlab-support

# ---- one-shot helper for the day you download the .deb -----------------------
mkdir -p "$HOME/.local/bin"
HELPER="$HOME/.local/bin/matlab-install"
cat > "$HELPER" <<'HELPER_EOF'
#!/bin/sh
# matlab-install <MathWorks...deb> — verify + install a Matlab .deb.
# Written by steps/32-eng-matlab.sh; safe to delete if you never use it.
set -eu
[ $# -eq 1 ] || { echo "usage: matlab-install <Matlab_*.deb>" >&2; exit 1; }
[ -f "$1" ] || { echo "not a file: $1" >&2; exit 1; }
dpkg-deb --info "$1" >/dev/null 2>&1 || { echo "not a valid .deb: $1" >&2; exit 1; }
if command -v doas >/dev/null 2>&1; then doas dpkg -i "$1"; else sudo dpkg -i "$1"; fi
echo "Matlab installed. If MEX needs the scipy/numpy venv, edit the run script to source ~/.local/venv/eng/bin/activate first."
HELPER_EOF
chmod +x "$HELPER"
log_ok "Wrote $HELPER"

echo
log_ok "matlab-support installed — system ready for a MathWorks .deb."
log_info "  1) Download a Linux Matlab .deb from mathworks.com (account required)."
log_info "  2) Run:   matlab-install /path/to/Matlab_*.deb   — verifies and attaches it."
log_info "  Alternatively unpack the MathWorks archive and run ./install inside it."