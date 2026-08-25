#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_BEGIN="# <<< dotfiles >>>"
MARKER_END="# <<< /dotfiles >>>"

# This script is not the only installer that writes marker blocks into these rc
# files. `clauder install` writes its own, namespaced `# <<< clauder >>>`, and
# resolves its target rc through the *same three variables* the *_rc() helpers
# below use: DOTFILES_BASH_RC, XDG_CONFIG_HOME, ZDOTDIR. DOTFILES_BASH_RC keeps
# its name there even though clauder is not this repo, precisely so that a
# machine which has told one installer where its durable bashrc lives has told
# both. Renaming it here silently relocates half of that machine's install.

# --- profiles: module lists per shell and profile ---

FISH_HOME="env fs git mdview nav python ssh utils"
FISH_WORK="$FISH_HOME argo az claude-profiles"

BASH_HOME="functions"
# Inert for now — no WSL-specific bash modules exist yet (unlike FISH_WORK,
# which already diverges from FISH_HOME). Placeholder for when bash grows
# its own work-only additions.
BASH_WORK="$BASH_HOME"
# dslab_startup/code_tunnel are function *definitions* — safe to source, do
# nothing until called. install_packages.sh is deliberately NOT here: per
# its own header it's a backup of a script that lives elsewhere on that
# machine (/home/jovyan/system_setup/install-packages.sh) and is only ever
# meant to be sudo-run standalone (see dslab_startup's own call to it) — it
# does an unconditional root-check-and-exit at the top level, so sourcing it
# anywhere kills the sourcing shell outright. Opt into this profile by name;
# nothing here should ever leak into home/work.
BASH_DSLAB="$BASH_HOME dslab_startup code_tunnel"

# tmux: host file sourced last so machine divergence is an override, not a fork
TMUX_LOCAL="options keys workflows theme host-local"
TMUX_REMOTE="options keys workflows theme host-remote"
TMUX_CONTAINER="options keys workflows theme host-container"

# git: identity defaults flip per profile, "other" identity is wired via includeIf
#
# The ~/ anchor is deliberate where it appears and deliberately absent where it
# does not. Git prepends **/ to a gitdir: pattern that does not start with ~/,
# ./ or /, and appends ** to one ending in /. So "dev/repos/ihr/" becomes
# **/dev/repos/ihr/**, which matches on a machine where the tree hangs off $HOME
# *and* on one where it does not (the beacon container keeps it on NFS, where
# the ~/-anchored form silently never fired and every repo resolved to the work
# identity). ihr is a container of repos, so recursive is what it wants.
#
# "~/plan/" stays anchored: unanchored it would become **/plan/**, matching any
# repo nested under any directory named plan anywhere on the box. If it ever
# needs to be portable, the narrow spelling is "plan/.git" — matching only a
# repo whose own root directory is called plan.
GIT_HOME_DEFAULT="personal"
GIT_HOME_OVERRIDE_GITDIRS="~/dev/repos/axpo/"
GIT_WORK_DEFAULT="work"
GIT_WORK_OVERRIDE_GITDIRS="dev/repos/ihr/ ~/plan/"

usage() {
    echo "Usage: $0 <install|uninstall> <fish|bash|git|tmux> [profile]"
    echo "  profile is required for install, ignored for uninstall"
    echo "  profiles: fish/git → home|work, bash → home|work|dslab, tmux → local|remote|container"
    exit 1
}

fish_rc() {
    # fish itself resolves config.fish via $XDG_CONFIG_HOME/fish (falling back
    # to ~/.config/fish) — mirror that instead of hardcoding ~/.config, so a
    # machine that redirects XDG_CONFIG_HOME to durable storage (e.g. an
    # ephemeral-$HOME container) gets a dotfiles install that survives too.
    # Unset anywhere else → identical to the old hardcoded path.
    local rc="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    mkdir -p "$(dirname "$rc")"
    echo "$rc"
}

bash_rc() {
    # No XDG equivalent for bash. DOTFILES_BASH_RC is a generic escape hatch
    # for a machine whose ~/.bashrc isn't durable/writable-as-final-home (e.g.
    # it's regenerated on every boot but itself sources a durable file) —
    # point the var at that durable file. Unset → today's ~/.bashrc.
    local rc="${DOTFILES_BASH_RC:-$HOME/.bashrc}"
    mkdir -p "$(dirname "$rc")"
    echo "$rc"
}

git_rc() {
    # git reads $XDG_CONFIG_HOME/git/config *and* ~/.gitconfig, merging them
    # (single-valued keys in ~/.gitconfig win on conflict) — so when
    # XDG_CONFIG_HOME is set, install there instead: durable if that's been
    # redirected, and it layers cleanly on top of whatever ~/.gitconfig
    # already holds. Unset → today's ~/.gitconfig, unchanged.
    if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
        local rc="$XDG_CONFIG_HOME/git/config"
        mkdir -p "$(dirname "$rc")"
        echo "$rc"
    else
        echo "$HOME/.gitconfig"
    fi
}

