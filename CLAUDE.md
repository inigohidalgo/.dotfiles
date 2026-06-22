# CLAUDE.md

Personal dotfiles — fish/bash shell, git, and tmux config, wired into rc files
by `install.sh`.

@README.md — install, profiles, and how the install mechanism works (marker
block, live files, edit-vs-reinstall).
@tmux/README.md — the nested local/remote tmux design and its sharp edges.

## Verifying changes

Pure config: no build, test, or lint to run. To check a change, re-source the
rc (e.g. `source ~/.config/fish/config.fish`) or reload tmux (`prefix R`). To
see what a profile *would* generate without touching real rc files, read the
`gen_block` function and the profile variables in `install.sh`.
