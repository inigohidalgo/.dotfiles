# navigation shortcuts
# abbr expands the command after pressing <space>
#
# --set-cursor and adding `%` will move the cursor to that location

# zoxide: frecency-based cd. `z foo` jumps to best match, `zi` opens fzf picker.
if type -q zoxide
    zoxide init fish | source
end

# fzf: Ctrl-T (file picker), Ctrl-R (history), Alt-C (cd picker)
# --fish needs fzf >= 0.48; older versions error, so silence and skip bindings
if type -q fzf
    fzf --fish 2>/dev/null | source
end

# fzp / fzx: fuzzy-find a file by name pattern.
#   fzp prints the path        -- nvim (fzp 260804)
#   fzx runs a command on it   -- fzx nvim 260804
# fzp owns every search flag; fzx just forwards its tail to fzp verbatim, so
# `fzx CMD ARGS` is always exactly `CMD (fzp ARGS)`.

# commands fzx refuses because they read stdin and ignore path arguments;
# extend with `set -a fzx_stdin_only <cmd>`
set -g fzx_stdin_only pbcopy pbpaste tr xargs

if type -q fd; and type -q fzf
    function fzp --description "fuzzy file finder (fd + fzf), prints the picked path"
        argparse --name=fzp h/help 'p/path=' 'e/ext=' a/all d/dirs m/multi -- $argv
        or return 1

        if set -q _flag_help; or test (count $argv) -eq 0
            set -l out 1
            set -q _flag_help; or set out 2
            printf '%s\n' \
                "usage: fzp [-p DIR] [-e EXT] [-a] [-d] [-m] PATTERN" \
                "" \
                "  prints the absolute path of the file matching PATTERN; opens" \
                "  the fzf picker (bat preview) when several match" \
                "" \
                "  -p --path DIR  search DIR instead of the current directory" \
                "  -e --ext EXT   only files with this extension" \
                "  -a --all       include gitignored files" \
                "  -d --dirs      match directories instead of files" \
                "  -m --multi     pick several with tab; prints one per line" \
                "" \
                "PATTERN is an fd regex matched against the file name:" \
                "  260804 contains it, '^260804' starts with it" \
                "" \
                "examples:" \
                "  nvim (fzp 260804)" \
                "  bat (fzp -p ~/.claude settings)" \
                "  diff (fzp -e md draft) (fzp -e md final)" >&$out
            set -q _flag_help; and return 0
            return 2
        end

        if test (count $argv) -gt 1
            echo "fzp: expected one PATTERN, got "(count $argv)": $argv" >&2
            echo "fzp: to search elsewhere use -p DIR" >&2
            return 2
        end

        set -l root .
        if set -q _flag_path
            set root $_flag_path
            if not test -d "$root"
                echo "fzp: no such directory: $root" >&2
                return 1
            end
        end

        # --base-directory: search from $root but print paths relative to it,
        # so the picker reads the same whether -p was used or not
        set -l type f
        set -q _flag_dirs; and set type d
        set -l fdopts --type $type --hidden --follow --exclude .git --base-directory "$root"
        set -q _flag_all; and set -a fdopts --no-ignore
        set -q _flag_ext; and set -a fdopts --extension $_flag_ext

        # fzf runs previews from *our* cwd, so hand it the root through the
        # environment -- sh expands it, which sidesteps quoting a path in
        # the preview string
        set -lx FZP_ROOT "$root"
        set -l preview 'cat "$FZP_ROOT"/{}'
        type -q bat; and set preview 'bat --style=numbers --color=always --line-range=:200 "$FZP_ROOT"/{}'
        if set -q _flag_dirs
            set preview 'ls -A "$FZP_ROOT"/{}'
            type -q eza; and set preview 'eza -a --color=always "$FZP_ROOT"/{}'
        end

        set -l fzfopts --select-1 --exit-0 --prompt "$argv[1]> " \
            --preview "$preview" --preview-window 'right,60%,<80(up,60%)'
        set -q _flag_multi; and set -a fzfopts --multi

        set -l picked (fd $fdopts -- $argv[1] | fzf $fzfopts)
        set -l rc $status
        if test $rc -ne 0
            # 130 = picker aborted on purpose; anything else = nothing matched
            test $rc -eq 130; and return 130
            echo "fzp: no match for '$argv[1]' under "(path resolve "$root") >&2
            return 1
        end

        # picks come back relative to $root; print them absolute so callers get
        # the same shape of path every time (symlinks are resolved too)
        path resolve -- $root/$picked
    end

    function fzx --description "fuzzy-find a file by pattern and run a command on it"
        if test (count $argv) -lt 2; or contains -- $argv[1] -h --help
            set -l out 1
            contains -- $argv[1] -h --help; or set out 2
            printf '%s\n' \
                "usage: fzx CMD [CMD-ARGS... --] FZP-ARGS... PATTERN" \
                "" \
                "  shorthand for: CMD (fzp FZP-ARGS... PATTERN)" \
                "  everything after CMD is handed to fzp untouched, so every fzp" \
                "  flag works here too -- see fzp -h" \
                "" \
                "  the picked path is appended to CMD, or substituted for a" \
                "  literal {} if one appears in CMD's arguments" \
                "" \
                "  CMD must accept a path as an argument. Commands that only read" \
                "  stdin (\$fzx_stdin_only) are refused -- pipe fzp into them" \
                "  instead. Abbreviations don't expand here; functions do." \
                "" \
                "  to give CMD its own flags, close the command line with --:" \
                "    fzx bat --color always -- -p ~/.claude 260804" \
                "    \\____ command ____/    \\___ fzp args ___/" \
                "" \
                "examples:" \
                "  fzx bat 260804                   bat the file named ...260804..." \
                "  fzx -p ~/.claude nvim settings   INVALID -- fzx flags go to fzp" \
                "  fzx nvim -p ~/.claude settings   edit a match under ~/.claude" \
                "  fzx cp {} /tmp/ -- 260804        {} marks where the path goes" >&$out
            contains -- $argv[1] -h --help; and return 0
            return 2
        end

        # a -- closes the command line; without one, only argv[1] is the command
        set -l cmd $argv[1]
        set -l find_args $argv[2..-1]
        set -l sep (contains -i -- -- $argv)
        if set -q sep[1]
            set cmd $argv[1..(math $sep[1] - 1)]
            set find_args $argv[(math $sep[1] + 1)..-1]
        end

        if test (count $find_args) -eq 0
            echo "fzx: no PATTERN to search for" >&2
            return 2
        end

        # both checks run before the picker, so a mistake costs no interaction

        # typos, and abbreviations (which never expand in this position)
        if not type -q $cmd[1]; and not test -x "$cmd[1]"
            echo "fzx: unknown command: $cmd[1]" >&2
            abbr -q $cmd[1]; and echo "fzx: '$cmd[1]' is an abbreviation -- abbreviations only expand as you type" >&2
            return 127
        end

        # commands that read stdin would ignore the path and hang on the terminal
        if contains -- $cmd[1] $fzx_stdin_only
            echo "fzx: $cmd[1] reads stdin and ignores path arguments" >&2
            echo "fzx: pipe instead -- fzp $find_args | $cmd" >&2
            return 2
        end

        set -l picked (fzp $find_args)
        set -l rc $status
        test $rc -eq 0; or return $rc

        if contains -- '{}' $cmd
            set -l expanded
            for arg in $cmd
                if test "$arg" = '{}'
                    set -a expanded $picked
                else
                    set -a expanded $arg
                end
            end
            set cmd $expanded
        else
            set -a cmd $picked
        end

        $cmd
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