# Troubleshooting

## Mouse lag / stutter (NVIDIA)

If the cursor skips or feels laggy — most commonly on the **NVIDIA proprietary
driver** — it's almost always picom's compositing backend.

The setup ships with:

```
backend = "xrender";
```

`xrender` is the safe default: it works on essentially everything, including
VMs and machines with no GPU acceleration. The trade-off is that on NVIDIA's
proprietary driver, `xrender` compositing stutters and its vsync is unreliable.

**Fix:** edit `~/.config/suckless/picom/picom.conf`, change the backend to
`glx`, and reload picom.

```
backend = "glx";
```

```sh
pkill picom && picom --config ~/.config/suckless/picom/picom.conf -b &
```

Don't blindly switch everyone to `glx`: on some older Intel GPUs, in VMs, or
under software (llvmpipe) rendering, `glx` can perform *worse* or fail to start
entirely, leaving you with no compositor. `glx` is the right choice **only** on
hardware that accelerates it well — which on the affected setups means NVIDIA.

---

## `~/.local/bin` programs not found under a display manager

If you install your own tools into `~/.local/bin` (for example, building dmenu
yourself instead of using rofi) and they can't be launched from dwm — yet they
run fine from a terminal — the cause is your login method, not the program.

### Why it happens

`~/.local/bin` is added to your `PATH` by the snippet in `~/.profile`. That file
is read only by a **login shell**.

- **TTY + `startx`:** logging into a virtual terminal *is* a login shell, so
  `~/.profile` runs and `~/.local/bin` is on `PATH` before X even starts.
  Everything works — you'll never see this problem.
- **Display manager (LightDM, etc.):** the graphical login never opens a login
  shell. LightDM runs the session through `/etc/X11/Xsession`, which sources
  `~/.xsessionrc` but **not** `~/.profile`. So `~/.local/bin` is missing from
  `PATH`, and anything dwm launches (including via keybindings) can't find it.

The tools this setup installs itself are unaffected — they go to
`/usr/local/bin` (always on `PATH`). Only programs *you* put in `~/.local/bin`
hit this.

> Note: exporting `PATH` inside `autostart.sh` does **not** fix it. That script
> is a child of dwm, so its `PATH` only reaches *its own* children — a program
> launched later from a dwm/sxhkd keybinding still inherits dwm's original
> environment. The fix has to set `PATH` *before* dwm starts.

### Fix

Create `~/.xsessionrc` (the Debian-standard hook that `/etc/X11/Xsession`
*does* source) and prepend `~/.local/bin` if it's missing:

```sh
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
esac
```

Log out and back in. This is idempotent and pulls in only the one `PATH`
entry — unlike sourcing all of `~/.profile`, which is run under `/bin/sh` and
can choke on bash-only syntax.
