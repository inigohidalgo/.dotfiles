-- rssh_split (cmd+d, shift+cmd+d): a split that follows rssh. See rex/README.md and
-- rssh/README.md.
--
-- If the pane's shell last reported a cwd on another host (file://HOST/PATH, from
-- OSC 7), the new pane is a local shell that runs `rssh HOST 'PATH'`: its own
-- persistent shell on HOST, in the same directory. The new pane is deliberately a
-- *local* shell running rssh, not rssh itself: a dropped connection then leaves the
-- pane (and so its block id) alive, which is what keeps its remote shell from being
-- released. Otherwise this is Rex's own split, untouched.

local TERMINAL = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"

local function remote_cwd(block_id)
  local r = rex.block.call(TERMINAL, "pwd", { block_id = block_id })
  local host, path = ((r and r.pwd) or ""):match("^file://([^/]*)(/.*)$")
  if not path then return nil end
  host = host:lower():gsub("%.local$", "")
  local me = rex.exec({ "hostname", "-s" })
  if host == "" or host == "localhost" or (me and me.ok and host == me.stdout:gsub("%s+$", ""):lower()) then
    return nil
  end
  return host, (path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

rex.action{
  name  = "rssh_split",
  title = "Split Pane (follow rssh host)",
  args  = { direction = "string" },
  run   = function(ctx, args)
    local host, path = remote_cwd(ctx.block_id)
    if not host then
      rex.client.queue(args.direction == "below" and "pane.split.down" or "pane.split.right")
      return
    end
    local quoted = "'" .. path:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"   -- fish quoting
    local res, err = rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = args.direction == "below" and "vertical" or "horizontal",
      side      = "after",
      focus     = true,
      layout    = { block = { flavor = SHELL, options = { initial_input = "rssh " .. host .. " " .. quoted .. "\n" } } },
    }
    if res == nil then error(err, 0) end
  end,
}

rex.bind("cmd+d",       "rssh_split", { direction = "right" })
rex.bind("shift+cmd+d", "rssh_split", { direction = "below" })
