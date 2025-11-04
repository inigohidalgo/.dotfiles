function sanitize_git_branch
    echo $argv[1] | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]._-' '-' | tr -s '-' | sed 's/^-\|-$//g'
end

function git_changed_files
        set mode $argv[1]

        switch $mode
                case staged
                        # Files staged for commit
                        git diff --cached --name-only
                    case unstaged
                        # Files modified but not staged
                        git diff --name-only
                    case all '*'
                        # Default: all changes (staged + unstaged) vs last commit
                        git diff HEAD --name-only
                end
end

function git_worktree_add
    # git_worktree_add - create a git worktree (use -h for help)
    argparse 'h/help' 'p/path=' 'n/name=' 'f/from=' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: git_worktree_add <branch> [options]"
        echo
        echo "Options:"
        echo "  -p, --path DIR      Use explicit directory for worktree"
        echo "  -n, --name NAME     Base folder name under ~/repos/worktrees/"
        echo "  -f, --from BRANCH   Create new branch starting from BRANCH"
        echo "  -h, --help          Show this help and exit"
        echo
        echo "Examples:"
        echo "  git_worktree_add feature-x"
        echo "  git_worktree_add feature-x -f main"
        echo "  git_worktree_add feature-x -n myrepo"
        echo "  git_worktree_add feature-x -p ~/scratch/ft-x"
        return 0
    end

    
    set -l branch_name $argv[1]
    set -l custom_path $_flag_path
    set -l custom_name $_flag_name
    set -l start_point $_flag_from
    
    # Check for mutually exclusive arguments
    if test -n "$custom_path" -a -n "$custom_name"
        echo "Error: --path and --name arguments are mutually exclusive" >&2
        return 1
    end
    
    # Validate branch name provided
    if test -z "$branch_name"
        echo "Error: Branch name required" >&2
        return 1
    end
    
    # Sanitize branch name for directory use
    set -l sanitized_branch (sanitize_git_branch $branch_name)
    or return 1
    
    # Determine target path
    set -l target_path
    if test -n "$custom_path"
        set target_path "$custom_path"
    else if test -n "$custom_name"
        set target_path "$HOME/repos/worktrees/$custom_name/$sanitized_branch"
    else
        # Default: ~/repos/worktrees/{repo-name}/{sanitized-branch}
        set -l repo_name (basename "$(dirname "$(realpath "$(git rev-parse --git-common-dir)")")")
        set target_path "$HOME/repos/worktrees/$repo_name/$sanitized_branch"
    end
    
    # Check if target directory already exists
    if test -d "$target_path"
        echo "Error: Directory already exists: $target_path" >&2
        return 1
    end

    echo "Creating worktree: $branch_name → $target_path" >&2
    
    # Check if branch exists (local or remote)
    set -l branch_exists 0
    if git show-ref --verify --quiet "refs/heads/$branch_name"; or git show-ref --verify --quiet "refs/remotes/origin/$branch_name"
        set branch_exists 1
    end
    
    # Validate start_point usage
    if test $branch_exists -eq 1 -a -n "$start_point"
        echo "Error: Branch $branch_name already exists, cannot use --from" >&2
        return 1
    end
    
    # Execute appropriate git worktree command
    if test $branch_exists -eq 1
        echo "Using existing branch: $branch_name" >&2
        git worktree add "$target_path" "$branch_name" >&2
    else if test -n "$start_point"
        echo "Creating new branch: $branch_name from $start_point" >&2
        git worktree add "$target_path" -b "$branch_name" "$start_point" >&2
    else
        echo "Creating new branch: $branch_name" >&2
        git worktree add "$target_path" -b "$branch_name" >&2
    end
    
    # Return the path if successful
    if test $status -eq 0
        echo "Worktree ready: $target_path" >&2
        set -g worktree_dir "$target_path"
        echo "Variable \$worktree_dir set to: $target_path" >&2
        echo "$target_path"
    else
        echo "Failed to create worktree" >&2
        return 1
    end
end

abbr -a g 'git'

alias gwa="git_worktree_add"

