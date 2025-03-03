function argo_clean_cronworkflows_by_label
    # Define and parse options
    set -l options (fish_opt --short=s --long=suspend)
    set -a options (fish_opt --short=d --long=delete)
    set -a options (fish_opt --short=h --long=help)
    argparse $options -- $argv
    
    # Show help and examples if requested
    if set -q _flag_help
        echo "Usage: delete_argo_cronworkflows_by_label [OPTIONS] LABEL [NAMESPACE]"
        echo ""
        echo "Options:"
        echo "  -s, --suspend    Suspend Argo workflows matching the label"
        echo "  -d, --delete     Delete Argo workflows matching the label"
        echo "  -h, --help       Show this help message"
        echo ""
        echo "Examples:"
        echo "  delete_argo_cronworkflows_by_label --delete app=myapp"
        echo "  delete_argo_cronworkflows_by_label --suspend env=dev my-namespace"
        echo ""
        return 0
    end

    set -l label $argv[1]
    set -l namespace $argv[2]
    
    # Set the action based on flags
    set -l clean_action ""
    if set -q _flag_suspend
        set clean_action "suspend"
    else if set -q _flag_delete
        set clean_action "delete"
    else
        echo "Please specify an action: --suspend or --delete"
        echo "Use --help for usage examples"
        return 1
    end
    
    if test -z "$label"
        echo "Please provide a label selector"
        echo "Use --help for usage examples"
        return 1
    end

    # Build namespace argument if specified
    set -l ns_arg ""
    if test -n "$namespace"
        set ns_arg "-n $namespace"
    end

    # List the workflows first
    echo "Workflows matching label: $label"
    if test -n "$namespace"
        echo "in namespace: $namespace"
    end
    echo "----------------------------------------"
    
    # Get workflow list once and store it
    set -l cmd "argo cron list -l $label $ns_arg"
    echo "Executing: $cmd"
    set -l workflows (eval $cmd)
    
    if test $status -ne 0
        echo "Error listing workflows"
        return 1
    end
    
    string collect -- $workflows
    echo "----------------------------------------"
    
    # Check if any workflows were found (more than header + separator lines)
    set -l workflow_count (string split \n $workflows | count)
    if test $workflow_count -le 2
        echo "No workflows found matching the label"
        return 0
    end
    
    read -l -P "Do you want to $clean_action these workflows? [y/N] " confirm
    
    if test "$confirm" = "y" -o "$confirm" = "Y"
        # Extract workflow names from the stored list (skip header row)
        for workflow in (string split \n $workflows | tail -n +2 | awk '{print $1}')
            echo "$clean_action workflow: $workflow"
            set -l cmd "argo cron $clean_action $workflow $ns_arg"
            echo "Executing: $cmd"
            eval $cmd
        end
        echo "$clean_action complete"
    else
        echo "Operation cancelled"
    end
end