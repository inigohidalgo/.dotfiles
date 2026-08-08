# Pandoc defaults, CSS, and the AppleScript ship alongside this module rather
# than in ~/.config, so the repo is the single source of truth. DOTFILE_DIR is
# exported by the dotfiles block in config.fish; an explicit mdview_assets set
# before this file is sourced wins.
set -q mdview_assets; or set -g mdview_assets $DOTFILE_DIR/mdview

function mdview --description "Render a markdown file to HTML/PDF, or read it in the terminal"
    argparse --name=mdview h/help p/pdf w/html T/term n/no-open t/toc 'o/out=' -- $argv
    or return 1

    if set -q _flag_help; or test (count $argv) -eq 0
        set -l fd 1
        set -q _flag_help; or set fd 2
        printf '%s\n' \
            "usage: mdview [--html|--term|--pdf] [--toc] [--out FILE] [--no-open] FILE.md" \
            "" \
            "  -w --html      (default) GitHub-styled HTML, new Safari window" \
            "  -T --term      read in the terminal with glow (writes no file)" \
            "  -p --pdf       render via typst, open in Preview" \
            "  -t --toc       include a table of contents       [html/pdf only]" \
            "  -o --out FILE  write here; its extension picks the format" \
            "  -n --no-open   render only, print the path       [html/pdf only]" \
            "" \
            "window placement (set in ~/.config/fish/config.fish):" \
            "  set -g mdview_width 780      window width in px (clamped to screen)" \
            "  set -g mdview_side  left     left | right" >&$fd
        set -q _flag_help; and return 0
        return 1
    end

    if test (count $argv) -gt 1
        echo "mdview: expected one file, got "(count $argv)": $argv" >&2
        return 2
    end

    set -l src $argv[1]
    if not test -f "$src"
        echo "mdview: no such file: $src" >&2
        return 1
    end

    # format flags are mutually exclusive -- don't silently pick a winner
    set -l picked
    set -q _flag_pdf; and set -a picked --pdf
    set -q _flag_html; and set -a picked --html
    set -q _flag_term; and set -a picked --term
    if test (count $picked) -gt 1
        echo "mdview: conflicting format flags: $picked" >&2
        return 2
    end

    if set -q _flag_term
        set -l unsupported
        set -q _flag_out; and set -a unsupported --out
        set -q _flag_toc; and set -a unsupported --toc
        set -q _flag_no_open; and set -a unsupported --no-open
        if test (count $unsupported) -gt 0
            echo "mdview: --term writes no file, so it ignores: $unsupported" >&2
            return 2
        end
        if not command -q glow
            echo "mdview: glow not found -- brew install glow" >&2
            return 127
        end
        # glow defaults to full terminal width; cap it for readable line length
        set -l width
        test -n "$COLUMNS"; and set width -w (math "min(100, max(40, $COLUMNS - 4))")
        glow --pager $width "$src"
        return $status
    end

    if not command -q pandoc
        echo "mdview: pandoc not found -- brew install pandoc typst" >&2
        return 127
    end

    # --out's extension picks the format, unless an explicit flag overrides it
    set -l fmt html
    if set -q _flag_out
        switch (string lower (path extension "$_flag_out"))
            case .pdf
                set fmt pdf
            case .html .htm
                set fmt html
        end
    end
    set -q _flag_html; and set fmt html
    set -q _flag_pdf; and set fmt pdf

    set -l out $_flag_out
    if test -z "$out"
        # one stable scratch dir, not a fresh mktemp -d per render
        set -l dir /tmp/mdview-$USER
        mkdir -p $dir; or return 1
        set out $dir/(path change-extension '' (path basename "$src")).$fmt
    else if test -d "$out"
        echo "mdview: --out is a directory: $out" >&2
        return 2
    end

    if not test -d "$mdview_assets"
        echo "mdview: asset dir not found: $mdview_assets" >&2
        echo "mdview: set mdview_assets, or reinstall (./install.sh install fish home)" >&2
        return 1
    end

    set -l opts --defaults $mdview_assets/$fmt.yaml
    # pandoc resolves relative images against the working directory, not the
    # input file -- so `mdview sub/dir/doc.md` embeds nothing and still exits 0.
    # Prepending the doc's own directory fixes that; pandoc keeps the working
    # directory as a fallback. Deliberately not `path resolve`: that would break
    # symlinked docs whose images sit beside the symlink, not the target.
    set -a opts --resource-path (path dirname "$src")
    set -q _flag_toc; and set -a opts --toc --toc-depth=3

    # html.yaml resolves its stylesheet through this
    set -lx MDVIEW_ASSETS $mdview_assets
    pandoc $opts -o "$out" "$src"; or return 1

    if set -q _flag_no_open
        echo $out
    else if test $fmt = html
        __mdview_safari "$out"; or open "$out"
    else
        open "$out"
    end
end

function __mdview_safari --argument-names path \
    --description "Open a local file in a new, side-docked Safari window"
    set -l px 780
    set -q mdview_width; and set px $mdview_width
    set -l side left
    set -q mdview_side; and set side $mdview_side

    if not string match -qr '^[0-9]+$' -- "$px"; or test $px -lt 200
        echo "mdview: mdview_width must be a pixel width >= 200, got: $px" >&2
        return 1
    end
    if not contains -- "$side" left right
        echo "mdview: mdview_side must be 'left' or 'right', got: $side" >&2
        return 1
    end

    # url-escaping also neutralises " and \, so the path is safe to embed
    # in the AppleScript string literal
    set -l url "file://"(string escape --style=url "$path")
    osascript $mdview_assets/safari-window.applescript "$url" "$px" "$side"
end
