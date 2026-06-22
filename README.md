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

Profiles: `home` (mac) or `work` (wsl) for fish/bash/git; `local` (outer) or `remote` (inner, nested over SSH) for tmux — see `tmux/README.md`. Each profile sources a different set of modules.

For `git`, both identities (`git/identity-personal`, `git/identity-work`) are wired up regardless of profile — the profile only controls which one is the default and which `gitdir:` paths trigger the override:

- `home` → default personal; override to work under `~/dev/repos/axpo/`.
- `work` → default work; override to personal under `~/dev/repos/ihr/` and `~/plan/`.

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

`fish/.fish` and `sh/.sh` are standalone entrypoints for `source`-ing a whole
dir by hand — convenient, but **not used by `install.sh`**, which builds its own
source list from the profile variables. Editing them does nothing to an
installed setup.
