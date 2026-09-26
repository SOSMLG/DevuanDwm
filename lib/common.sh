#!/bin/bash
# lib/common.sh — shared helpers for the dwm-setup fork.
# Grafted from devuan-wm-setup (priv/install_pkgs/backup guards) and
# DebianSway (log_head/start_service/verify_download) so every step
# speaks the same doas-first, apt-cache-checked language. Sourced by
# run.sh and each steps/##-*.sh. No side effects at source time.

# Double-source guard — steps re-source defensively; skip the re-run.
[ -n "${DEBSWAY_COMMON_SOURCED:-}" ] && return 0
DEBSWAY_COMMON_SOURCED=1

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# Plain (un-bracketed) line — install.sh's banner/status lines.
msg() { echo -e "${CYAN}$1${NC}"; }

log_head() {
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}=========================================================${NC}"
}

die() { log_err "$*"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# have_priv / priv — doas first, sudo fallback; DEBSWAY_PRIV=doas|sudo
# forces one. Never write bare sudo in new code.
have_priv() { command_exists doas || command_exists sudo; }

priv() {
    local tool="${DEBSWAY_PRIV:-}"
    if [ -z "$tool" ]; then
        if command_exists doas; then tool=doas; else tool=sudo; fi
    fi
    "$tool" "$@"
}

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

require_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        log_err "Do not run this as root — run it as your normal user; it escalates itself (doas, sudo fallback)."
        exit 1
    fi
    if ! have_priv; then
        log_err "Neither doas nor sudo found — install one, then re-run."
        exit 1
    fi
    # Minimal installs often ship an escalator the user can't actually use
    # (sudo with no group, doas without a rule). Warn early with the fix —
    # never fatal, the user may know better.
    if ! id -nG 2>/dev/null | grep -qwE "sudo|wheel|doas" \
       && ! grep -qw "$USER" /etc/doas.conf 2>/dev/null; then
        log_warn "Your user is in no privilege group (sudo/wheel) and /etc/doas.conf names no rule for $USER."
        log_warn "Escalation will likely fail. As root, fix with ONE of:"
        log_warn "  usermod -aG sudo $USER            # Debian stock path"
        log_warn "  printf 'permit persist $USER as root\n' > /etc/doas.conf   # BSD-minimal path"
    fi
}

# Real (non-root) user even if invoked via escalation upstream.
ACTUAL_USER="${SUDO_USER:-${DOAS_USER:-$USER}}"
[ -z "$ACTUAL_USER" ] && ACTUAL_USER="$(id -un)"

run_as_user() {
    if [ "$(id -un)" = "$ACTUAL_USER" ]; then
        "$@"
    else
        priv -u "$ACTUAL_USER" "$@"
    fi
}

# --- user interaction ------------------------------------------------------

