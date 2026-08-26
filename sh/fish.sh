# Hand an interactive bash off to fish.
#
# This, rather than tmux's `default-shell` / `default-command`, or the IDE's
# terminal profile. All of those launch fish *instead of* bash, and on a machine
# whose $HOME is wiped and regenerated (a container recreate, a fresh
# devcontainer) bash's rc chain is doing real work on the way past: it re-reads
# the machine's own rc, which is what redirects the $HOME-relative defaults --
# PATH, XDG_CONFIG_HOME, and friends -- onto durable storage.
#
# Skipping it does not fail loudly, which is the point. A tmux *server*'s
# environment is a snapshot frozen when the server started and never refreshed,
# and panes inherit the snapshot, so a fish launched directly by tmux gets a
# stale *subset* rather than nothing at all. Measured 2026-08-26 on a server
# that predated a change to the machine rc: a fresh pane had XDG_CONFIG_HOME
# (so fish found its config and looked perfectly healthy) but not
# CLAUDER_USER_HOME (so a downstream tool read state from the wrong directory).
# Running bash first repairs that on every single pane, because it re-reads the
# live rc rather than trusting anything cached.
#
# `exec`, not a plain call: bash is replaced rather than left waiting, so the
# pane exits with fish and #{pane_current_command} reads `fish`.
#
# **This module must be sourced last.** `exec` never returns, so anything after
# it in the rc -- including another installer's marker block -- never runs. Keep
# it last in every BASH_* list in install.sh, and keep the dotfiles block last
# in the rc.
#
# Getting a bash shell when you want one:
#   bash                            # nested; DOTFILES_FISH_SHELL is exported,
#                                   # so the child skips the handoff
#   DOTFILES_NO_FISH=1 <launcher>   # opt out entirely
#   tmux new-window /bin/bash
#
# Guards, in order: interactive only; not `bash -c "..."`, which must stay bash
# so scripts and tooling are unaffected; not opted out; not already downstream
# of a handoff; and fish actually installed -- so this is inert, not fatal, on a
# machine without it.
if [[ $- == *i* ]] &&
   [[ -z "${BASH_EXECUTION_STRING:-}" ]] &&
   [[ -z "${DOTFILES_NO_FISH:-}" ]] &&
   [[ -z "${DOTFILES_FISH_SHELL:-}" ]] &&
   command -v fish >/dev/null 2>&1; then
    export DOTFILES_FISH_SHELL=1
    exec fish
fi