tmux_rc() {
    # No override hook here, unlike the other three: tmux's own config-file
    # search hardcodes ~/.config/tmux/tmux.conf (confirmed via `tmux -vv` —
    # it ignores $XDG_CONFIG_HOME even though tmux passes it through to the
    # server). Nothing written elsewhere would ever actually get read, so on
    # a machine with an ephemeral $HOME, the fix isn't a different target —
    # it's re-running this install after every recreate.
    local rc="$HOME/.config/tmux/tmux.conf"
    mkdir -p "$(dirname "$rc")"
    echo "$rc"
}

get_rc() {
    case "$1" in
        fish) fish_rc ;;
        bash) bash_rc ;;
        git)  git_rc  ;;
        tmux) tmux_rc ;;
    esac
}

valid_profiles() {
    case "$1" in
        tmux) echo "local remote container" ;;
        bash) echo "home work dslab" ;;
        *)    echo "home work" ;;
    esac
}

get_modules() {
    local shell="$1" profile="$2"
    local var
    var="$(echo "${shell}_${profile}" | tr '[:lower:]' '[:upper:]')"
    eval echo "\$$var"
}

gen_block() {
    local shell="$1" profile="$2"
    local modules dir ext src_prefix

    case "$shell" in
        fish)
            modules="$(get_modules "$shell" "$profile")"
            dir="$SCRIPT_DIR/fish"
            ext=".fish"
            echo "$MARKER_BEGIN"
            echo "set -x DOTFILE_DIR \"$dir\""
            for mod in $modules; do
                echo "source \$DOTFILE_DIR/${mod}${ext}"
            done
            echo "$MARKER_END"
            ;;
        bash)
            modules="$(get_modules "$shell" "$profile")"
            dir="$SCRIPT_DIR/sh"
            ext=".sh"
            echo "$MARKER_BEGIN"
            echo "export DOTFILE_DIR=\"$dir\""
            for mod in $modules; do
                echo "source \"\$DOTFILE_DIR/${mod}${ext}\""
            done
            echo "$MARKER_END"
            ;;
        tmux)
            modules="$(get_modules "$shell" "$profile")"
            dir="$SCRIPT_DIR/tmux"
            echo "$MARKER_BEGIN"
            for mod in $modules; do
                echo "source-file \"$dir/${mod}.conf\""
            done
            echo "$MARKER_END"
            ;;
        git)
            dir="$SCRIPT_DIR/git"
            local default_id override_id override_gitdirs
            case "$profile" in
                home)
                    default_id="$GIT_HOME_DEFAULT"
                    override_gitdirs="$GIT_HOME_OVERRIDE_GITDIRS"
                    override_id="work"
                    ;;
                work)
                    default_id="$GIT_WORK_DEFAULT"
                    override_gitdirs="$GIT_WORK_OVERRIDE_GITDIRS"
                    override_id="personal"
                    ;;
            esac
            echo "$MARKER_BEGIN"
            echo "[include]"
            echo "    path = $dir/common"
            echo "    path = $dir/identity-${default_id}"
            for gd in $override_gitdirs; do
                echo "[includeIf \"gitdir:${gd}\"]"
                echo "    path = $dir/identity-${override_id}"
            done
            echo "$MARKER_END"
            ;;
    esac
}

has_block() {
    grep -qF "$MARKER_BEGIN" "$1" 2>/dev/null
}

remove_block() {
    local rc="$1"
    if ! has_block "$rc"; then
        echo "No dotfiles block found in $rc"
        return
    fi
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        !skip
    ' "$rc" > "$tmp"
    mv "$tmp" "$rc"
    echo "Removed dotfiles block from $rc"
}

install() {
    local shell="$1" profile="$2"
    local rc
    rc="$(get_rc "$shell")"

    if has_block "$rc"; then
        echo "Already installed in $rc — run uninstall first to reinstall"
        exit 1
    fi

    echo "" >> "$rc"
    gen_block "$shell" "$profile" >> "$rc"
    echo "Installed dotfiles block ($profile) in $rc"
}

uninstall() {
    local shell="$1"
    local rc
    rc="$(get_rc "$shell")"
    remove_block "$rc"
}

# --- main ---

[[ $# -lt 2 ]] && usage

action="$1"
shell="$2"

[[ "$shell" != "fish" && "$shell" != "bash" && "$shell" != "git" && "$shell" != "tmux" ]] && usage

case "$action" in
    install)
        [[ $# -ne 3 ]] && usage
        profile="$3"
        [[ " $(valid_profiles "$shell") " != *" $profile "* ]] && usage
        install "$shell" "$profile"
        ;;
    uninstall)
        uninstall "$shell"
        ;;
    *)
        usage
        ;;
esac
