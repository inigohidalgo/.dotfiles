-- fork_claude (shift+cmd+f): fork the focused pane's Claude Code session into a
-- split beside it. See rex/README.md.
--
-- All the work is clauder's (`clauder rex fork`, in workbench): it finds the Claude
-- in the block, works out the fork, and makes the split. This only hands it the
-- block. On success the new pane is the feedback; on failure clauder's stderr is
-- the error, its first line written to fit the collapsed "Action failed" pill.
--
-- rex.exec runs in the server's environment, whose PATH is bare, so clauder is
-- named by its installed path. It reaches this server through $REX_SERVER, which
-- the server's environment has.

local CLAUDER = os.getenv("HOME") .. "/.local/bin/clauder"

rex.action{
  name  = "fork_claude",
  title = "Fork Claude",
  description = "Fork the focused pane's Claude Code session into a split beside it",
  keywords = "claude fork session resume split",
  args  = { split = "string?" },
  run   = function(ctx, args)
    if not ctx.block_id then error("no focused pane", 0) end
    local r, err = rex.exec(
      { CLAUDER, "rex", "fork", "--block", ctx.block_id, "--split", args.split or "right" },
      { timeout = 15 })
    if r == nil then error(err, 0) end
    if not r.ok then error((r.stderr:gsub("%s+$", "")), 0) end
    return { block_id = (r.stdout:gsub("%s+$", "")) }
  end,
}

rex.bind("shift+cmd+f", "fork_claude")
