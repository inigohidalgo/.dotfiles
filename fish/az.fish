function azl --wraps='az login --use-device-code' --description 'alias azl=az login --use-device-code'
  az login --use-device-code $argv  
end



function az_cp_variable_groups --description 'Copy all variable groups from one AZDO project to another'
    argparse 'dry-run' -- $argv
    
    # Get positional arguments after flag parsing
    set -l args $argv
    if test (count $args) -ne 3
        echo "Usage: copy_variable_groups [--dry-run] SOURCE_PROJECT TARGET_PROJECT ORGANIZATION"
        echo "Example: copy_variable_groups --dry-run \"Project-A\" \"Project-B\" \"https://dev.azure.com/MyOrg\""
        return 1
    end

    set -l source_project $args[1]
    set -l target_project $args[2]
    set -l organization $args[3]
    set -l is_dry_run 0
    
    if test -n "$_flag_dry_run"
        set is_dry_run 1
        echo "Running in dry-run mode - no changes will be made"
        echo "================================================"
    end

    # Get list of variable groups from source project
    set -l source_groups (az pipelines variable-group list \
        --organization "$organization" \
        --project "$source_project")

    # Check if we got any groups
    if test -z "$source_groups" 
        echo "No variable groups found in source project: $source_project"
        return 1
    end

    # First check for existing groups in target project and handle deletion
    set -l target_groups (az pipelines variable-group list \
        --organization "$organization" \
        --project "$target_project")

    echo "Checking for existing variable groups in target project..."
    
    for group in (echo $source_groups | jq -c '.[]')
        set -l name (echo $group | jq -r '.name')
        # Check if group exists in target
        set -l existing_group (echo $target_groups | jq -c ".[] | select(.name == \"$name\")")
        
        if test -n "$existing_group"
            set -l group_id (echo $existing_group | jq -r '.id')
            echo "Found existing group '$name' (ID: $group_id) in target project"
            
            if test $is_dry_run -eq 1
                echo "[DRY RUN] Would prompt to delete variable group: $name"
            else
                read -l -P "Do you want to delete variable group '$name'? (y/N) " confirm
                if test "$confirm" = "y"
                    echo "Deleting variable group: $name"
                    az pipelines variable-group delete \
                        --organization "$organization" \
                        --project "$target_project" \
                        --group-id "$group_id" \
                        --yes
                else
                    echo "Skipping deletion of group: $name"
                    continue
                end
            end
        end
    end

    # Now proceed with creation
    echo "Creating variable groups..."
    for group in (echo $source_groups | jq -c '.[]')
        set -l name (echo $group | jq -r '.name')
        set -l variables (echo $group | jq -r '.variables')
        
        # Build variables argument string
        set -l vars_string ""
        for var_name in (echo $variables | jq -r 'keys[]')
            set -l var_value (echo $variables | jq -r ".[\"$var_name\"].value")
            set vars_string "$vars_string '$var_name=$var_value'"
        end

        echo "Processing variable group: $name"
        if test $is_dry_run -eq 1
            echo "Would create variable group with command:"
            echo "az pipelines variable-group create \\"
            echo "    --organization \"$organization\" \\"
            echo "    --project \"$target_project\" \\"
            echo "    --name \"$name\" \\"
            echo "    --authorize true \\"
            echo "    --variables $vars_string"
        else
            echo "Creating variable group: $name"
            eval "az pipelines variable-group create \
                --organization \"$organization\" \
                --project \"$target_project\" \
                --name \"$name\" \
                --authorize true \
                --variables $vars_string"
        end
    end
end


