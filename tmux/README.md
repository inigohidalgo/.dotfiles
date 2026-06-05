# tmux

One config, two machines. The local machine runs the *outer* tmux; the remote
(`inigo-mbp20`) runs an *inner* tmux reached over SSH inside an outer pane —
always nested, never a bare shell.

## Layout

| File | Role |
|---|---|
| `options.conf` | shared — server PATH fix, indexing, general options, terminal features |
| `keys.conf` | shared — session/window/pane bindings, `prefix R` reload |
| `workflows.conf` | shared — clauder/lazygit popups, fzf window switcher (`bind C`/`bind g` are local-tooling-dependent and just error if pressed where the tool is missing) |
| `theme.conf` | shared — Catppuccin Mocha base; accent + bar shape excluded |
| `host-local.conf` | prefix `C-a`, titles, blue accent, full status bar |
| `host-remote.conf` | prefix `M-a`, peach accent, lean ` ssh ` bar |

The host file is sourced **last**, so machine divergence is a ~15-line
override, never a forked copy. Install generates the entry point
(`~/.config/tmux/tmux.conf`) as a marker block of `source-file` lines:

```bash
./install.sh install tmux local    # this machine, outer
./install.sh install tmux remote   # inigo-mbp20, inner
```

## Why two host files

1. **Prefix collision** in tmux-in-tmux: both layers can't bind the same
   prefix. Inner uses `M-a` — same letter as outer's `C-a` (muscle memory),
   and Opt+A arrives as `ESC a`, which survives SSH and the outer tmux
   without extended-keys gymnastics.
2. **Visual ambiguity** with two status bars on screen: same palette/shape,
   but inner swaps blue → peach on active-window + active-pane-border and
   shows a static ` ssh ` label. Warm vs cool = inner vs outer at a glance.

Inner also drops `set-titles` (outer owns the terminal title) and the
pane-border title row (outer already labels the SSH pane — it would stack).

## Sync workflow

Edit here → commit → push. On the other machine: `git pull` in the repo,
then `prefix R` (or `tmux kill-server && tmux` for a clean start — required
for changes to the server PATH fix). No rsync, no parallel copies; drift
shows up as a dirty worktree instead of silently diverging.

## Prereqs

- **tmux ≥ 3.4** — `workflows.conf` uses `run-shell -E` (3.4+). Older tmux
  fails to parse and the server exits on launch
  (`command run-shell: unknown flag -E`).
- Remote is Intel (`/usr/local/bin/tmux`), local is ARM (`/opt/homebrew`).
  The PATH fix in `options.conf` handles both — keep it prefix-agnostic.

## Known sharp edges

- **Shift+Enter doesn't insert a newline in remote Claude Code**: outer tmux
  uses `extended-keys on` (not `always`), so CSI u sequences only reach apps
  that opt in via DECSET 2017 — SSH doesn't. `always` would fix it but risks
  stray CSI u garbage in legacy apps. Trade accepted; paste or a literal
  `\n` works.
- `bind C` (clauder) and `bind g` (lazygit) error visibly on a machine
  without the tool. Harmless; move to `host-local.conf` if it gets noisy.
