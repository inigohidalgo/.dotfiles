#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Every block opens and closes with `<<< dotfiles >>>` / `<<< /dotfiles >>>`,
# written as a comment in the rc file's own language: `#` everywhere except Lua
# (rex), where `#` isn't a comment and `--` is.
comment_leader() { case "$1" in rex) echo "--" ;; *) echo "#" ;; esac; }
marker_begin()   { echo "$(comment_leader "$1") <<< dotfiles >>>"; }
marker_end()     { echo "$(comment_leader "$1") <<< /dotfiles >>>"; }

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
# Beacon IDE container. `fish` (sh/fish.sh) execs fish at the end of an
# interactive bash's rc; that file's header argues why the handoff goes through
# bash and why it is opt-in per profile. Two rules bind here:
#
#   - Never in home/work. On a machine whose $SHELL is already fish (both Macs)
#     it would leave no way to a bash prompt but DOTFILES_NO_FISH=1.
#   - Keep `fish` LAST, here and in any profile that ever gains it: it execs, so
#     nothing after it in the rc runs — including another installer's block.
BASH_BEACON_IDE="$BASH_HOME fish"
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
TMUX_BEACON_IDE="options keys workflows theme host-beacon-ide"

# rex: Lua modules dofile'd from ~/.config/rex/init.lua. Other repos' installers
# (e.g. clauder shipping deck actions) are meant to add their own namespaced block
# there, `-- <<< NAME >>>`, the same way clauder does in the shell rc files — so
# each installer only ever touches its own block.
REX_HOME="edited-file rssh-split"

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
    echo "Usage: $0 <install|uninstall> <fish|bash|git|tmux|rex|karabiner|rssh> [profile]"
    echo "  profile is required for install, ignored for uninstall"
    echo "  profiles: fish/git → home|work, bash → home|work|beacon-ide|dslab, tmux → local|remote|beacon-ide, rex|karabiner|rssh → home"
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

rex_rc() {
    # Rex reads $REX_CONFIG, else rex/init.lua under $XDG_CONFIG_HOME (falling
    # back to ~/.config). Mirror that — but note it's the Rex *server's*
    # environment that counts (the Rex app starts it), not this shell's, the same
    # caveat as karabiner. Both are normally unset, giving ~/.config/rex/init.lua.
    local rc="${REX_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua}"
    mkdir -p "$(dirname "$rc")"
    echo "$rc"
}

get_rc() {
    case "$1" in
        fish) fish_rc ;;
        bash) bash_rc ;;
        git)  git_rc  ;;
        tmux) tmux_rc ;;
        rex)  rex_rc  ;;
    esac
}

valid_profiles() {
    case "$1" in
        tmux) echo "local remote beacon-ide" ;;
        bash) echo "home work beacon-ide dslab" ;;
        rex|karabiner|rssh) echo "home" ;;
        *)    echo "home work" ;;
    esac
}

get_modules() {
    local shell="$1" profile="$2"
    local var
    # `-` folds to `_` so a hyphenated profile survives becoming a variable
    # name: without it, beacon-ide looks up $BASH_BEACON followed by a literal
    # -IDE, which under `set -u` aborts the install outright.
    var="$(echo "${shell}_${profile}" | tr '[:lower:]-' '[:upper:]_')"
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
            marker_begin "$shell"
            echo "set -x DOTFILE_DIR \"$dir\""
            for mod in $modules; do
                echo "source \$DOTFILE_DIR/${mod}${ext}"
            done
            marker_end "$shell"
            ;;
        bash)
            modules="$(get_modules "$shell" "$profile")"
            dir="$SCRIPT_DIR/sh"
            ext=".sh"
            marker_begin "$shell"
            echo "export DOTFILE_DIR=\"$dir\""
            for mod in $modules; do
                echo "source \"\$DOTFILE_DIR/${mod}${ext}\""
            done
            marker_end "$shell"
            ;;
        tmux)
            modules="$(get_modules "$shell" "$profile")"
            dir="$SCRIPT_DIR/tmux"
            marker_begin "$shell"
            for mod in $modules; do
                echo "source-file \"$dir/${mod}.conf\""
            done
            marker_end "$shell"
            ;;
        rex)
            modules="$(get_modules "$shell" "$profile")"
            dir="$SCRIPT_DIR/rex"
            marker_begin "$shell"
            for mod in $modules; do
                echo "dofile(\"$dir/${mod}.lua\")"
            done
            marker_end "$shell"
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
            marker_begin "$shell"
            echo "[include]"
            echo "    path = $dir/common"
            echo "    path = $dir/identity-${default_id}"
            for gd in $override_gitdirs; do
                echo "[includeIf \"gitdir:${gd}\"]"
                echo "    path = $dir/identity-${override_id}"
            done
            marker_end "$shell"
            ;;
    esac
}

has_block() {
    local rc="$1" shell="$2"
    # -x: the marker must be the whole line, as remove_block's awk requires too — a
    # comment that merely mentions it must not count as an installed block.
    # -e: the Lua marker starts with `--`, which grep would otherwise parse as an option.
    grep -qxF -e "$(marker_begin "$shell")" -- "$rc" 2>/dev/null
}

remove_block() {
    local rc="$1" shell="$2"
    if ! has_block "$rc" "$shell"; then
        echo "No dotfiles block found in $rc"
        return
    fi
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$(marker_begin "$shell")" -v end="$(marker_end "$shell")" '
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

    if has_block "$rc" "$shell"; then
        echo "Already installed in $rc — run uninstall first to reinstall"
        exit 1
    fi

    echo "" >> "$rc"
    gen_block "$shell" "$profile" >> "$rc"
    echo "Installed dotfiles block ($profile) in $rc"
    [[ "$shell" == "rex" ]] && echo "Rex reads init.lua at startup: run Reload Config from the command palette" || true
}

