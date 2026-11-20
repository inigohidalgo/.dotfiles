# `rex/`

Rex config as Lua modules. Rex reads one file, `~/.config/rex/init.lua`;
install appends a marker block of `dofile(...)` lines to it, one per module in
the profile's list (`REX_HOME` in `install.sh`), pointing at the live files
here.

```bash
./install.sh install rex home      # appends the block to ~/.config/rex/init.lua
./install.sh uninstall rex         # removes exactly that block
```

Rex loads `init.lua` at startup, not on change: after installing or editing a
module, run **Reload Config** from the command palette (or
`rex -C <client> do client.config.reload`), then check `rex keymap` lists the
bindings. `rex config check` loads the file and reports errors without
applying it.

| Module | Binds | What it does |
|---|---|---|
| `edited-file.lua` | `cmd+shift+e` | Open a file the focused pane's Claude Code session edited, in a split beside it (fzf when there are several). Its helper, `edited_files.py`, maps the claude pid to its session transcript(s) and lists edited files, most recent first; it's found beside the module, so nothing depends on `~/.config/rex`. Needs `uv`, `fzf`, `nvim`. |
| `rssh-split.lua` | `cmd+d`, `shift+cmd+d` | On a pane whose shell is on another host (per its OSC 7 cwd), split into a new pane with its own persistent shell on that host, in the same directory, via `rssh` (`../rssh/README.md`). On a local pane, Rex's own split, untouched. |

## Writing a module

Each module is a standalone chunk: declare the locals it needs (`HOME`,
creator names like `com.superlogical.terminal`) itself — modules share no
scope. A module that ships assets finds them relative to itself:

```lua
local HERE = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$")
```

(Rex reports the chunk source with or without Lua's usual `@` prefix.) To try
an action before installing it: `rex do path/to/module.lua --action NAME k=v`.

## Blocks from other repos

The block is `-- <<< dotfiles >>>` … `-- <<< /dotfiles >>>` (Lua comments; `#`
isn't one). Other repos that ship Rex modules — workbench/clauder plans deck
actions — add their **own** namespaced block, `-- <<< NAME >>>`, the way
clauder already does in the shell rc files. Each installer touches only its own
block, so `init.lua` stays shared without anyone owning it. Agree on key
bindings across blocks: the later `rex.bind` of the same key wins.