function az_pipeline_status --description 'Get status of recent Azure pipeline runs for current repository'
    # Fix argparse syntax with correct Fish format
    argparse -n az_pipeline_status \
             'o/organization=' \
             'p/project=' \
             'r/repository=' \
             't/repository-type=' \
             'n/top=' \
             'b/branch=' \
             's/status=' \
             'result=' \
             'h/help' -- $argv
    
    if set -q _flag_help
        echo "Usage: az_pipeline_status [options]"
        echo
        echo "Options:"
        echo "  -o, --organization=URL    Azure DevOps organization URL"
        echo "  -p, --project=NAME        Azure DevOps project name"
        echo "  -r, --repository=REPO     Repository name (e.g., org/repo)"
        echo "  -t, --repository-type=TYPE Repository type (default: github)"
        echo "  -n, --top=NUMBER          Number of runs to display (default: 10)"
        echo "  -b, --branch=BRANCH       Filter by branch name (e.g., refs/heads/main)"
        echo "  -s, --status=STATUS       Filter by status (allowed: all, cancelling, completed, inProgress, none, notStarted, postponed)"
        echo "  --result=RESULT           Filter by result (allowed: canceled, failed, none, partiallySucceeded, succeeded)"
        echo "  -h, --help                Show this help message"
        echo
        echo "Examples:"
        echo "  az_pipeline_status"
        echo "  az_pipeline_status -b refs/heads/main -s completed --result succeeded"
        return 0
    end
    
    # Default values
    set -l org $_flag_organization
    set -l project $_flag_project
    set -l repo $_flag_repository
    set -l repo_type $_flag_repository_type
    set -l top $_flag_top
    set -l branch $_flag_branch
    set -l run_status $_flag_status  # Renamed status to run_status
    set -l result $_flag_result
    
    if test -z "$run_status"
        set run_status "all"
    end

    # Validate status if provided
    set -l valid_statuses "all" "cancelling" "completed" "inProgress" "none" "notStarted" "postponed"
    set -l status_valid 0
    
    for valid_status in $valid_statuses
        if test "$run_status" = "$valid_status"
            set status_valid 1
            break
        end
    end
    
    if test $status_valid -eq 0
        echo "Error: '$run_status' is not a valid value for status."
        echo "Allowed values: all, cancelling, completed, inProgress, none, notStarted, postponed."
        return 1
    end
    
    # Validate result if provided
    if test -n "$result"
        set -l valid_results "canceled" "failed" "none" "partiallySucceeded" "succeeded"
        set -l result_valid 0
        
        for valid_result in $valid_results
            if test "$result" = "$valid_result"
                set result_valid 1
                break
            end
        end
        
        if test $result_valid -eq 0
            echo "Error: '$result' is not a valid value for result."
            echo "Allowed values: canceled, failed, none, partiallySucceeded, succeeded."
            return 1
        end
    end
    
    # Set defaults if not provided
    if test -z "$org"
        set org "https://dev.azure.com/Axpo-AXSO/"
    end
    
    if test -z "$project"
        set project "AdvancedAnalytics-General"
    end
    
    # Try to get repository from git if not provided
    if test -z "$repo"
        # Try to extract from git remote URL
        if command -q git
            set -l git_remote (git config --get remote.origin.url 2>/dev/null)
            if test $status -eq 0
                # Extract org/repo from git URL format
                echo "Attempting to extract repository from git remote: $git_remote"
                # Handle different git URL formats
                if string match -q "*github.com*" $git_remote
                    set repo (string replace -r '.*github.com[:/](.+/.+)\.git' '$1' $git_remote)
                    set repo_type "github"
                    echo "Extracted repository: $repo"
                
                # azure devops
                else if string match -q "*dev.azure.com*" $git_remote
                    # Parse Azure DevOps URL format: git@ssh.dev.azure.com:v3/Axpo-AXSO/<project>/<repo>
                    # or https://dev.azure.com/Axpo-AXSO/<project>/<repo>
                    if string match -rq -- '.*dev\.azure\.com[:/]+v3?/[^/]+/([^/]+)/([^/]+)(?:\.git)?$' $git_remote
                        set project (string replace -r '.*dev\.azure\.com[:/]+v3?/[^/]+/([^/]+)/[^/]+(?:\.git)?$' '$1' $git_remote)
                        set repo (string replace -r '.*dev\.azure\.com[:/]+v3?/[^/]+/[^/]+/([^/]+)(?:\.git)?$' '$1' $git_remote)
                        set repo_type "tfsgit"
                        echo "Extracted project: $project"
                        echo "Extracted repository: $repo"
                    end
                end
            end
        end
    end
    
    if test -z "$repo"
        set repo "axpo-ts/advancedanalytics-usecase-co2"
        echo "Using default repository: $repo"
    end
    
    if test -z "$repo_type"
        set repo_type "github"
    end
    
    if test -z "$top"
        set top 10
    end
    
    echo "Fetching pipelines for repository: $repo"
    
    # Get pipeline IDs for the specific repository
    set -l pipelines_cmd "az pipelines list --organization \"$org\" --project \"$project\" --repository \"$repo\" --repository-type \"$repo_type\""
    echo "Command: $pipelines_cmd"
    set -l pipelines_json (eval $pipelines_cmd)
    
    # Store the exit status in a variable to avoid overwriting it
    set -l cmd_status $status
    
    if test $cmd_status -ne 0
        echo "Error retrieving pipelines. Command: $pipelines_cmd"
        return 1
    end
    
    if test -z "$pipelines_json" -o "$pipelines_json" = "[]"
        echo "No pipelines found for repository: $repo"
        return 1
    end
    
    # Extract pipeline IDs
    set -l pipeline_ids (echo $pipelines_json | jq -r '.[].id')
    
    if test -z "$pipeline_ids"
        echo "Failed to extract pipeline IDs"
        return 1
    end
    
    echo "Found pipelines with IDs: $pipeline_ids"
    
    # Format pipeline IDs as space-separated string
    set -l pipeline_ids_arg (string join ' ' $pipeline_ids)
    
    # Construct base command for pipeline runs
    set -l runs_cmd "az pipelines runs list --organization \"$org\" --project \"$project\" --pipeline-ids $pipeline_ids_arg --top $top"
    
    # Add filters if specified
    if test -n "$branch"
        set runs_cmd "$runs_cmd --branch \"$branch\""
    end
    
    if test -n "$run_status"
        set runs_cmd "$runs_cmd --status \"$run_status\""
    end
    
    if test -n "$result"
        set runs_cmd "$runs_cmd --result \"$result\""
    end
    
    # Get recent runs for these pipelines
    echo "Fetching recent runs for pipelines..."
    echo "Command: $runs_cmd"
    set -l runs_json (eval $runs_cmd)
    
    # Store the exit status in a variable to avoid overwriting it
    set -l cmd_status $status
    
    if test $cmd_status -ne 0
        echo "Error retrieving pipeline runs"
        return 1
    end
    
    if test -z "$runs_json" -o "$runs_json" = "[]"
        echo "No recent pipeline runs found"
        return 1
    end
    
    # Count runs
    set -l run_count (echo $runs_json | jq '. | length')
    echo "Found $run_count pipeline runs"
    
    # Parse the date format to make it more readable
    # Display results in a nice, colorized format with correct field extraction
    echo $runs_json | jq -r '.[] | [
        (.id | tostring),
        (if .result then .result else .status end),
        (.startTime | sub("T"; " ") | sub("\\\\.[0-9]+Z$"; "")),
        (.sourceBranch | sub("refs/heads/"; ""))
    ] | @tsv' | while read -l build_id run_state start_time branch
        # Colorize run_state
        set -l state_color
        switch $run_state
            case succeeded
                set state_color (set_color green)
            case failed
                set state_color (set_color red)
            case partiallySucceeded
                set state_color (set_color yellow)
            case canceled
                set state_color (set_color blue)
            case '*'
                set state_color (set_color cyan)
        end
        
        # Build the pipeline run URL directly
        set -l run_url "$org/$project/_build/results?buildId=$build_id&view=results"
        set -l run_url_formatted (create_hyperlink "$run_url" "[#$build_id]")

        # Format output directly without using the helper function
        printf '%s%s%s: %s%s%s | %s%s%s | %s%s%s\n' \
            (set_color blue) "$run_url_formatted" (set_color normal) \
            $state_color "$run_state" (set_color normal) \
            (set_color yellow) "$start_time" (set_color normal) \
            (set_color magenta) "$branch" (set_color normal)
    end
end