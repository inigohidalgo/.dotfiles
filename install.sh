#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_BEGIN="# <<< dotfiles >>>"
MARKER_END="# <<< /dotfiles >>>"

# --- profiles: module lists per shell and profile ---

FISH_HOME="env fs git nav python ssh utils"
FISH_WORK="$FISH_HOME argo az claude-profiles"

BASH_HOME="functions"
BASH_WORK="$BASH_HOME install_packages"

# git: identity defaults flip per profile, "other" identity is wired via includeIf
GIT_HOME_DEFAULT="personal"
GIT_HOME_OVERRIDE_GITDIRS="~/dev/repos/axpo/"
GIT_WORK_DEFAULT="work"
GIT_WORK_OVERRIDE_GITDIRS="~/dev/repos/ihr/ ~/plan/"

usage() {
    echo "Usage: $0 <install|uninstall> <fish|bash|git> [home|work]"
    echo "  profile is required for install, ignored for uninstall"
    exit 1
}

fish_rc() {
    local rc="$HOME/.config/fish/config.fish"
    mkdir -p "$(dirname "$rc")"
    echo "$rc"
}

bash_rc() {
    echo "$HOME/.bashrc"
}

git_rc() {
    echo "$HOME/.gitconfig"
}

get_rc() {
    case "$1" in
        fish) fish_rc ;;
        bash) bash_rc ;;
        git)  git_rc  ;;
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

[[ "$shell" != "fish" && "$shell" != "bash" && "$shell" != "git" ]] && usage

case "$action" in
    install)
        [[ $# -ne 3 ]] && usage
        profile="$3"
        [[ "$profile" != "home" && "$profile" != "work" ]] && usage
        install "$shell" "$profile"
        ;;
    uninstall)
        uninstall "$shell"
        ;;
    *)
        usage
        ;;
esac