# ask() — "Y/n" (default Y) or "y/N" (default N). With DEBSWAY_ASSUME_YES
# set (run.sh --yes / install.sh) the default is taken without prompting.
ask() {
    local prompt="$1" default="${2:-Y}" reply
    local hint="(Y/n)"
    [ "$default" = "N" ] && hint="(y/N)"
    if [ -n "${DEBSWAY_ASSUME_YES:-}" ]; then
        reply="$default"
    else
        read -rp "$(echo -e "${YELLOW}${prompt} ${hint}: ${NC}")" reply
        reply=${reply:-$default}
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

# --- packaging -------------------------------------------------------------

# pkg_available — 0 if a candidate exists in the apt cache (read-only).
# Steps call this before touching the package list so a typo or a
# Debian/Devuan naming drift fails loudly instead of mid-apt.
pkg_available() {
    command -v apt-cache >/dev/null 2>&1 || return 1
    [ -n "$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2}')" ]
}

# install_pkgs <label> <pkgs...> — installs only what's missing, only what
# exists in the apt cache. Unknown packages are skipped with a warning,
# never fatal. Returns 0 if everything ended up installed.
install_pkgs() {
    local label="$1"; shift
    local to_install=() pkg
    for pkg in "$@"; do
        if is_installed "$pkg"; then
            continue
        fi
        if ! pkg_available "$pkg"; then
            log_warn "skip '$pkg': not in apt cache (rename or extra repo needed)"
            continue
        fi
        to_install+=("$pkg")
    done
    if [ "${#to_install[@]}" -eq 0 ]; then
        log_ok "$label already installed."
        return 0
    fi
    log_info "$label: installing ${to_install[*]}"
    priv apt-get install -y "${to_install[@]}" || {
        log_warn "$label: some packages failed to install (continuing)."
        return 1
    }
    log_ok "$label installed."
    return 0
}

# apt_update — refresh package lists exactly once per run. run.sh updates
# once up front and exports DEBSWAY_SKIP_APT_UPDATE=1 so per-step refreshes
# become no-ops; standalone step runs still refresh here.
apt_update() {
    [ -n "${DEBSWAY_SKIP_APT_UPDATE:-}" ] && return 0
    if command_exists apt-get; then
        priv apt-get update "$@"
    else
        log_err "apt-get not found — this needs a Debian/Devuan APT system."
        return 1
    fi
}

# check_repo_package — probe availability before install, with a hint about
# the common cause (missing non-free-firmware / contrib component).
check_repo_package() {
    local probe="$1" component="$2"
    local cand
    cand="$(apt-cache policy "$probe" 2>/dev/null | awk -F': ' '/Candidate:/{gsub(/ /,"",$2); print $2; exit}')"
    if [ -n "$cand" ] && [ "$cand" != "(none)" ]; then
        return 0
    fi
    log_warn "$probe is not available — the '$component' repo component is probably missing."
    log_warn "Add the component to your sources (/etc/apt/sources.list.d), run"
    log_warn "'apt-get update' as root, then re-run this step."
    return 1
}

# ensure_repo_component <component> [suite] — make an APT component
# (non-free-firmware, contrib) available, adding a dwm-setup snippet if the
# configured sources lack it. Idempotent; never edits existing files.
ensure_repo_component() {
    local comp="$1" suite="${2:-}"
    local srcd="${APT_SOURCES_D:-/etc/apt/sources.list.d}"
    . /etc/os-release 2>/dev/null || true
    local id="${ID:-debian}"
    [ -z "$suite" ] && suite="${VERSION_CODENAME:-}"
    if [ -z "$suite" ]; then
        log_warn "ensure_repo_component: cannot detect suite codename."
        return 1
    fi
    if apt-cache policy 2>/dev/null | grep -Eq "(^|[, ])c=${comp}([, ]|$)"; then
        return 0
    fi
    log_info "APT component '$comp' missing — adding ${srcd}/dwm-setup-${comp}.sources ..."
    local uris="http://deb.debian.org/debian" sig=""
    if [ "$id" = "devuan" ]; then
        uris="http://deb.devuan.org/merged"
    else
        sig=$'\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg'
    fi
    mkdir -p "$srcd" 2>/dev/null || priv mkdir -p "$srcd"
    if [ -f "$srcd/dwm-setup-${comp}.sources" ]; then
        priv cp -a "$srcd/dwm-setup-${comp}.sources" "$srcd/dwm-setup-${comp}.sources.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    priv tee "$srcd/dwm-setup-${comp}.sources" > /dev/null << EOF
# Written by dwm-setup (ensure_repo_component) — base suite + '$comp'.
# Safe to delete once your main sources carry this component themselves.
Types: deb
URIs: $uris
Suites: $suite
Components: main contrib non-free non-free-firmware${sig}
EOF
    priv apt-get update || { log_warn "apt-get update failed after adding '$comp'."; return 1; }
    apt-cache policy 2>/dev/null | grep -Eq "(^|[, ])c=${comp}([, ]|$)"
}

# --- services (init-agnostic, OpenRC-first on Devuan) -----------------------

# start_service <svc> [action] — enable+start under whatever init actually
# runs (systemd, OpenRC or sysvinit). Never assumes systemctl exists.
# Actions: enable|disable|start|stop|restart (default: enable+start).
# sbin tools are called by absolute path — an escalator's PATH may not
# include /usr/sbin.
start_service() {
    local svc="$1" action="${2:-}"
    local wants_enable=1 wants_action="${action:-start}"
    case "$action" in
        disable) wants_enable=0; wants_action=stop ;;
        start|stop|restart|enable) wants_enable=0; wants_action="$action" ;;
    esac
    if command_exists systemctl && [ -d /run/systemd/system ]; then
        case "$wants_action:$wants_enable" in
            restart:*) priv systemctl restart "$svc" >/dev/null 2>&1 || true ;;
            stop:*)    priv systemctl disable --now "$svc" >/dev/null 2>&1 || true ;;
            *)         priv systemctl enable --now "$svc" >/dev/null 2>&1 || true ;;
        esac
    elif { command_exists rc-service || [ -x /usr/sbin/rc-service ]; } \
            && [ -d /run/openrc/softlevel ]; then
        if [ "$wants_enable" -eq 1 ]; then
            priv /usr/sbin/rc-update add "$svc" default >/dev/null 2>&1 || true
            priv /usr/sbin/rc-service "$svc" start >/dev/null 2>&1 || true
        else
            case "$wants_action" in
                stop)    priv /usr/sbin/rc-update del "$svc" default >/dev/null 2>&1 || true ;;
                restart) priv /usr/sbin/rc-service "$svc" restart >/dev/null 2>&1 || true ;;
                *)       priv /usr/sbin/rc-service "$svc" "$wants_action" >/dev/null 2>&1 || true ;;
            esac
        fi
    else
        # sysvinit fallback.
        if command_exists update-rc.d || [ -x /usr/sbin/update-rc.d ]; then
            [ "$wants_enable" -eq 1 ] && priv /usr/sbin/update-rc.d "$svc" defaults >/dev/null 2>&1 || true
            [ "$wants_action" = "stop" ] && priv /usr/sbin/update-rc.d -f "$svc" remove >/dev/null 2>&1 || true
        fi
        if command_exists service || [ -x /usr/sbin/service ]; then
            priv /usr/sbin/service "$svc" "$wants_action" >/dev/null 2>&1 || true
        fi
    fi
}

