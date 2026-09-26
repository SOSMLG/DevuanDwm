# dwm-setup — project conventions

This is the working copy of the dwm daily-driver kit for Devuan 6
(excalibur) / Debian 13 (trixie). It was forked from the justaguy.dev
dwm-setup lineage, but the runtime has changed: the quickshell bar is
gone (native dwm bar + slstatus), the rice is **static Darkmatter**
(near-black `#121113`, red accent `#e75353`, JetBrainsMono Nerd Font),
and there is no wallpaper-driven theme engine — `wallpaper-theme`
applies the same six colors to Xresources/rofi/dunst/kitty from the
bundled wallpapers in `suckless/wallpaper/`.

When working on this repo:

- **Init & privileges.** Devuan runs OpenRC on sysvinit — there is no
  `systemctl`. Enable/start services with `start_service` (OpenRC-aware)
  from `lib/common.sh`. Escalate through the `priv()` helper (doas first,
  sudo fallback, `DEBSWAY_PRIV` to force one). Never write bare `sudo`.
- **No remote install scripts.** Steps run from files in the repo; no
  `curl | bash`, no fetching scripts at install time. Dowloads are
  tarballs/packages with `verify_download` size checks.
- **APT discipline.** Devuan/Debian only. No `apt upgrade` anywhere —
  steps install specific packages. Check names against `apt-cache` and
  use `install_pkgs` (installs only what's missing).
- **The steps runner.** `run.sh` discovers `steps/##-*.sh` (phase from
  the leading digit: 1x core, 3x engineering, 4x apps). Every step has
  `# DEBSWAY_DESC:` / `# DEBSWAY_DEFAULT:` headers (read by `--list`)
  and sources `../lib/common.sh`. New step scripts must pass
  `bash -n` + shellcheck and be safe to re-run (no blind force-purges;
  back up before destructive writes).
- **Configs.** `suckless/*` is canonical and mirrors `~/.config/suckless`
  on the live box. dwm/st/slstatus/dmenu/tabbed build from their
  directories under `$HOME/.config/suckless` after config-copy; the
  Darkmatter palette in `config.def.h` is the source of truth for hexes.
  Keep `keybindings.txt` in sync (the dwm Makefile regenerates it via
  `scripts/gen-keybinds`).
- **Verification.** `./verify.sh` is a read-only audit (groups, installed
  binaries, Darkmatter hexes, services). Run it after touching configs
  or steps; `run.sh --verify` wraps it.
- **No AI tells.** This is a published fork — keep comments concrete and
  varied (say *what* and *why*, never a documentarian's monotone), no
  filler sections, no grand summaries. Match the terse style of the
  existing scripts.