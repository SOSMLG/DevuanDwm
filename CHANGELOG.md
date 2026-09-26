# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Everything below the fork entry documents the upstream (justaguy.dev)
project this was cut from. The fork keeps that history intact, but where the
entry conflicts with what this repo does today, **the fork wins** — the
quickshell bar, the butter* tooling, and the wallpaper-driven theming engine
do not exist here.

## [2026-09-26] — Pre-push audit: file-mode normalization

Git tracked nearly the whole `suckless/` tree as executable (C sources, man
pages, `.diff` patches, Makefiles, even READMEs — 116 files at `100755`),
while the actual entrypoints `run.sh` and `verify.sh` were tracked at
`100644` — a fresh clone couldn't even run `./verify.sh` (exit 126,
"Permission denied"), and `run.sh` needed `bash` to invoke.

- **116 files back to `100644`**: `suckless/{dwm,st,slstatus,tabbed,dmenu,
  dunst}` sources/docs/patches, `rofi/*.rasi`, `picom.conf`.
- **`run.sh` + `verify.sh` → `100755`** (invoked as `./run.sh`/`./verify.sh`
  everywhere in the docs); `install.sh` already correct.
- **`README.md` → `100644`** (was erroneously executable).
- `suckless/scripts/*` kept `100755` — those are executed directly by
  autostart/sxhkd.
- Verified: `./verify.sh` now runs standalone (65 passed / 0 failed);
  `dwm` rebuilt clean from `config.def.h`; mode changes are content-free
  (0 lines).

## [2026-09-24] — dwm gaps round: sticky-flameshot fix, lock, sxhkd

Follow-up hardening on the fork — the same bug class as the sway/wofi
"Screenshot menu won't die" incident, and the concrete gaps found while
auditing against the sway-switch effort.

### Fixed
- **The screenshot overlay can no longer stick.** The bare
  `Print → flameshot gui` binding left flameshot's daemon alive after the
  client exited; it could re-show its selection window at random, and there
  was no way to kill it. `Print`, `Super + Print` and `Super + Ctrl + Print`
  now run `scripts/screenshot` (region / full / copy), a wrapper that
  `pkill -x flameshot` after the capture settles — nothing persists across
  lock or logout.
- **Screen lock exists and is clean.** `Super + Shift + l` runs
  `scripts/lock` (`pkill -x flameshot` then `slock`). Previously slock was
  installed but had no keybinding, so a stuck overlay could survive an
  unlock — the exact dwm mirror of the sway bug.