# --- doas rule (BSD-minimal privilege path) ---------------------------------
# doas.conf(5): last match wins, default deny — one explicit line is the
# whole policy. `persist` caches a successful auth for ~5 min so a long
# install asks once, upfront.
ensure_doas_persist() {
    local user="${1:-$ACTUAL_USER}"
    local conf="${DOAS_CONF:-/etc/doas.conf}"
    local want="permit persist $user as root"
    if [ -z "$user" ] || [ "$user" = "root" ]; then
        log_err "ensure_doas_persist: refusing bad user '$user'."
        return 1
    fi
    if [ -f "$conf" ] \
        && grep -Eq "^[[:space:]]*permit\b.*\bpersist\b.*\b$user\b" "$conf" 2>/dev/null; then
        log_ok "doas persist rule already present for '$user' ($conf)."
        if [ "$(stat -c%a "$conf" 2>/dev/null || echo '')" != "600" ]; then
            priv chmod 600 "$conf" 2>/dev/null \
                || log_warn "Could not chmod 600 $conf."
        fi
        return 0
    fi
    log_info "Ensuring doas persist rule: '$want' in $conf ..."
    if [ -f "$conf" ]; then
        priv cp -a "$conf" "$conf.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    if printf '%s\n' "$want" | priv tee -a "$conf" >/dev/null \
        && priv chmod 600 "$conf" 2>/dev/null; then
        if command_exists doas && ! priv doas -C "$conf" >/dev/null 2>&1; then
            log_warn "doas -C rejects $conf — check its syntax."
        fi
        log_ok "doas persist rule added for '$user' (root-owned, mode 600)."
        return 0
    fi
    log_err "Could not write $conf (no working escalator)."
    log_warn "As root, run: printf '$want\n' >> $conf && chmod 600 $conf"
    return 1
}

# --- download verification --------------------------------------------------

# sha256_verify — strict check where upstream publishes a known-good hash.
sha256_verify() {
    local file="$1" expected="$2"
    [ -f "$file" ] || { log_err "sha256_verify: $file not found"; return 1; }
    local actual
    actual="$(sha256sum "$file" | cut -d' ' -f1)"
    if [ "$actual" = "$expected" ]; then
        log_ok "sha256 verified for $(basename "$file")."
        return 0
    fi
    log_err "sha256 MISMATCH for $(basename "$file")."
    log_err "  got:      $actual"
    log_err "  expected: $expected"
    return 1
}

# verify_download — structural plausibility check for fetched files
# (catches truncation, HTML error pages, 404 bodies). Not a substitute for
# sha256_verify where upstream publishes hashes. Always logs the sha256 so
# you can compare it against a release page manually.
# Usage: verify_download <file> [min-size-bytes]  (min default 1024)
verify_download() {
    local file="$1"
    local min_size="${2:-1024}"
    [ -f "$file" ] || { log_err "verify_download: $file not found."; return 1; }

    local size
    size="$(stat -c%s "$file" 2>/dev/null || echo 0)"
    if [ "$size" -lt "$min_size" ]; then
        log_err "$(basename "$file") looks empty/truncated (${size} bytes)."
        return 1
    fi

    case "$file" in
        *.deb)
            if ! dpkg-deb --info "$file" >/dev/null 2>&1; then
                log_err "$(basename "$file") is not a valid .deb package."
                return 1
            fi
            ;;
        *.tar.gz|*.tgz)
            if ! tar -tzf "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid tar.gz."; return 1; fi
            ;;
        *.tar.bz2)
            if ! tar -tjf "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid tar.bz2."; return 1; fi
            ;;
        *.tar.xz)
            if ! tar -tJf "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid tar.xz."; return 1; fi
            ;;
        *.tar)
            if ! tar -tf "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid tar."; return 1; fi
            ;;
        *.zip)
            if ! unzip -t "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid zip."; return 1; fi
            ;;
        *.gz)
            if ! gzip -t "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid gzip."; return 1; fi
            ;;
        *.xz)
            if ! xz -t "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid xz."; return 1; fi
            ;;
        *.bz2)
            if ! bzip2 -t "$file" >/dev/null 2>&1; then log_err "$(basename "$file") is not a valid bz2."; return 1; fi
            ;;
    esac

    log_ok "Download verified: $(basename "$file") (${size} bytes)."
    return 0
}