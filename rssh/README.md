# `rssh/`

One persistent shell on a remote host per Rex pane. Rex manages the panes,
tabs and sessions; each pane that runs `rssh HOST` holds one shell on `HOST`
that outlives the connection. It replaces "ssh into one remote tmux and manage
everything inside it" with "Rex manages everything, the remote only keeps
shells alive".

Built for `inigo-mbp20`, which can't run a Rex server of its own: Rex's macOS
server is Apple Silicon + macOS 15 only, and `rex server install ssh://` only
supports Linux. Where the remote *can* run Rex, use a real Rex host instead.

| File | Runs on | Role |
|---|---|---|
| `rssh` | the Rex machine | `rssh HOST [DIR]` attaches this pane; `rssh gc [-n] HOST` releases closed panes' shells |
| `rssh-host` | the remote host | wraps [`zmx`](https://zmx.sh): `attach`, `list`, `kill` |

The split that follows a remote pane (`cmd+d` on an mbp20 pane opens another
mbp20 pane in the same directory) is a Rex module: `rex/rssh-split.lua`.

## Install

```bash
./install.sh install rssh home     # both machines: links rssh + rssh-host into ~/.local/bin
```

Both commands go on every machine; which one runs depends on the machine's
role. `rssh` reaches the remote half at the fixed path `~/.local/bin/rssh-host`,
so it never depends on where a host keeps its clone of this repo.

Needs, on the Rex machine: `rex`, `jq`, and an `~/.ssh/config` entry for the
host name the remote shell reports (the split uses it — for mbp20 that's
`Host inigo-mbp20`). On the remote: `zmx` (on `PATH`, or `~/.local/bin`), and
a shell that reports its directory with OSC 7 (fish does by default; the split
depends on it).

**zmx on mbp20 is a hand-built binary**, not managed here: v1.0.1 in
`~/.local/bin/zmx`. zmx's prebuilt macOS binaries require macOS 15 and mbp20
is on 14, so it was cross-compiled from Apple Silicon with the minimum pinned:

```bash
git clone https://github.com/neurosnap/zmx && cd zmx && git checkout v1.0.1
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-macos.14.0   # Zig 0.17; -> zig-out/bin/zmx
```

To update, build on mbp20 itself instead (Zig 0.17 isn't installed there yet).
Without the `.14.0`, Zig targets its default macOS minimum and the binary
won't start on 14.

## Use

```bash
rssh mbp20                  # attach this pane to its shell on mbp20 (create in ~)
rssh mbp20 ~/homelab        # ...creating it in ~/homelab if it doesn't exist yet
rssh gc -n mbp20            # what would be released, without releasing it
ssh mbp20 '~/.local/bin/rssh-host v1 list'   # sessions on the host, with their processes
```

**`rssh HOST [DIR]` is a stable interface.** Other tools may call it to open a
remote shell in a pane (workbench's `deck` intends to, rather than reimplement
it) — change its arguments only alongside them.

## Design

**Session ID = this Rex server + this pane.** `<first 8 chars of rex whoami
host_id>-<block UUID>`. Block IDs survive sleep, dropped connections and Rex
restarts (a restored pane is a fresh local shell that still has `$REX_BLOCK`),
and are never reused. So reattaching after any of those is just `rssh mbp20`
again *in the same pane* — there is deliberately no auto-reconnect and no
auto-resume.

**Release rule: a remote shell lives exactly as long as its pane.**
`rssh gc` lists every block on the local Rex server and kills that host's
sessions — only ones carrying this server's prefix — whose block is gone. It
runs in the background on every attach, so release is *lazy*: a closed pane's
shell lingers until the next `rssh` to that host, or a manual `rssh gc`. It
**fails safe**: if it can't reach Rex, or gets an empty block list, it kills
nothing. (Rex has a `block_closed` event, but only a long-lived `rex do` daemon
can receive it — not worth a daemon.)

**Kill = everything that ran in the pane.** `rssh-host kill` snapshots every
process on the session's tty, HUPs them, and KILLs survivors after 3s — so
`nohup`ed and `disown`ed jobs go too. Only something that deliberately left
the terminal (`setsid`, a self-daemonizing server) escapes.

**Why zmx, not dtach.** rssh started on dtach, and dtach deadlocks under
Claude Code. Its master writes your input into the pty with a blocking
`write()` in a single-threaded loop. Claude's fullscreen mode turns on
any-motion mouse tracking (mode 1003), so moving the mouse floods input; if
Claude isn't reading input at that moment (say, mid-redraw), the master blocks
and stops relaying output, and the pane freezes for good. abduco has the same
blocking write. zmx doesn't: it queues input and writes it without blocking.
Measured on mbp20 with a program that never reads input, a 47 KB flood of mouse
reports froze dtach for good while zmx kept up with ten times that. zmx also
restores the screen and scrollback on reattach, where dtach cleared it.

**State.** Everything lives under `~/.cache/rssh`: `ID.meta` (the wrapper's
pid and tty) and `zmx/` (zmx's sockets and per-session logs, pinned with
`ZMX_DIR` because zmx's default follows `$TMPDIR`). zmx never deletes a
session's log, so attach removes the logs of ended sessions. zmx's `ctrl+\`
detach key is off (`ZMX_NO_DETACH_KEY`), so leaving a pane's shell is only
ever `exit`, a dropped connection, or closing the pane.

**Protocol version.** Every call carries `v1`; `rssh-host` refuses any other
with "update the dotfiles repo on both machines". A mismatch means one
machine's clone is behind — `git pull` it. Bump `PROTO` in both scripts
together when the call format changes.

### What survives what

| Event | The remote shell | Getting back to it |
|---|---|---|
| Rex machine sleeps, network drops | survives | the pane drops to its local prompt; `rssh HOST` again (screen and scrollback come back) |
| Rex restarts, Rex machine reboots | survives | the restored pane is local; `rssh HOST` again in it |
| `exit` in the remote shell | ends; files removed | the pane is back at its local prompt |
| Pane closed in Rex | orphaned → released by the next `gc` | — |
| **Remote host reboots or crashes** | **lost** (zmx lives in memory) | the next attach prints `[rssh] the shell this pane had on … is gone`, then starts a new one |

## Sharp edges

- **Input past 256 KB is dropped.** zmx caps the input it's holding for a
  program that isn't reading at 256 KB, then drops new input (logged as `pty
  input dropped` in `~/.cache/rssh/zmx/logs/ID.log`). In practice that's
  queued-up mouse motion; a stuck program loses keystrokes instead of freezing
  the pane.
- **Old dtach sessions are ended on attach.** A pane whose shell still runs
  under dtach (from before zmx) can't be reattached; its next `rssh` ends that
  shell, prints `[rssh] ended this pane's old dtach shell`, and starts a zmx
  one. Delete this path once no dtach sessions remain.
- **macOS process tooling:** `pgrep -t`/`pkill -t` match nothing (use `ps -t` +
  `kill`); `pgrep` hides its own ancestors unless `-a`; a `nohup`ed process
  shows tty `??` once its session leader dies — snapshot before signalling.

## Not yet

- Claude sessions running in rssh panes don't feed workbench's activity
  ordering (`deck rex sort`): Claude runs on the remote, where `$REX_BLOCK`
  and the Rex socket mean nothing. Workbench's side would add a second
  activity source; nothing here needs to change for it.