uninstall() {
    local shell="$1"
    local rc
    rc="$(get_rc "$shell")"
    remove_block "$rc" "$shell"
}

# --- karabiner: a symlink-based install ---
#
# Everything above writes a marker block into an rc file this repo doesn't own
# outright. Karabiner-Elements has no include mechanism, so there is no block to
# write: the repo owns the whole config directory instead, and the live config
# dir becomes a symlink to karabiner/config. Owning it outright is safe because
# nothing but Karabiner itself writes there — its Settings window rewrites
# karabiner.json in place, and those edits land in the repo as a `git diff`.
#
# Link the directory, never karabiner.json itself: Karabiner's docs are explicit
# that it fails to detect changes (and so never reloads) when karabiner.json is a
# symlink. After moving the config, Karabiner-Console-User-Server has to be
# restarted once before it watches the new location — install does that.

KARABINER_SRC="$SCRIPT_DIR/karabiner/config"
KARABINER_AGENT="org.pqrs.service.agent.Karabiner-Console-User-Server"

karabiner_dir() {
    # Karabiner honours XDG_CONFIG_HOME, but from its launchd agents'
    # environment, not this shell's — so ask launchd, not $XDG_CONFIG_HOME.
    # Unset there (the normal case) → ~/.config/karabiner.
    local xdg
    xdg="$(launchctl getenv XDG_CONFIG_HOME 2>/dev/null || true)"
    echo "${xdg:-$HOME/.config}/karabiner"
}

restart_karabiner_agent() {
    launchctl kickstart -k "gui/$(id -u)/$KARABINER_AGENT" \
        || echo "warning: could not restart $KARABINER_AGENT — is Karabiner-Elements installed?"
}

install_karabiner() {
    local dst
    dst="$(karabiner_dir)"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$KARABINER_SRC" ]]; then
        echo "Already installed: $dst -> $KARABINER_SRC"
        exit 1
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        local aside
        aside="$dst.pre-dotfiles-$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$aside"
        echo "Moved existing $dst aside to $aside"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$KARABINER_SRC" "$dst"
    restart_karabiner_agent
    echo "Linked $dst -> $KARABINER_SRC"
}

uninstall_karabiner() {
    # Leave a real copy behind, not nothing: an empty config dir would silently
    # drop every rule and device grab on Karabiner's next reload.
    local dst
    dst="$(karabiner_dir)"
    if [[ ! -L "$dst" || "$(readlink "$dst")" != "$KARABINER_SRC" ]]; then
        echo "No dotfiles symlink at $dst"
        return
    fi
    rm "$dst"
    cp -R "$KARABINER_SRC" "$dst"
    restart_karabiner_agent
    echo "Replaced symlink $dst with a copy of $KARABINER_SRC"
}

# --- rssh: commands linked into ~/.local/bin ---
#
# rssh is two commands rather than config, so there is no rc file to put a block
# in: install links both into ~/.local/bin, which every shell (fish, bash, and the
# PATH-less one `ssh host cmd` gets) can reach. Both go on every machine — `rssh`
# is what a Rex machine runs, `rssh-host` what a remote host is reached through —
# so one target serves both roles. rssh calls the host side by that fixed path,
# which keeps it independent of where each host keeps its clone of this repo.

RSSH_SRC="$SCRIPT_DIR/rssh"
RSSH_BIN="$HOME/.local/bin"
RSSH_CMDS="rssh rssh-host"

install_rssh() {
    mkdir -p "$RSSH_BIN"
    local cmd dst
    for cmd in $RSSH_CMDS; do
        dst="$RSSH_BIN/$cmd"
        if [[ -L "$dst" && "$(readlink "$dst")" == "$RSSH_SRC/$cmd" ]]; then
            echo "Already linked: $dst -> $RSSH_SRC/$cmd"
            continue
        fi
        if [[ -e "$dst" || -L "$dst" ]]; then
            local aside
            aside="$dst.pre-dotfiles-$(date +%Y%m%d-%H%M%S)"
            mv "$dst" "$aside"
            echo "Moved existing $dst aside to $aside"
        fi
        ln -s "$RSSH_SRC/$cmd" "$dst"
        echo "Linked $dst -> $RSSH_SRC/$cmd"
    done
}

uninstall_rssh() {
    local cmd dst
    for cmd in $RSSH_CMDS; do
        dst="$RSSH_BIN/$cmd"
        if [[ -L "$dst" && "$(readlink "$dst")" == "$RSSH_SRC/$cmd" ]]; then
            rm "$dst"
            echo "Removed $dst"
        else
            echo "No dotfiles link at $dst"
        fi
    done
}

# --- main ---

[[ $# -lt 2 ]] && usage

action="$1"
shell="$2"

[[ "$shell" != "fish" && "$shell" != "bash" && "$shell" != "git" && "$shell" != "tmux" && "$shell" != "rex" && "$shell" != "karabiner" && "$shell" != "rssh" ]] && usage

case "$action" in
    install)
        [[ $# -ne 3 ]] && usage
        profile="$3"
        [[ " $(valid_profiles "$shell") " != *" $profile "* ]] && usage
        if [[ "$shell" == "karabiner" ]]; then
            install_karabiner
        elif [[ "$shell" == "rssh" ]]; then
            install_rssh
        else
            install "$shell" "$profile"
        fi
        ;;
    uninstall)
        if [[ "$shell" == "karabiner" ]]; then
            uninstall_karabiner
        elif [[ "$shell" == "rssh" ]]; then
            uninstall_rssh
        else
            uninstall "$shell"
        fi
        ;;
    *)
        usage
        ;;
esac
