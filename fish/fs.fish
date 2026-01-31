function mkd --description 'Create directory with date or UUID prefix'
    argparse 'h/help' 'u/uuid' 'p/path=' 'j/jump' -- $argv
    or return 1

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: mkd [OPTIONS] DESCRIPTION" >&2
        echo "" >&2
        echo "Create a directory with a date or UUID prefix." >&2
        echo "" >&2
        echo "Options:" >&2
        echo "  -h, --help       Show this help message" >&2
        echo "  -u, --uuid       Use UUID prefix instead of date" >&2
        echo "  -p, --path PATH  Create directory in PATH (default: current dir)" >&2
        echo "  -j, --jump       cd into the created directory" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  mkd my-project          # Creates 2024-01-31_my-project" >&2
        echo "  mkd -u temp             # Creates 550e8400-e29b_temp" >&2
        echo "  mkd -j work             # Creates dir and cd's into it" >&2
        echo "  mkd foo | code          # Creates dir and opens in VS Code" >&2
        echo "" >&2
        echo "Sets \$created_dir to the created path for scripting." >&2
        return 0
    end

    set -l description $argv[1]

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
        if set -q _flag_jump
            echo "Changing directory to: $full_path" >&2
            cd "$full_path"
        end
    else
        echo "Failed to create directory" >&2
        return 1
    end
end
