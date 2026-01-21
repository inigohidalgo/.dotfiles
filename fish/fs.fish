function mkd --description 'Create directory with date or UUID prefix'
    argparse 'u/uuid' 'p/path=' -- $argv
    or return 1

    set -l description $argv[1]

    if test -z "$description"
        echo "Error: Description required" >&2
        return 1
    end

    # Generate prefix
    set -l prefix
    if set -q _flag_uuid
        set prefix (generate_prefix uuid)
    else
        set prefix (generate_prefix date)
    end

    # Sanitize description (replace spaces and special chars with underscores)
    set -l sanitized_desc (string replace -ra '[^a-zA-Z0-9_-]' '_' $description | string replace -ra '_+' '_')

    # Create full directory name
    set -l dir_name "$prefix"_"$sanitized_desc"

    # Determine base path
    set -l base_path
    if test -n "$_flag_path"
        set base_path "$_flag_path"
    else
        set base_path "$PWD"
    end

    set -l full_path "$base_path/$dir_name"

    # Create directory
    mkdir -p "$full_path"

    if test $status -eq 0
        echo "Directory created: $full_path" >&2
        set -g created_dir "$full_path"
        echo "Variable \$created_dir set to: $full_path" >&2
        echo "$full_path"
    else
        echo "Failed to create directory" >&2
        return 1
    end
end
