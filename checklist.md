# Fork Smoke-Test Checklist

End-to-end pass for the fork, run on a fresh Devuan 6 (or Debian 13) box.
Tick `[x]` as you go; any `[ ]` left at the end needs investigation before
a release. This is the "does the daily driver actually drive" test, so most
of it is manual.

## Step 0 — sync the test machine

```bash
cd <repo-clone>
git checkout main && git pull
./install.sh                 # base: packages, config copy, suckless builds
# log out, log back in, pick "dwm" at LightDM
```

To re-test just the config side on an already-built box, `./install.sh
--only-config` covers it (no packages/services touched).

## Phase 1 — Boot sanity

- [ ] LightDM greeter shows a `dwm` session and login works
- [ ] Bar appears with all 12 tags and the slstatus line (wifi, cpu, ram, disk, battery, clock)
- [ ] Wallpaper is set (feh ran — default `andromeda-2.png`)
- [ ] `pgrep -x dwm slstatus picom dunst lxpolkit redshift-gtk xfce4-power-manager` — all present, no duplicates after a `Super + Shift + r`
- [ ] `~/.xsession-errors` is clean of dwm/session errors

## Phase 2 — The bar

- [ ] Status text updates (CPU/RAM move; clock advances)
- [ ] Status draws on **all** monitors (multi-monitor only — `statusallmons`)
- [ ] Layout symbol visible on the left (default: dwindle 󰕴), window-follow glyph `>`/`v` next to it
- [ ] `bar restart` / `Super + Ctrl + r` (sxhkd up) bounces slstatus cleanly
- [ ] `Super + Ctrl + b` hides and restores the bar

## Phase 3 — Core dwm bindings

- [ ] `Super + Return` → **st** opens (not kitty)
- [ ] `Super + p` → dmenu opens, Darkmatter colors (`-nb #121113`, `-sb #e75353`)
- [ ] `Print` → flameshot region screenshot lands in `~/Screenshots/`
- [ ] `Super + j` / `k` focus next/prev window; `Super + Shift + j` / `k` move in stack
- [ ] `Super + q` closes the focused window
- [ ] `Super + Shift + f` fullscreen toggle; `Super + Shift + Space` floating toggle
- [ ] `Super + y` sticky toggle; `Super + n` window-follow flip (glyph flips `>` ↔ `v`)
- [ ] `Super + Tab` returns to the previous tag
- [ ] `Super + apostrophe` → rofi window switcher lists windows across tags

## Phase 4 — Layouts & resize

- [ ] `Shift + Ctrl + 1..=` cycles the 12 layouts, symbol updates on the bar
- [ ] `Shift + Ctrl + 3` → columnlayout (side-by-side columns, full height)
- [ ] In columns, `Super + h` / `l` widen/narrow the focused column (cfact)
- [ ] In tile, `Super + h` / `l` shift the master split; `Super + ;` resets both
- [ ] `Super + Alt + Tab` / `Super + Alt + Shift + Tab` change master count
- [ ] `Super + Shift + l` (sxhkd) → the rofi layout menu fires the right combo

## Phase 5 — Tags & monitors

- [ ] `Super + 1..9, 0, -, =` view tags 1..12; `Super + Shift + <key>` sends the window
- [ ] `Super + Ctrl + <key>` toggles tag visibility (combined views)
- [ ] `Ctrl + Shift + Left/Right` view adjacent tag; `Alt + Ctrl + Left/Right` send window across
- [ ] (multi-monitor) `Super + ,` / `.` focus monitors; `Super + Shift + ,` / `.` send windows

## Phase 6 — Scratchpads

- [ ] `` Super + ` `` → st scratchpad spawns first time, toggles after
- [ ] `Super + v` → pulsemixer scratchpad toggles
- [ ] `Super + Alt + 1` → scratch slot 1 spawns (tabbed container)
- [ ] Open thunar, `Super + Alt + Shift + 1` → promoted into slot 1; `Super + Alt + 1` toggles it
- [ ] `` Super + Alt + Shift + ` `` clears scratch state on the focused window
- [ ] `Super + Alt + Shift + s` promotes the focused window straight to scratchpad

