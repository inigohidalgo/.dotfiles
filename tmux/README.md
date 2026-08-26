# tmux

One config, three contexts. The local machine runs the *outer* tmux; the
remote (`inigo-mbp20`) runs an *inner* tmux reached over SSH inside an outer
pane — always nested, never a bare shell. A third context, `container`, is a
single non-nested tmux inside a browser-based IDE terminal (e.g. code-server
in a Docker container) — no outer layer, but its own set of transport quirks
(see "Sharp edges" below).

## Layout

| File | Role |
|---|---|
| `options.conf` | shared — server PATH fix, indexing, general options, terminal features |
| `keys.conf` | shared — session/window/pane bindings, `prefix R` reload |
| `workflows.conf` | shared — clauder/lazygit popups, fzf window switcher (`bind C`/`bind g` are local-tooling-dependent and just error if pressed where the tool is missing) |
| `theme.conf` | shared — Catppuccin Mocha base; accent + bar shape excluded |
| `host-local.conf` | prefix `C-a`, titles, blue accent, full status bar |
| `host-remote.conf` | prefix `M-a`, peach accent, lean ` ssh ` bar |
| `host-container.conf` | prefix `C-a`, mouse off (see sharp edges), green accent, ` web: ` bar |

The host file is sourced **last**, so machine divergence is a ~15-line
override, never a forked copy. Install generates the entry point
(`~/.config/tmux/tmux.conf`) as a marker block of `source-file` lines:

```bash
./install.sh install tmux local       # this machine, outer
./install.sh install tmux remote      # inigo-mbp20, inner
./install.sh install tmux container   # browser-based IDE container
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

## Pane shell

Panes run fish, reached *through* bash rather than instead of it: `host-container.conf`
pins `default-shell` to `/bin/bash`, and `.dotfiles/sh/fish.sh` `exec`s fish at
the end of bash's rc. The repo README has the reasoning; the short version is
that on the container bash's rc is what redirects `$HOME`-relative defaults onto
durable storage, and a tmux server's environment is a frozen snapshot, so a pane
that skipped bash would inherit a stale subset and fail quietly.

Pinned in the host file rather than `options.conf` because it isn't true
everywhere — on the Mac `$SHELL` is already fish, panes are fish directly, and
the handoff never runs.

**Known broken here:** `bind b` and `bind M-b` in `workflows.conf` are written
in fish and run under `default-shell`, which on this machine is now explicitly
bash — so they fail at press time with a syntax error, silently, since a popup's
exit status isn't surfaced. They work on the Mac. The fix is to extract each
body into its own `#!/usr/bin/env fish` script and have the binding invoke that;
wrapping them in `fish -c '...'` inline doesn't survive the escaping, since the
bodies contain nested single quotes for `awk`.

## Sync workflow

Edit here → commit → push. On the other machine: `git pull` in the repo,
then `prefix R` (or `tmux kill-server && tmux` for a clean start — required
for changes to the server PATH fix). No rsync, no parallel copies; drift
shows up as a dirty worktree instead of silently diverging.

## Reload vs reinstall

Install is **not** symlink-based. It writes `~/.config/tmux/tmux.conf` as a
marker block of `source-file` lines pointing at the absolute paths of the
module files in this repo. tmux reads the live repo files on every load, so:

- **Editing a setting in an existing module** (`options.conf`, `keys.conf`,
  …) → just reload with `prefix R`. The `source-file` line already points at
  that file. This is the common case.
- **Adding / removing / renaming a module file** → reinstall. The entry point
  only sources the modules listed in `TMUX_LOCAL` / `TMUX_REMOTE` /
  `TMUX_CONTAINER` in `install.sh`, baked in at install time. Update that
  list, then regenerate the entry point. Install refuses to overwrite an
  existing block, so:

  ```bash
  ./install.sh uninstall tmux && ./install.sh install tmux local
  ```

## Prereqs

