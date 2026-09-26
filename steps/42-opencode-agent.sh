#!/usr/bin/env bash
# DEBSWAY_DESC: OpenCode AI agent (npm install path on this fork) + PATH + optional dwm hotkey note
# DEBSWAY_DEFAULT: Y
# =======================================================
# AI: OpenCode
# -------------------------------------------------------
# Installs OpenCode (https://opencode.ai) — an open-source,
# terminal-based AI coding agent (bring your own API key, or use
# its free tier). This fork avoids piping the official installer to
# a shell from a step script (a hard rule here: nothing remote is
# ever piped into bash on install), so it goes through npm — the
# same artifact, installed for the user.
#
# Also drops a plain system "skill"/AGENTS file describing this
# box, so OpenCode (and Claude Code) start with the right context.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "AI: OpenCode"

# ---- npm path (no curl|bash from a step) -------------------------------------
if command_exists opencode; then
    log_ok "OpenCode already installed ($(opencode --version 2>/dev/null || echo 'version unknown'))."
else
    command_exists npm || install_pkgs "Node.js + npm" nodejs npm
    if command_exists npm; then
        if ask "Install OpenCode via npm?"; then
            if priv npm install -g opencode-ai; then
                log_ok "OpenCode installed via npm."
            else
                log_warn "npm install failed. The other path is the official installer from a"
                log_warn "terminal YOU run:  curl -fsSL https://opencode.ai/install | bash"
            fi
        else
            log_warn "Skipped OpenCode installation."
        fi
    else
        log_warn "npm not available — install nodejs/npm, or run the official installer:"
        log_warn "  curl -fsSL https://opencode.ai/install | bash"
    fi
fi

# ---- ensure ~/.opencode/bin and ~/.local/bin are on PATH for dwm sessions ----
for CANDIDATE in "$HOME/.opencode/bin" "$HOME/.local/bin"; do
    if [ -d "$CANDIDATE" ] && ! grep -qF "$CANDIDATE" "$HOME/.profile" "$HOME/.bashrc" 2>/dev/null; then
        printf 'export PATH="%s:$PATH"\n' "$CANDIDATE" >> "$HOME/.profile"
        log_ok "Added $CANDIDATE to PATH in ~/.profile"
    fi
done

# ---- dwm hotkey: nothing the script can edit live (keybinds live in the
#      compiled config.h), so print the exact line to add. --------------------
DWM_HOTKEY_HINT='{ MODKEY, XK_a, spawn, SHCMD("st -e opencode") },'
log_info "dwm hotkey (optional): add this line to the keys[] table in"
log_info "  ~/.config/suckless/dwm/config.def.h  then rebuild (make clean install):"
log_info "      $DWM_HOTKEY_HINT"

# ---- system skill / AGENTS file ----------------------------------------------
if ask "Install a system 'skill' file so AI tools know this is a Debian/dwm box?"; then
    SKILL_SRC="$SCRIPT_DIR/../AGENTS.md"
    if [ -f "$SKILL_SRC" ]; then
        mkdir -p "$HOME/.config/opencode"
        cp "$SKILL_SRC" "$HOME/.config/opencode/AGENTS.md" 2>/dev/null \
            && log_ok "Installed to ~/.config/opencode/AGENTS.md"
        if [ ! -f "$HOME/AGENTS.md" ]; then
            cp "$SKILL_SRC" "$HOME/AGENTS.md" 2>/dev/null \
                && log_ok "Also installed to ~/AGENTS.md."
        fi
    else
        log_warn "AGENTS.md not found next to the repo — skipping."
    fi
fi

echo
log_ok "OpenCode step complete."
log_info "Run 'opencode auth login' once to connect a provider; then just 'opencode'."