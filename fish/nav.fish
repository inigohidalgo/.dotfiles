# navigation shortcuts
# abbr expands the command after pressing <space>
#
# --set-cursor and adding `%` will move the cursor to that location

# zoxide: frecency-based cd. `z foo` jumps to best match, `zi` opens fzf picker.
if type -q zoxide
    zoxide init fish | source
end

# fzf: Ctrl-T (file picker), Ctrl-R (history), Alt-C (cd picker)
if type -q fzf
    fzf --fish | source
end

# ff: fuzzy-find a file with fd + fzf (bat preview), print path to stdout
if type -q fd; and type -q fzf
    function ff --description "fuzzy file finder (fd + fzf), prints selection"
        set -l preview_cmd
        if type -q bat
            set preview_cmd 'bat --style=numbers --color=always --line-range=:200 {}'
        else
            set preview_cmd 'cat {}'
        end
        fd --type f --hidden --follow --exclude .git $argv | fzf --select-1 --preview "$preview_cmd"
    end
end

# batf: view an ff-picked file with bat
if type -q bat
    function batf --description "ff piped into bat"
        set -l file (ff $argv)
        or return
        bat -- $file
    end
end

abbr -a ..2 "cd ../.."
abbr -a ..3 "cd ../../.."
abbr -a ..4 "cd ../../../.."
abbr -a ..5 "cd ../../../../.."

abbr -a --set-cursor cdc 'cd $HOME/.config/%'
abbr -a --set-cursor cdcf 'cd $HOME/.config/fish/%'

abbr -a --set-cursor cdd 'cd $DEV_DIR/%'
abbr -a --set-cursor cdp 'cd $PLAN_DIR/main/%'
abbr -a --set-cursor cddt 'cd $DEV_DIR/tmp/%'

abbr -a --set-cursor cds 'cd $DEV_DIR/stacks/%'


abbr -a --set-cursor cdr 'cd $REPOS_DIR/%'
abbr -a --set-cursor cdra 'cd $REPOS_DIR/axpo/%'
abbr -a --set-cursor cdrau 'cd $AU_REPO_DIR/%'
abbr -a --set-cursor cdrw 'cd $GWT_DIR/%'
abbr -a --set-cursor cdri 'cd $REPOS_DIR/ihr/%'

abbr -a --set-cursor cdt 'cd $TOOLS_DIR/%'
abbr -a --set-cursor cdtp 'cd $TOOLS_DIR/pythia/%'
abbr -a --set-cursor cdtb 'cd $TOOLS_DIR/bimo/%'
abbr -a --set-cursor cdtd 'cd $TOOLS_DIR/dsbuilder/%'

abbr -a --set-cursor cdu 'cd $UC_DIR/%'

if type -q eza
    function ls --description "eza simple list (all files, modification times)"
        eza -al --time-style="+%y-%m-%d %H:%M" --no-permissions --no-filesize --no-user $argv
    end

    function ll --description "long listing with perms, user, date, hidden"
        eza -al --time-style="+%y-%m-%d %H:%M" $argv
    end

    function lt --description "tree view, 2 levels deep, hidden + times"
        eza -aT --level=2 --time-style="+%y-%m-%d %H:%M" $argv
    end

    function lg --description "git-enhanced ls"
        eza -al --git --time-style="+%y-%m-%d %H:%M" --no-permissions --no-filesize --no-user $argv
    end
end