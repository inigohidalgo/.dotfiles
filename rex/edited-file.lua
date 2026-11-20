-- open_edited_file (cmd+shift+e): open a file the focused pane's Claude Code
-- session edited, in a split beside it. See rex/README.md.

local HOME = os.getenv("HOME")
local TERMINAL = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"

-- This module's own directory, so its helper is found beside it wherever the repo
-- lives. (Rex reports the chunk source with or without Lua's usual "@" prefix.)
local HERE = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$")

-- Opens a file the focused pane's Claude Code session edited, in a split beside it.
-- `command` is word-split by sh, so "nvim -R" works; the file is appended as the
-- last argument. With several edited files, fzf picks one (most recent first).
rex.action{
  name  = "open_edited_file",
  title = "Open File Edited by Claude",
  description = "Pick a file the focused Claude session edited and open it with a command in a side pane",
  keywords = "claude edited transcript render",
  args  = { command = "string", direction = "string?", ratio = "number?", keep_open = "boolean?", ext = "string?" },
  run   = function(ctx, args)
    local proc, err = rex.block.call(TERMINAL, "process", { block_id = ctx.block_id })
    if proc == nil then error(err, 0) end
    local fg = proc.foreground
    if fg == nil or (fg.argv0 ~= "claude" and not (fg.invoked_path or ""):match("/claude$")) then
      error("the focused pane isn't running claude", 0)
    end

    local r, xerr = rex.exec(
      { HOME .. "/.local/bin/uv", "run", "--no-project", "python",
        HERE .. "/edited_files.py", tostring(fg.pid) },
      { timeout = 20 })
    if r == nil then error(xerr, 0) end
    if not r.ok then error(r.stderr, 0) end

    -- `ext` is a comma-separated list of extensions to keep, e.g. "md,markdown".
    local wanted = nil
    if args.ext then
      wanted = {}
      for e in args.ext:gmatch("[^,%s]+") do wanted[e:lower()] = true end
    end

    local files = {}
    for line in r.stdout:gmatch("[^\n]+") do
      local e = line:match("%.([^./]+)$")
      -- .env, .env.local, .env.production...: dotenv files, whatever their suffix.
      if line:match("/%.env$") or line:match("/%.env%.[^/]+$") then e = "env" end
      if wanted == nil or (e and wanted[e:lower()]) then files[#files + 1] = line end
    end
    if #files == 0 then
      error("this claude session hasn't edited any "
        .. (args.ext and (args.ext .. " ") or "") .. "files", 0)
    end

    local script = [[
cmd=$1; shift
if [ $# -eq 1 ]; then f=$1
else f=$(printf '%s\n' "$@" | fzf --prompt='edited> ') || exit 0
fi
exec $cmd "$f"
]]
    local argv = { "sh", "-c", script, "sh", args.command }
    for _, f in ipairs(files) do argv[#argv + 1] = f end

    local options = { command = argv, cwd = fg.cwd }
    if args.keep_open ~= false then options.exit = { on_completion = false } end

    local dir = args.direction or "right"
    local res, serr = rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = (dir == "right" or dir == "left") and "horizontal" or "vertical",
      side      = (dir == "right" or dir == "below") and "after" or "before",
      ratio     = args.ratio or 0.5,
      focus     = true,
      layout    = { block = { flavor = SHELL, label = "edited", options = options } },
    }
    if res == nil then error(serr, 0) end
    return { block_id = res.block_ids[1], files = #files }
  end,
}

-- Extensions with a tuned nvim setup (render-markdown, tree-sitter parsers).
local VIEWABLE = table.concat({
  "md,markdown",
  "txt",
  "env",
  "toml,yaml,yml,json,jsonc,ini,cfg,conf",
  "py,pyi",
  "ts,tsx,mts,cts",
  "swift",
  "cpp,cc,cxx,hpp,hh,h",
  "rs",
}, ",")

rex.bind("cmd+shift+e", "open_edited_file", { command = "nvim", ext = VIEWABLE, keep_open = false })
