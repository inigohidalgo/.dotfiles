# `.dotfiles/`

General personal system config files

## Setup

```
git clone <clone_url> <path>
```

### Install

```bash
./install.sh install fish home   # ~/.config/fish/config.fish
./install.sh install bash work   # ~/.bashrc
./install.sh install git home    # ~/.gitconfig
```

Profiles: `home` (mac) or `work` (wsl). Each profile sources a different set of modules.

For `git`, both identities (`git/identity-personal`, `git/identity-work`) are wired up regardless of profile — the profile only controls which one is the default and which `gitdir:` paths trigger the override:

- `home` → default personal; override to work under `~/dev/repos/axpo/`.
- `work` → default work; override to personal under `~/dev/repos/ihr/` and `~/plan/`.

### Uninstall

```bash
./install.sh uninstall fish
./install.sh uninstall bash
./install.sh uninstall git
```

The script appends a marked block (`# <<< dotfiles >>>`) to the rc file (or `~/.gitconfig`). Uninstall removes exactly that block.
