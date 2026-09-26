# Contributing

Pull requests are welcome. The fork lives on GitHub at
[SOSMLG/dwm-setup](https://github.com/SOSMLG/dwm-setup) — fork it, branch
off `main`, and open a PR. There's no CI gate yet, so the review is
whatever the maintainer is in the mood for, but the checklist below is what
gets a change merged without back-and-forth.

## The rules of the road

These aren't cosmetic. The repo is Devuan-first and that shows up in every
script, so keep it that way:

- **Never write bare `sudo`.** Escalation goes through `priv()` from
  `lib/common.sh` (doas first, sudo fallback, `DEBSWAY_PRIV` override).
  If you need it inside a step, source `lib/common.sh` and use `priv`.
- **Never assume systemd.** Services go through `start_service()`, which
  handles OpenRC on Devuan and falls back to sysvinit. No `systemctl` in
  new code, no systemd timers.
- **No root, ever.** Steps refuse to run as root and escalate the small
  parts that need elevation. Per-user state must land in the real user's
  `$HOME`, which is why `run.sh` and every step check `id -u` up front.
- **Nothing remote is piped into bash.** Install step content runs from
  files on disk. When a tool needs an installer, install the artifact
  through a real package path (apt, Flatpak, npm, a `.deb`) or print the
  command for the user to run themselves.

## Adding or changing a step

Steps live in `steps/##-*.sh`. The leading digit decides the phase —
`1` core, `3` engineering, `4` apps — and `run.sh` sorts by filename, so
number accordingly.

- Every step carries two headers near the top, no exceptions:
  `# DEBSWAY_DESC:` (one line) and `# DEBSWAY_DEFAULT:` (`Y` or `N`).
  `./run.sh --list` reads them, and the README's phase table is generated
  from the same source.
- Source `lib/common.sh` and use its helpers: `ask()`, `install_pkgs()`
  (which skips what's already installed and checks the apt cache before
  touching anything), `apt_update()`, `start_service()`, `require_not_root()`,
  `die()`.
- Be idempotent. Every script is safe to re-run: check before installing,
  skip what's present, and never force-purge. Backup (`*.bak.<timestamp>`)
  before any destructive config write.
- Keep the script honest about its failures. `install_pkgs` records a
  warning when something is skipped; if a step genuinely can't proceed,
  exit non-zero and say why.

## Changing the suckless tree

- Edit `config.def.h`, never a generated `config.h` or
  `keybindings.txt`. The dwm Makefile copies the header and regenerates
  `keybindings.txt` from the annotated `keys[]` table via
  `scripts/gen-keybinds`, so help text goes in the trailing comments next
  to each binding.
- New dwm patches go in `suckless/dwm/patches/` and get a row in
  `suckless/dwm/modifications.txt` where applicable.
- If you touch the Darkmatter palette, you touched everything: the hexes
  clear across `dwm/config.def.h`, `slstatus/config.h`, `st/config.def.h`,
  `rofi/colors.rasi`, `dunst/dunstrc` (`# THEME:` markers), kitty's
  `current-theme.conf` and `wallpaper-theme` itself. `verify.sh` spot-checks
  `#121113` / `#e75353` in dunst and rofi, and it will tell you.

## Before you push

1. `bash -n` anything you touched, and run `shellcheck` on it if you have
   it. `scripts/gen-keybinds` and the awk inside `scripts/help` are the
   usual places a "small fix" turns into a parse error.
2. `./run.sh --list` — if you changed a step's headers, confirm they render
   with the right phase/description/default.
3. If your change affects the end state, run `./run.sh --verify` (or
   `bash verify.sh`) — a read-only audit that must exit with zero FAILs.
4. Update the CHANGELOG fork section for user-visible changes. Keep the
   historical upstream entries below it untouched.

## Docs

The README, QUICKSTART and this file are read by people who just installed
the thing. Keep them in a human voice and make sure they match the code —
if a binding or a script changed, the keybinding table and the
configuration tree changed with it. There's no wiki; if it isn't in the
repo, it doesn't exist.