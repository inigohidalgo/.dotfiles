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
# stale *subset* rather than nothing at all. Measured 2026-08-26: a fresh pane
# had XDG_CONFIG_HOME (so fish found its config and looked perfectly healthy)
# but not CLAUDER_USER_HOME (so a downstream tool read state from the wrong
# directory). Running bash first repairs that on every single pane, because it
# re-reads the live rc rather than trusting anything cached.
#
# `exec`, not a plain call: bash is replaced rather than left waiting, so the
# pane exits with fish and #{pane_current_command} reads `fish`.
#
# **This module must be sourced last.** `exec` never returns, so anything after
# it in the rc -- including another installer's marker block -- never runs. Keep
# it last in any BASH_* list that has it in install.sh, and keep the dotfiles
# block last in the rc.
#
# **Opt-in per profile, and deliberately not in home/work.** It ships only with
# BASH_BEACON_IDE, because the `bash` escape hatch below holds only where the
# fish you are sitting in was itself reached through this handoff. On a machine
# whose $SHELL is already fish (both Macs), nothing ever exports the marker, so
# a typed `bash` would read its rc, find no marker, and exec straight back into
# fish -- leaving DOTFILES_NO_FISH=1 as the only way to get a bash prompt. The
# profile list is what keeps that from happening, not a runtime check.
#
# Getting a bash shell when you want one:
#   bash                            # DOTFILES_FISH_SHELL is exported before the
#                                   # exec, so the child inherits it and skips
#                                   # the handoff
#   DOTFILES_NO_FISH=1 <launcher>   # opt out entirely
#   tmux new-window 'DOTFILES_NO_FISH=1 bash'
#
# A bare `tmux new-window /bin/bash` is NOT one of them: host-beacon-ide.conf
# scrubs the marker from the server's environment (deliberately -- see the
# comment there), so that pane's bash finds nothing set and hands off like any
# other. Verified by probe.
#
# BASH_EXECUTION_STRING keeps `bash -ic "..."` in bash, so scripts and tooling
# are unaffected; the `command -v fish` check makes this inert, not fatal, on a
# machine without fish.
if [[ $- == *i* ]] &&
   [[ -z "${BASH_EXECUTION_STRING:-}" ]] &&
   [[ -z "${DOTFILES_NO_FISH:-}" ]] &&
   [[ -z "${DOTFILES_FISH_SHELL:-}" ]] &&
   command -v fish >/dev/null 2>&1; then
    export DOTFILES_FISH_SHELL=1
    exec fish
fi