## Phase 7 — Gaps

- [ ] `Super + Alt + 0` kills gaps, second press restores
- [ ] `Super + Alt + u` grows them, `Super + Alt + Shift + u` shrinks
- [ ] `Super + Alt + 6..9` (+ Shift) adjust inner/outer per-axis gaps
- [ ] `Super + Alt + Shift + 0` resets to defaults without clearing a scratch window

## Phase 8 — Restart preservation

- [ ] Windows on tags 2, 5, 8 in different layouts, one promoted to a scratch slot
- [ ] `Super + Shift + r` → dwm restarts, tags/windows/layouts/scratch all survive

## Phase 9 — Help overlay

- [ ] `Super + /` → rofi keybind overlay opens
- [ ] Sections present: LAUNCH, WINDOW, LAYOUT, TAGS, MONITOR, SCRATCHPAD, GAPS, SYSTEM
- [ ] Pinned (`!`) entries render at the top of their section; both dwm and sxhkd rows appear (sxhkd rows only if `sxhkdrc` rows match `# === name ===` sections)

## Phase 10 — Wallpaper / theming

- [ ] Start sxhkd, then `Super + Shift + p` → dmenu lists the 5 bundled wallpapers
- [ ] Pick one — wallpaper changes, dunst respawns with the Darkmatter frame, dwm recolors in place (no re-exec)
- [ ] `~/.Xresources` has one `! BEGIN dwm-thememenu` … `! END dwm-thememenu` block, no stacking after repeated picks
- [ ] `grep e75353 ~/.config/suckless/rofi/colors.rasi` matches; `~/.cache/dwm/current_wallpaper` holds the pick
- [ ] New st and kitty windows use the palette; `xrdb -query` shows `dwm.selbgcolor: #e75353`
- [ ] `autostart.sh` now sets the picked wallpaper; logout/login keeps it

## Phase 11 — sxhkd layer (optional daemon)

- [ ] `sxhkd &` starts; `Super + Space` → rofi drun; `Super + b` → firefox-esr; `Super + f` → thunar; `Super + e` → codium
- [ ] Volume: `XF86AudioRaiseVolume` / `Super + F12` → `changevolume up` with dunst progress bar; mute works
- [ ] Brightness: `XF86MonBrightnessUp/Down` move the backlight
- [ ] `Super + x` → power menu; `Shutdown` asks loginctl, cancel closes cleanly
- [ ] `Super + Shift + n` toggles the NM connection editor
- [ ] `Super + w` attaches the focused window to a tab group; `Super + Shift + w` detaches; empty container destroys itself
- [ ] `Super + Escape` reloads sxhkd with a notification

## Phase 12 — Steps + verification

On the test box, run the full kit and confirm the audit passes:

```bash
./run.sh --full
./run.sh --verify        # or: bash verify.sh
```

- [ ] `--full` finishes with no failed steps; `last-run.log` shows `result  ok`
- [ ] verify.sh: 0 FAIL (warnings allowed for optional apps you skipped)
- [ ] Groups: `id -nG` includes input, video, render, plugdev after a reboot
- [ ] `/usr/local/bin` holds dwm, st, slstatus, tabbed, dmenu
- [ ] Darkmatter spot-checks pass (dunst `#121113`, rofi `#e75353`)
- [ ] Spot-check a step: `octave --version`, `python3 -c "import control"` inside `~/.local/venv/eng`, `codium --version`, `opencode --version` (if you ran those phases)
- [ ] A second run of `./run.sh --full` is a no-op apart from re-checks (idempotence)

## When something fails

1. Note the phase and what happened before touching anything.
2. Bindings dead in Phase 3? They're compiled in — check `config.def.h` and
   rebuild (`make && doas make install`).
3. sxhkd rows missing? `pgrep -ax sxhkd`, and run
   `sxhkd -c ~/.config/suckless/sxhkd/sxhkdrc` in the foreground to see
   parse errors.
4. dwm crashes or misbehaves: `~/.xsession-errors`, or run dwm from a tty
   to get the error on screen. `Super + Shift + r` restarts it in place.
5. Report back with the log tail from `~/.local/state/dwm-setup/last-run.log`.