- **tmux ≥ 3.4** — `workflows.conf` uses `run-shell -E` (3.4+). On an older
  tmux this specific bind (`bind C`, clauder) fails to *register* at config-load
  time (`tmux: unknown option -- E` / `usage: run-shell [-bC]...`); the rest
  of the config still loads and applies fine, `prefix C` just falls back to
  tmux's own default (`customize-mode -Z`) instead of launching clauder.
  Confirmed on a 3.2a container build — not a hard crash like the flag name
  might suggest, just that one binding silently not existing.
- **`allow-passthrough` needs tmux ≥ 3.3** — `options.conf` sets it
  unconditionally, so the same older tmux also logs `invalid option:
  allow-passthrough` at config-load time. Same shape of failure as `bind C`
  above: that one `set` is skipped, everything after it still loads. So on the
  3.2a container expect *two* errors on load, both benign and both explained
  by this section rather than by anything wrong with the install.
- Remote is Intel (`/usr/local/bin/tmux`), local is ARM (`/opt/homebrew`).
  The PATH fix in `options.conf` handles both — keep it prefix-agnostic. It's
  a harmless no-op on `container` (plain Linux PATH, no Homebrew).

## Known sharp edges

- **Shift+Enter doesn't insert a newline in remote Claude Code**: outer tmux
  uses `extended-keys on` (not `always`), so CSI u sequences only reach apps
  that opt in via DECSET 2017 — SSH doesn't. `always` would fix it but risks
  stray CSI u garbage in legacy apps. Trade accepted; paste or a literal
  `\n` works. On `container`, the same symptom can occur for an unrelated
  reason (whether the browser-hosted terminal emits CSI u for Shift+Enter at
  all) — don't assume the SSH-specific root cause carries over uninvestigated.
- `bind C` (clauder) and `bind g` (lazygit) error visibly on a machine
  without the tool. Harmless; move to `host-local.conf` if it gets noisy.
- **Copy-to-system-clipboard doesn't reliably work on `container`, and
  there's no full fix — accepted, not resolved**: OSC 52 (tmux's
  `set-clipboard on`, and apps like Claude Code that emit OSC 52 directly)
  gets silently dropped somewhere between the container and the real OS
  clipboard — confirmed independent of tmux (a bare, non-tmux shell in the
  same browser-hosted terminal has the identical failure for OSC-52-driven
  copies, while genuine browser-native drag-select + Cmd+C works fine
  everywhere, tmux or not). Matches widely-reported upstream limitations in
  browser-hosted VS Code terminals (code-server/Codespaces). Things tried and
  ruled out:
  - `mouse off` (forces every drag through the browser's working native copy
    path instead of tmux's copy-mode) fixes copying from a plain pane, but
    loses pane resize/click-select/scroll-through-history for no benefit
    against the real target — reverted.
  - `CLAUDE_CODE_DISABLE_MOUSE=1` (stops Claude Code's TUI from capturing
    the mouse at all) — same trade, same revert, and Claude's own OSC-52
    copy still wouldn't reach the clipboard even with it on.
  - Shift+drag to bypass an app's mouse-tracking (the documented Claude Code
    / VS Code convention) doesn't work in this browser terminal — it still
    forwards the mouse-tracking report to the app regardless of Shift, so
    the app never sees a bypass signal.
  - A `copy-command` bridge (piping tmux copy-mode's selection to `xclip`/
    `xsel`/`wl-copy`) isn't available either — none of those binaries exist
    in this container and there's no `$DISPLAY`/`$WAYLAND_DISPLAY`.
  - Net: pane-aware selection (tmux mouse+copy-mode) and reaching the real
    OS clipboard are mutually exclusive here — the former's only egress is
    the broken OSC 52 relay, and the latter requires bypassing tmux's
    mediation entirely (losing pane-awareness by construction).
  - **Working fallback**: `prefix z` to zoom the pane before a native
    drag-select + Cmd+C, so no neighboring pane shares a row. Toggle `prefix
    z` again after. Mouse mode is otherwise left on (default from
    `options.conf`).
