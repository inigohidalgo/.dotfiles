function sanitize_git_branch
    echo $argv[1] | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]._-' '-' | tr -s '-' | sed 's/^-\|-$//g'
end

function git_worktree_add
    # Create a git worktree for a branch in a separate directory
    # Usage: git_worktree_add <branch-name> [options]
    # Options:
    #   -p/--path DIR    Base directory (creates DIR/branch-name)
    #   -n/--name NAME   Custom repo name (creates ~/repos/worktrees/NAME/branch-name)
    #   -f/--from BRANCH Create new branch starting from BRANCH
    
    # Parse arguments
    argparse 'p/path=' 'n/name=' 'f/from=' -- $argv
    or return 1

    
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
        set target_path "$custom_path/$sanitized_branch"
    else if test -n "$custom_name"
        set target_path "$HOME/repos/worktrees/$custom_name/$sanitized_branch"
    else
        # Default: ~/repos/worktrees/{repo-name}/{sanitized-branch}
        set -l repo_name (basename (git rev-parse --show-toplevel))
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

alias gwa="git_worktree_add"
alias gwl="git worktree list"
alias gwrm="git worktree remove"
alias gs="git status"
alias gcm="git commit -m"
alias gc="git checkout"