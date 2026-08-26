# `reference/`

Reference copies. **Nothing here is installed, sourced, or read by
`install.sh`** — these are snapshots kept for recovery and for reading, and
they go stale the moment the original changes.

## `workspace.bashrc`

A byte-identical copy of `$DEFAULT_WORKSPACE/.bashrc` on the Beacon container
(taken 2026-08-26), the untracked machine-local file that bootstraps that
machine. The platform's ephemeral `~/.bashrc` sources it unconditionally, at a
point *after* its own non-interactive early-return — so only interactive bash
ever reaches it.

It's here because it's the one file the container's whole setup hangs off and
the only one with no copy anywhere else: `$HOME` is wiped on every recreate, and
while this file itself lives on NFS, nothing versions it.

What it holds, and why it isn't in the repo proper:

- The redirect table — `XDG_CONFIG_HOME`, `CLAUDE_CONFIG_DIR`,
  `CLAUDER_USER_HOME`, `DOTFILES_BASH_RC`, `NPM_CONFIG_PREFIX`, `GOPATH`,
  `GOBIN`, `CARGO_HOME`, and the `PATH` additions — all derived from
  `$BEACON_USER_DIR`, which only that platform sets.
- A one-shot call to `inigo/setup/bootstrap.sh`, guarded on an atomic
  `mkdir "$HOME/.bootstrapped"`, which re-does what a recreate wipes.
- The `# <<< dotfiles >>>` and `# <<< clauder >>>` marker blocks, written by
  their respective installers.

These are machine facts, and machine facts are exactly what this repo does not
carry — it reads variables, guarded, so every branch is inert elsewhere. Keeping
the file here as an inert snapshot rather than a live module is what keeps that
true. See `notes/platform/260825-container-config-ownership.md` (not in this
repo) for the ownership rule in full.

**Restoring it is not enough on its own.** The blocks inside reference absolute
paths that are correct only for that machine, and the bootstrap call names a
path under a personal workspace tree. On a rebuilt container, prefer re-running
`install.sh` over pasting this back.
