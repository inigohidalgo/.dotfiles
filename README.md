# `.dotfiles/`

General personal system config files

## Setup

```
git clone <clone_url> <path>
```

### Install

```bash
./install.sh install fish home    # ~/.config/fish/config.fish
./install.sh install bash work    # ~/.bashrc
./install.sh install git home     # ~/.gitconfig
./install.sh install tmux local   # ~/.config/tmux/tmux.conf
```

Profiles: `home` (mac) or `work` (wsl) for fish/git; same for bash, plus `beacon-ide` and `dslab`, both opt-in only by name — see below; `local` (outer), `remote` (inner, nested over SSH), or `beacon-ide` (Axpo's browser-based IDE, code-server in a container) for tmux — see `tmux/README.md`. Each profile sources a different set of modules.

`bash`'s `work` is currently **inert** — identical module list to `home` (just `functions`). Unlike fish, where `work` already pulls in real additions (`argo`, `az`, `claude-profiles`), bash has no work-only modules yet; `work` exists as the parallel placeholder for whenever it does. `beacon-ide` adds one module to `home`'s list, `fish` — the bash→fish handoff described below, which is opt-in by profile precisely so it can't reach a machine where `$SHELL` is already fish. `dslab` is a separate, unrelated profile (a JupyterHub/DSLab container, `jovyan` user, PVC-backed home) — it pulls in `dslab_startup`/`code_tunnel` (function definitions, safe to source) but deliberately never `install_packages` (a standalone `sudo`-run provisioner, not something to source into a shell — see the comment on `BASH_DSLAB` in `install.sh`). Since it targets a machine topology this repo otherwise doesn't touch, it only ever activates if you explicitly `install bash dslab`.

For `git`, both identities (`git/identity-personal`, `git/identity-work`) are wired up regardless of profile — the profile only controls which one is the default and which `gitdir:` paths trigger the override:

- `home` → default personal; override to work under `~/dev/repos/axpo/`.
- `work` → default work; override to personal under `~/dev/repos/ihr/` and `~/plan/`.

### Where the rc files actually land

The paths above (`~/.config/fish/config.fish`, `~/.bashrc`, `~/.config/tmux/tmux.conf`) are the *defaults* — what you get on a normal machine where `$HOME` is the durable place things live. `install.sh` resolves the real target per shell:

- **fish** and **git**: both tools natively read `$XDG_CONFIG_HOME` (fish: `$XDG_CONFIG_HOME/fish/config.fish`; git: `$XDG_CONFIG_HOME/git/config`, merged with `~/.gitconfig` rather than replacing it). `install.sh` just follows that — if `$XDG_CONFIG_HOME` is unset, you get today's `~/.config/...`/`~/.gitconfig` behavior, unchanged.
- **bash**: no XDG equivalent, so there's an override var, `DOTFILES_BASH_RC`. Unset → `~/.bashrc`, same as always. Where it's needed, point it at a file your *ephemeral* `~/.bashrc` already unconditionally sources on its own — not any durable file, specifically one already wired into the sourcing chain, so the install stays in effect without any of this repo's machinery re-running on that machine.
- **tmux**: no override — tmux's own config search hardcodes `~/.config/tmux/tmux.conf` regardless of `$XDG_CONFIG_HOME` (verified with `tmux -vv`), so there's nowhere else to point it.

This matters on a machine where `$HOME` itself isn't durable (wiped/regenerated on some external trigger, e.g. a container recreate) but something else is — set `$XDG_CONFIG_HOME` and/or `DOTFILES_BASH_RC` to that durable location *before* running install, and fish/git/bash land there instead. tmux has no such escape hatch — on that kind of machine, re-run `install.sh install tmux <profile>` after every reset instead (it's idempotent-safe to script: it refuses to touch an rc file that already has the block).

### Landing in fish from bash

`sh/fish.sh` `exec`s fish at the end of an interactive bash's rc. It ships with
the `beacon-ide` bash profile only, and it's last in that list — it has to be:
`exec` never returns, so anything after it in the rc — including another
installer's marker block — never runs. For the same reason the dotfiles block
wants to be last in the rc file.

Why here rather than pointing tmux's `default-shell`, or the terminal emulator,
straight at fish: on a machine where `$HOME` is wiped and regenerated, bash's rc
chain is doing real work on the way past — it re-reads the machine's own rc,
which is what redirects the `$HOME`-relative defaults onto durable storage.
Skipping it doesn't fail loudly. A tmux server's environment is a snapshot
frozen at server start and never refreshed, so a fish launched directly by tmux
inherits a stale *subset*, comes up looking healthy, and quietly reads some
state from the wrong place. Going through bash re-establishes the table on every
single pane.

Why it's opt-in by profile rather than installed everywhere and left to its own
guards: the escape hatch only works downstream of a handoff. Typing `bash` gets
you bash because `sh/fish.sh` exports `DOTFILES_FISH_SHELL` before the `exec`,
and the child inherits it. On a machine where `$SHELL` is *already* fish, no
handoff ever ran, so that marker doesn't exist — a typed `bash` would read its
rc, find nothing set, and `exec` straight back into fish, leaving
`DOTFILES_NO_FISH=1` as the only way to a bash prompt. Both Macs are that
machine, so they don't install the module. Not installing it is the guard.

Inert, additionally, where fish isn't on `PATH`, and for anything
non-interactive — scripts, `bash -c`, `ssh host cmd` all stay bash.

### Uninstall

```bash
./install.sh uninstall fish
./install.sh uninstall bash
./install.sh uninstall git
./install.sh uninstall tmux
```

## How it works

Install is **not** symlink-based. `install.sh` appends a marker block (`# <<<
dotfiles >>>`) of `source` / `source-file` / `include` lines to the target rc
file (`~/.config/fish/config.fish`, `~/.bashrc`, `~/.gitconfig`, or
`~/.config/tmux/tmux.conf`); uninstall removes exactly that block.

The block points at the live files in this repo, which the shell reads on every
startup. So:

- **Editing an existing module** → no reinstall; the next shell (or `prefix R`
  for tmux) picks it up.
- **Adding / removing / renaming a module** → first update the profile's module
  list at the top of `install.sh` (`FISH_*`, `BASH_*`, `TMUX_*` — these decide
  which modules each profile sources), then `uninstall` + `install` to
  regenerate the block.

A module needing more than shell code keeps its assets in a sibling dir named
after it — `fish/mdview/` holds the pandoc defaults, CSS, and AppleScript that
`fish/mdview.fish` drives, resolved through `$DOTFILE_DIR`, so nothing depends
on a path outside the repo. (`mdview` needs `pandoc`, `typst`, and `glow`.)

`fish/.fish` and `sh/.sh` are standalone entrypoints for `source`-ing a whole
dir by hand — convenient, but **not used by `install.sh`**, which builds its own
source list from the profile variables. Editing them does nothing to an
installed setup.
