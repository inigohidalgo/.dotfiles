function mkd --description 'Create directory with date or UUID prefix'
    argparse 'h/help' 'u/uuid' 'p/path=' 'j/jump' 'e/editor' 'c/chat' 't/tmp' 's/stacks' -- $argv
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
        echo "  -e, --editor     Open the directory in VS Code" >&2
        echo "  -c, --chat       Create in ~/chat/" >&2
        echo "  -t, --tmp        Create in ~/dev/tmp/" >&2
        echo "  -s, --stacks     Create in ~/dev/stacks/" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  mkd my-project          # Creates 2024-01-31_my-project" >&2
        echo "  mkd -u temp             # Creates 550e8400-e29b_temp" >&2
        echo "  mkd -j work             # Creates dir and cd's into it" >&2
        echo "  mkd -cj my-chat         # Creates in ~/chat/ and cd's into it" >&2
        echo "  mkd -e foo              # Creates dir and opens in VS Code" >&2
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
    set -l location_flags 0
    set -q _flag_chat; and set location_flags (math $location_flags + 1)
    set -q _flag_tmp; and set location_flags (math $location_flags + 1)
    set -q _flag_stacks; and set location_flags (math $location_flags + 1)
    set -q _flag_path; and set location_flags (math $location_flags + 1)

    if test $location_flags -gt 1
        echo "Error: -c, -t, -s, and -p are mutually exclusive" >&2
        return 1
    end

    set -l base_path
    if set -q _flag_chat
        set base_path ~/chat
    else if set -q _flag_tmp
        set base_path ~/dev/tmp
    else if set -q _flag_stacks
        set base_path ~/dev/stacks
    else if test -n "$_flag_path"
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
        if set -q _flag_editor
            echo "Opening in VS Code: $full_path" >&2
            code "$full_path"
        end
        if set -q _flag_jump
            echo "Changing directory to: $full_path" >&2
            cd "$full_path"
        end
    else
        echo "Failed to create directory" >&2
        return 1
    end
end
