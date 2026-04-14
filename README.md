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
```

Profiles: `home` (mac) or `work` (wsl). Each profile sources a different set of modules.

### Uninstall

```bash
./install.sh uninstall fish
./install.sh uninstall bash
```

The script appends a marked block (`# <<< dotfiles >>>`) to the shell rc file that sources selected modules. Uninstall removes exactly that block.
