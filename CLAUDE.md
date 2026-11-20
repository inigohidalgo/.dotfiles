# CLAUDE.md

Personal dotfiles — fish/bash shell, git, and tmux config, wired into rc files
by `install.sh`; plus Karabiner-Elements, symlinked as a whole directory; plus
`rssh`, persistent remote shells per Rex pane, linked into `~/.local/bin`.

@README.md — install, profiles, and how the install mechanism works (marker
block, live files, edit-vs-reinstall).
@tmux/README.md — the nested local/remote tmux design and its sharp edges.
@karabiner/README.md — the live Karabiner config: editing it, CLI tools, and
why each rule exists.
@fish/README.md — inventory of the live fish customizations that come from
outside this repo (conf.d snippets, installer blocks, vendor completions).
@rssh/README.md — one persistent remote shell per Rex pane (dtach on the host):
the ID and release rule, what survives what, and the dtach deadlock.

## Verifying changes

Pure config: no build, test, or lint to run. To check a change, re-source the
rc (e.g. `source ~/.config/fish/config.fish`) or reload tmux (`prefix R`). To
see what a profile *would* generate without touching real rc files, read the
`gen_block` function and the profile variables in `install.sh`.

For Karabiner, edits to `karabiner/config/karabiner.json` load live; confirm in
`/var/log/karabiner/core_service.log` (see `karabiner/README.md`).