- **Panic key.** `Super + Ctrl + Escape` kills any stuck flameshot overlay
  (mirrors sway's `$mod+Ctrl+Escape` → `swayctl kill`).
- **sxhkd actually starts.** `autostart.sh` now launches it
  (`sxhkd -c ~/.config/suckless/sxhkd/sxhkdrc`, pgrep-guarded for SIGHUP
  restarts). The whole app-shortcut layer (`Super + s`, `Super + Shift + s`,
  `Super + x`, volume keys) was previously dead unless started by hand.
  The screenshot bindings in `sxhkdrc` route through the same wrapper.
- **verify.sh** now guards slock/flameshot, the wrapper scripts' presence
  and exec bits, the self-clean line, the sxhkd autostart line, and treats
  a missing `sxhkdrc` as a failure (it is load-bearing now).

### Changed
- Keybindings document regenerated (`gen-keybinds`); the new bindings are
  pinned in `config.def.h` with @help descriptors.

## [2026-09-24] — Fork: dwm-setup (SOSMLG)

This is the fork: a Devuan-first rework of the dwm setup, published as
SOSMLG/dwm-setup. The headline change is direction, not just code — the
project moved from a Qt bar with live, wallpaper-derived theming to a static
Darkmatter dwm with the native bar.

### Changed
- **The bar is native again.** quickshell (and `quickshell-network`) are
  gone entirely; the bar is dwm's own, fed by slstatus — status2d color
  blocks for wifi, CPU, RAM, disk, battery and clock. `showbar` is back to
  1, `showsystray` to 0 so slstatus owns the bar; the systray patch stays in
  the tree but off. The old `Super + Ctrl + b` toggle now just toggles the
  native bar.
- **Static Darkmatter theming replaces the wallpaper-driven engine.** The
  QML palette extraction (beacon detection, semantic ANSI slots,
  pre-generated palettes) is removed. The palette is fixed — background
  `#121113`, accent `#e75353`, JetBrainsMono Nerd Font — and compiled into
  every config. The `wallpaper-theme` script survives but now re-applies
  that same palette from a bundled set of matching Darkmatter wallpapers
  (`suckless/wallpaper/`) to Xresources (dwm + st), rofi, dunst and kitty.
  GTK is no longer recolored; dunst respawn and the `_DWM_RELOADCOLORS`
  in-place recolor are kept.
- **st is the default terminal.** `termcmd` now spawns st; kitty is demoted
  to a themed secondary, with its config kept session-scoped via
  `KITTY_CONFIG_DIRECTORY` in the `dwm-session` wrapper.
- **dwm rebuilt for the fork.** 22 patches across from the live build —
  status2d (with bar padding), cool-autostart, systray, xresources,
  vanitygaps, scratchtagwins, namedscratchpads, per-client columnlayout,
  window-follow, movestack, sticky and the rest. `dwm/config.def.h` is the
  single source of truth for bindings; the Makefile regenerates
  `keybindings.txt` from the annotated `keys[]` table via
  `scripts/gen-keybinds` on every build.
- **dmenu is built and bound** to `Super + p` (`dmenu_run`), colored from
  the same palette. rofi keeps the app menu, window switcher, help overlay
  and power menu.
- **Devuan/OpenRC-first installer.** `install.sh`, `run.sh` and
  `verify.sh` were rewritten around the DebianSway/common.sh conventions:
  doas-first privilege with sudo fallback (never bare sudo), an
  init-agnostic `start_service()` that speaks OpenRC on Devuan, and no
  `systemctl` calls anywhere. `install.sh` owns the base system only and
  deliberately never runs `apt upgrade`. App layers moved to the `run.sh`
  step runner.
- **Stepped app phases.** Steps live in `steps/##-*.sh`, grouped into
  phases by leading digit (1x core, 3x engineering, 4x apps), each carrying
  `DEBSWAY_DESC:` / `DEBSWAY_DEFAULT:` headers read by `run.sh --list`.
  Flags: `--list`, `--phase`, `--only`, `--yes`, `--full`, `--no-update`,
  `--verify` (runs `verify.sh`). State log at
  `~/.local/state/dwm-setup/last-run.log`. The phase set — engineering math
  (Octave/Jupyter/SciPy + `python-control` venv), EDA, Matlab prep, desktop
  apps, timeshift, opencode, office/mail, media, gaming (i386 before
  Steam), chat (Vesktop/Telegram Flatpaks) and editors — carries over from
  the DebianSway lineage.
- **`verify.sh`** is a read-only end-state audit: group membership,
  `/usr/local/bin` suckless binaries (dwm, st, slstatus, tabbed, dmenu),
  Darkmatter hex spot-checks in dunstrc and rofi, OpenRC presence, the
  lightdm `user-session=dwm` wiring, and optional package checks.
- **Login wiring:** LightDM greeter with `user-session=dwm`, session
  wrapper `/usr/local/bin/dwm-session`, Thunar "Open Terminal Here" via a
  kitty helper, `~/.xsessionrc` PATH for `~/.local/bin`.
- **Docs rewritten.** README is self-contained (no wiki, no Gitea/Forgejo
  shields); QUICKSTART, CONTRIBUTING and the checklist now describe the
  fork's actual workflow.

### Removed
- quickshell bar + `quickshell-network` (QML, IPC, layout picker sliders,
  command menu, beacon-aware extraction).
- `polybar/` configs and the wallpaper-derived palette files.
- The 12-theme switcher (`dwm-thememenu`, `Super + Shift + T`) and the
  `dwm/themes/` tree from 2026-05-15.
- butter* tooling references (butterknife, butterscripts) — installs now
  run from files on disk; nothing remote is piped into bash.

### Added
- `suckless/dmenu/` (built with the other five tools).
- `suckless/wallpaper/` — the bundled Darkmatter wallpaper set.
- The `weather` script (rofi front-end for the bar's weather readout, state
  in two plain files).

---

## [2026-08-27]

> **Fork note (2026-09-24):** this entry describes wallpaper-derived live
> theming — beacon-aware palette extraction, semantic ANSI slots, palettes
> pre-generated from the default wallpaper. None of that exists in the
> fork, which uses the static Darkmatter palette described above. The
> `wallpaper-theme` concurrency lock and the `_DWM_RELOADCOLORS` in-place
> recolor do survive, in adapted form.

### Changed
- **One theming system: the wallpaper dictates the colors.** The rofi
  theme switcher (`dwm-thememenu`, `Super+Shift+T`) and the 12 curated
  themes under `dwm/themes/` are removed — the wallpaper picker
  (`Super+Shift+P`) covers every target the switcher handled: bar,
  rofi, dunst, kitty, GTK, dwm + st colors. The `~/.Xresources` block
  markers still read `dwm-thememenu` so upgraded installs replace the
  old block instead of stacking a second one.
- **The default look is generated from the default wallpaper.** Every
  shipped palette file (`rofi/colors.rasi`, `polybar/colors.ini`,
  dunst's THEME lines, kitty's `current-theme.conf`) and dwm's
  compiled color defaults in `config.def.h` are pre-baked from
  `wallhaven-ym7d3l` with the picker's own extraction engine — first
  login is themed before the picker ever runs, and the installer no
  longer seeds a theme.

### Added
- **Beacon-aware palette extraction** (shared `WallpaperPicker.qml`, all
  three quickshell ports): before the histogram picks the accent, a
  beacon check looks for a small, bright, hue-distinct cluster — a
  lamp, neon sign, or sunset sliver. When one exists it becomes the
  accent (semantically the image's point, even at a handful of pixels)
  and the dominant field hue steps down to secondary; without one,
  extraction is byte-identical to before. Validated by a 50-wallpaper
  sweep: 14 images changed (lighthouse beam, streetlights, a gold
  medallion), 36 untouched.

- **Window-follow toggle in the bar** (`Follow.qml`): the native bar's
  `>`/`v` wfsymbol indicator returns as a clickable module next to the
  layout button — arrow lit means sends follow the window. Backed by
  `_DWM_FOLLOW`/`_DWM_SETFOLLOW`; `Mod+n` stays in sync.

- **Semantic ANSI slots** (shared `WallpaperPicker.qml`): extracted hues
  now land in their nearest semantic terminal slot — green things stay
  green, blue things blue — instead of filling slots in vibrancy order,
  so color-coded output (diffs, ls, test runners) keeps meaning on any
  wallpaper. Slots the image has no hue near are synthesized at the
  slot's canonical hue — at a deliberately quieter saturation than the
  image's own hues, so guest colors never outshine earned ones. Sweep-validated: average hue error vs canonical
  dropped 89° → 9° across 51 wallpapers, zero accent regressions.
- **One notch less pastel**: the terminal wash saturation raised
  (0.3 → 0.4, brights 0.42) and the accent's pastel ceiling lifted
  (0.45 → 0.55) — same hues, a little more body.

### Fixed
- **Wallpaper picks no longer restart dwm.** A new `_DWM_RELOADCOLORS`
  atom (extbar patch §18g) re-reads Xresources and restyles in place —
  borders, bar schemes — so theming keeps your selected tags and all
  pertag state. `Super+Shift+r` still does a full restart.
- **Restarts landed on tag 1**: the extbar patch's atom seeding ran
  before `restoremonitortagsets()` and overwrote the saved view.
  Restore now runs first; `Super+Shift+r` returns to the tags you were
  on.
- `wallpaper-theme` serializes concurrent runs (two rapid picker
  clicks used to interleave writes and leave the desktop half from
  each image). The lock is inheritance-safe: respawned daemons (dunst,
  xsettingsd) no longer hold it after the script exits, and a bounded
  wait means a leaked lock can only delay, never deadlock.

## [2026-08-26]

> **Fork note (2026-09-24):** the quickshell shell, the `quickshell-extbar`
> patch wiring, and the network front-end described here were removed in the
> fork. The bar is native, fed by slstatus; the patch itself remains in the
> tree but only its `_DWM_RELOADCOLORS` recolor atom is used.

Quickshell bar port (third home for the shared shell, after bspwm-setup and
openbox-setup). After pulling, rebuild dwm and re-copy configs:

```bash
cd ~/.config/suckless/dwm && rm -f config.h && sudo make clean install
```

### Added
- **quickshell shell** vendored at `suckless/quickshell/` +
  `suckless/quickshell-network/` per the portability contract
  (`suckless/quickshell/README.md`): bar, popups, wallpaper-driven live
  theming, network app. Launched from `autostart.sh` (`qs -n` makes the
  SIGHUP re-run a no-op). Right-click empty bar = height/scale sliders.
- **quickshell-extbar dwm patch** (`patches/dwm-quickshell-extbar.diff`,
  modifications.txt §18): dock windows adopted unmanaged with
  `_NET_WM_STRUT_PARTIAL` honored live (height slider re-tiles);
  `_NET_CURRENT_DESKTOP`/`_NET_WM_DESKTOP` ClientMessages handled (bar
  clicks work via xdotool); `_DWM_SELTAGS` root atom carries the raw
  tagset bitmask; `_DWM_MONTAGS` now written live; every client tag
  change fires a root PropertyNotify heartbeat.
- **Layout button + picker in the bar** (`LayoutButton.qml`,
  `LayoutPicker.qml`): current layout shown as its config.h glyph —
  scroll cycles, click opens a grid of all fifteen layouts, the three
  keybind-less ones included. Backed by two new extbar-patch atoms
  (modifications.txt §18e): `_DWM_LAYOUT` publishes the current
  layouts[] index (pertag-aware — follows tag switches), and writing an
  index to `_DWM_SETLAYOUT` applies a layout via plain `xprop -set`.
  The rofi menu (`Super+Shift+l`) still works as a fallback.
- **Desktop sliders in the layout picker** (modifications.txt §18f):
  window gap (live via `_DWM_SETGAPS`, persisted to a `dwm-gaps` state
  file that `autostart.sh` re-applies after every dwm restart — theme
  changes SIGHUP dwm, so without this gaps would reset on every
  wallpaper switch), master width and master count (pertag: they tweak
  the focused tag, like the keybinds — and they dim in layouts whose
  arrange function ignores mfact/nmaster, dwindle-on-nmaster included).
  Keybind changes (`Mod+Alt+u`, `Mod+Alt+Tab`) stay in sync with the
  sliders. Border width stays compile-time — no slider. The extbar
  patch now also touches `vanitygaps.c` (one hook in `setgaps`).
- **One tweaks popup**: the bar height / element scale sliders moved
  into the layout picker (Bar section), and right-click on empty bar
  now opens that same popup — `BarTweaks.qml` retired (openbox keeps
  its own). The `tweaks` IPC target still works, aliased to the picker.
- **Fix**: keyboard multi-tag views (`toggleview`) never refreshed
  `_DWM_SELTAGS`, so the bar missed `Super+Ctrl+N` tag combinations.
- **`scripts/wallpaper-theme`** (shared, dwm tail): palette from the
  wallpaper → bar (live), rofi, dunst, kitty, GTK, and the same
  `! BEGIN dwm-thememenu` Xresources block thememenu owns (dwm + st
  colors), then dunst respawn + `pkill -HUP dwm`. `Super+Shift+p` opens
  the picker; `dwm-thememenu` (`Super+Shift+t`) coexists, last run wins.
- **`dwm-session`** login wrapper (`Exec=dwm-session` in dwm.desktop):
  exports `KITTY_CONFIG_DIRECTORY=~/.config/suckless/kitty` so theming
  recolors a vendored kitty config (`suckless/kitty/`), not the global
  one. Installer runs butterscripts `install_kitty.sh --no-config`.
- **`Super+Shift+n`**: network app (quickshell NetworkManager front-end).
- Installer: quickshell package via butterrepo (skipped when `qs` is
  already on PATH); seeded `suckless/polybar/colors.ini` palette.

### Changed
- **Native bar retired to fallback**: `showbar=0`, `showsystray=0` (the
  QML bar carries an SNI tray), slstatus line commented in autostart.
  `Mod+Ctrl+b` still toggles the native bar back.
- dunst per-urgency frame markers de-aliased (`frame_low/normal/critical`
  instead of three `frame_global` copies) — thememenu's per-urgency
  frame colors now actually apply.
- `dwm-thememenu` wallpaper sed matches any `feh --bg-*` mode so it can
  overwrite wallpaper-theme's `--bg-fill` line.
- `tagtoleft`/`tagtoright` now call `setclienttagprop()` (client
  `_NET_CLIENT_INFO` previously went stale on those keybinds).

## [2026-05-15]

> **Fork note (2026-09-24):** the 12-theme switcher (`dwm-thememenu`,
> `Super + Shift + T`) and `suckless/dwm/themes/` are gone in the fork —
> there is one theme, static Darkmatter. The xresources patch, status2d,
> ewmhtags, scratchtagwins, dwmtabs and the custom features below
> (columnlayout, togglefollow, resizefocused, 12 tags) all remain, as does
> `modifications.txt` §13 for the Xresources color names. The rebuild
> commands shown use `sudo`; the fork is doas-first.

Major dev-branch merge. After pulling, rebuild everything:

```bash
cd ~/.config/suckless/dwm      && rm -f config.h && sudo make clean install
cd ~/.config/suckless/st       && rm -f config.h && sudo make clean install
cd ~/.config/suckless/slstatus && rm -f config.h && sudo make clean install
cd ~/.config/suckless/tabbed   && rm -f config.h && sudo make clean install
```

### Added
- **Theme system**: 12 themes under `suckless/dwm/themes/` (catppuccin, doomone, dracula, everforest, github_dark, gruvbox, kanagawa, monokai, moonfly, nord, retro, rose_pine). Bound to `Super + Shift + t` via the new `dwm-thememenu` rofi script. Each theme directory holds `dwm.xresources`, `theme.conf` (wallpaper + ghostty/wezterm/GTK/icon/dunst metadata) and `colors.rasi`. Theme switching merges Xresources, swaps wallpaper / dunst / rofi / ghostty / wezterm / GTK, signals `st` (SIGUSR1) for live recolor, and `pkill -HUP dwm` to re-exec with `preserveonrestart`.
- **xresources patch**: dwm reads `dwm.normbgcolor`, `dwm.selbgcolor`, etc. from `~/.Xresources` at startup; restart with `Super + Shift + r` to pick up new values.
- **statusallmons patch**: status bar draws on every monitor, gated by a `statusallmons` config constant.
- **fakefullscreen patch**: `lockfullscreen = 0` plus tighter `_NET_WM_STATE_TOGGLE` handling.
- **ewmhtags patch + per-client `_NET_WM_DESKTOP`**: rofi window switcher (Super + apostrophe) now shows the tag number for each window via `{w}` in `window-format`.
- **scratchtagwins patch (9 slots) + window-promotion**: `Super + Alt + 1..9` toggles tabbed scratch slot N, `Super + Alt + Shift + 1..9` promotes the focused window into slot N, `Super + Alt + Shift + grave` clears scratch state.
- **dwmtabs (C tool)**: native libX11/Xinerama replacement for the previous bash `dwm-tabs` script. Built by the dwm Makefile. Subcommands: `attach`, `detach`, `create`. Bound to `Super + w` / `Super + Shift + w` via sxhkd. Per-monitor logic uses XineramaQueryScreens; matches `dwm-tabbed` WM_CLASS to find existing containers.
- **slstatus v1.1**: upstream pull. Includes wifi-component rewrite and netspeed component.
- **Custom dwm features** (see `suckless/dwm/modifications.txt` for hand-merge details):
  - **columnlayout**: i3-style side-by-side columns weighted by per-client `cfact`.
  - **togglefollow**: `Super + n` toggles whether tag/monitor sends follow the window; indicator `>`/`v` on the bar.
  - **resizefocused** + **resetfacts**: `Super + h` / `l` is layout-aware (mfact in tile, cfact in columnlayout); `Super + ;` resets both.
  - **12 tags**: tags 1–9 + 0, minus, equals (was 9).
  - **Per-rule `iscentered`**: alwayscenter is now opt-in via the rule table.
- **st patches**: `st-xresources` + `st-xresources-signal-reloading` for live theme reload via SIGUSR1.

### Changed
- **dwm patch set audit (2026-05-15)**: removed 4 unused .diff files from `suckless/dwm/patches/` — `dwm-focusedontop-6.6.diff` (never applied), `dwm-maximize_vert_horz-20160731-56a31dc.diff` (never applied), `dwm-fullscreen-6.2.diff` (superseded by 2026-01-12 variant), `dwm-status2d-systray-6.4.diff` (superseded by the barpadding-systray variant). 25 → 21 patches.
- **fullscreen patch upgrade**: now using the 2026-01-12 variant which checks the active layout via `pertag->ltidxs` instead of the bar state, fixing a toggle-logic loop.
- **status2d-barpadding-systray patch**: replaces the older status2d-systray; adds `vertpad` / `sidepad` for bar padding.
- **rofi theming**: every rofi `.rasi` now `@import "colors.rasi"`; theme switch drops a new `colors.rasi` into `~/.config/suckless/rofi/` instead of regenerating each `.rasi` from a template. Killed the codegen.
- **sxhkd rework**: removed all chord-mode bindings (the ~3s super-disabled lockout felt unresponsive). Dropped `PRINT` key. Layout/theme menus and dwmtabs attach/detach moved off chords onto direct combos.
- **Keybind reshuffle to coexist with sxhkd**: `togglebar` → `Super + Ctrl + b`; `togglesticky` → `Super + y`; `incnmaster` → `Super + Alt + Tab` / `Super + Alt + Shift + Tab`. Dropped redundant Mod+t/f/m layout shortcuts in favor of `Shift + Ctrl + 1..=`. See `modifications.txt` §10 for the full table.
- **changevolume / power scripts**: updated.
- **st mouse wheel**: plain wheel scrolls scrollback (no Shift needed). `Button4` / `Button5` rebound from `ShiftMask` to `XK_ANY_MOD` → `kscrollup` / `kscrolldown`.
- **st scrollback buffer**: 2000 → 10000 lines (`HISTSIZE`).
- **dwm help script**: pinned-entry support — prefix a description with `!` in `keybindings.txt` or `sxhkdrc` to render it at the top of its section.
- **README** + **CHANGELOG**: brought current with the dev-branch state. Keybind table, patches table, configuration-files tree, theme-system section all rewritten.
- **`.gitignore`**: switched to allow-by-default policy at the repo root.

### Removed
- 4 stale dwm patches (see Changed § audit).
- `suckless/dwm/maximize.c` (the maximize patch was never applied; helper file was orphaned).
- `suckless/dwm/dwm.c.rej` (stale patch reject from an earlier merge attempt).
- `suckless/dwm/resume.txt` (stray Claude session-id file).
- Bash `dwm-tabs` script (replaced by C `dwmtabs`).

### Fixed
- **dwmtabs detach**: detaches the focused tab, not always the first tab in the container.

### Notes
- If you add custom themes, drop them under `~/.config/suckless/dwm/themes/<name>/` with at least `dwm.xresources` and `theme.conf`; the theme switcher picks them up automatically.
- The 6 dwm color names in `~/.Xresources` are `normbgcolor`, `normfgcolor`, `normbordercolor`, `selbgcolor`, `selfgcolor`, `selbordercolor`. See `modifications.txt` §13.

## [2025-08-25]

### Changed
- Updated README.md documentation
- Cleaned up repository by removing config.h (using config.def.h instead)
- Improved .gitignore files to protect special files without extensions
- Removed compiled object files and executables from repository

### Fixed
- File protection for special files in .gitignore (PR #3 by [@JeffofBread](https://github.com/JeffofBread))

## [2025-08-20]

### Changed
- Updated install.sh to remove bashrc option
- Refactored installer for better functionality

## [2025-07-02]

### Changed
- Removed wallpaper from repository but added to script functionality
- Updated install.sh

### Removed
- install.sh.orig file (cleanup)

## [2025-06-15]

### Added
- install_minimal.sh script for minimal installation option

### Changed
- Major refactoring to make setup more suckless-compliant
- Updated README.md documentation
- Multiple improvements to install_minimal.sh

## [2025-05-31]

### Changed
- Multiple updates and improvements to install.sh

## [2025-05-23]

### Changed
- Updated install.sh
- Made dunstrc configuration more streamlined

## [2025-05-22]

### Added
- Native scratchpad terminal (spterm3) mapped to Mod+Shift+Return
  - Replaces tdrop dependency for floating terminal functionality
  - Third scratchpad with different floating behavior (isfloating=0)
- Fullscreen toggle functionality (Mod+Shift+f)
  - Switches between last layout and monocle mode
  - Automatically hides/shows status bar

### Changed
- Updated scratchpad rules to include isfloating parameter
- Removed tdrop command from sxhkd configuration
- Updated install.sh (removed 25 lines for cleanup/optimization)

### Removed
- Dependency on tdrop for floating terminal

## [2025-05-21]

### Changed
- Updated README.md documentation

### Removed
- Deprecated st-alpha patch (st-alpha-20220206-0.8.5.diff)

## [2025-05-20]

### Added
- New installer script with improved functionality
- Initial dwm configuration with multiple patches:
  - alwayscenter
  - attachbottom
  - cool-autostart
  - fixborders
  - focusadjacenttag
  - focusedontop
  - focusonnetactive
  - movestack
  - pertag
  - preserveonrestart
  - restartsig
  - scratchpads
  - status2d-systray
  - togglefloatingcenter
  - vanitygaps
  - windowfollow
- st (simple terminal) with patches:
  - alpha transparency
  - anysize
  - bold-is-not-bright
  - clipboard
  - delkey
  - font2
  - scrollback
  - scrollback-mouse
- slstatus configuration
- dunst notification daemon configuration
- picom compositor configuration
- rofi launcher configuration
- sxhkd hotkey daemon configuration
- Collection of wallpapers
- Helper scripts:
  - autostart.sh
  - changevolume
  - discord.sh
  - dwm-layout-menu.sh
  - firefox-latest.sh
  - help
  - librewolf-install.sh
  - neovim.sh
  - power
  - redshift-off/on

### Changed
- Updated install.sh with improved installation process
- Enhanced README documentation

### Removed
- Deprecated st-alpha patch (st-alpha-20220206-0.8.5.diff)