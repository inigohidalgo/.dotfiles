function sanitize_git_branch
    echo $argv[1] | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]._-' '-' | tr -s '-' | sed 's/^-\|-$//g'
end

function git_worktree_add
    # check out a branch from the current directory
    # into a worktree in another directory
    # finally return the path to the new directory
    # if no path is set it will default to a directory
    # under the global worktree directory
    # ~/repos/worktrees/{current-repo-name}/{sanitized-branch-name}
    
    # Parse arguments
    argparse 'p/path=' 'n/name=' -- $argv
    or return 1
    
    set -l branch_name $argv[1]
    set -l custom_path $_flag_path
    set -l custom_name $_flag_name
    
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

    echo "Target path $target_path"
    echo "Target branch $branch_name"
    echo "Sanitized branch $sanitized_branch"
    
    # Check if branch exists (local or remote)
    if git show-ref --verify --quiet "refs/heads/$branch_name"
        # Branch exists locally
        git worktree add "$target_path" "$branch_name"
    else if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"
        # Branch exists on remote
        git worktree add "$target_path" "$branch_name"
    else
        # Create new branch
        git worktree add "$target_path" -b "$branch_name"
    end
    
    # Return the path if successful
    if test $status -eq 0
        echo "$target_path"
    else
        return 1
    end
end

alias gwa="git_worktree_add"