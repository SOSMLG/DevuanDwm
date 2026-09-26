# QUICKSTART — dwm-setup (Darkmatter)

You just installed the base system and logged into a dwm session. Here's the
short version of how to live here.

## First things first

- **`Super + /` is the whole manual.** It opens a searchable rofi list of
  every binding, dwm and sxhkd merged. When you're lost, press it.
- `Super + Return` opens a terminal — **st**, the default. kitty is there
  too, if you prefer it; the theme matches.
- `Super + p` launches dmenu, `Print` takes a region screenshot with
  Flameshot. `Super + q` closes whatever's focused.
- The bar at the top is dwm's own, fed by slstatus: wifi, CPU, RAM, disk,
  battery, clock. Nothing to maintain.

One honest caveat: several convenience keys — the rofi app menu
(`Super + Space`), the browser bound to `Super + b`, volume and brightness
keys, the power menu on `Super + x` — live in `sxhkdrc`, and **sxhkd is not
autostarted**. If those keys do nothing, start sxhkd once:

```bash
sxhkd &
```

or add the same line to `~/.config/suckless/scripts/autostart.sh` so it's
always running. The dwm bindings in `Super + /` work regardless.

## Everyday tasks

**Change the wallpaper.** Run `wallpaper-theme` (or `Super + Shift + p` once
sxhkd is up). It lists the bundled Darkmatter set in dmenu; pick one and it
re-applies the static palette to dwm, st, rofi, dunst and kitty, then
recolors dwm in place — no restart. Drop your own images into
`~/.config/suckless/wallpaper/` and they join the list.

**Volume.** Hardware keys if you have them, or `Super + F11` / `F12` /
`F10` — both paths go through the `changevolume` script, which pops a dunst
progress bar. Without sxhkd, `pavucontrol` from dmenu works fine.

**Brightness.** `XF86MonBrightnessUp/Down` (sxhkd) runs `xbacklight ±10`.
`brightnessctl` is installed too, for finer control.

**Add the app phases.** The base install is deliberately lean. When you want
the rest:

```bash
cd dwm-setup
./run.sh --list                 # see what exists
./run.sh --phase core,apps      # pick by phase
./run.sh --full                 # everything, unattended
```

Reboot when it finishes — the first step adds you to the input/video/render/
plugdev groups, and that only matters on the next login.

**Change a dwm keybind.** They're compiled in, not read at runtime:

```bash
cd ~/.config/suckless/dwm
nano config.def.h               # edit the key line + its comment
make && doas make install
```

`make` regenerates `keybindings.txt` from the comments automatically, so the
`Super + /` help updates itself. Then `Super + Shift + r` restarts dwm with
your windows and tags intact.

## Where things live

- Config root: `~/.config/suckless/` — dwm, slstatus, st, rofi, dunst,
  picom, kitty, wallpaper, scripts
- dwm keybinds: `~/.config/suckless/dwm/config.def.h`
- App/media keys (optional): `~/.config/suckless/sxhkd/sxhkdrc`
- Setup steps: `steps/` in the repo, run via `./run.sh`
- Install and run logs: `~/.local/state/dwm-setup/`