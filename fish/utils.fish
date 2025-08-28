# Function to create a clickable hyperlink for terminal output
function create_hyperlink --description 'Create a clickable hyperlink for terminal output'
    # Arguments:
    # $argv[1]: URL/link to navigate to
    # $argv[2]: display text 
    
    if test (count $argv) -lt 2
        echo "Usage: create_hyperlink <url> <display_text>"
        return 1
    end
    
    set -l url $argv[1]
    set -l display_text $argv[2]
    
    # Return the formatted hyperlink string using ANSI escape sequences
    printf "%b" "\033]8;;$url\007$display_text\033]8;;\007"
end

function colorize --description 'Print $argv in given color & style'
    set -l col $argv[1]; set -e argv[1]
    printf "%s%s%s" (set_color $col --bold) "$argv" (set_color normal)
end
