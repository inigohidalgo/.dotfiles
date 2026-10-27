# `karabiner/`

Karabiner-Elements config. `config/` **is** the live config directory:
`./install.sh install karabiner home` makes `~/.config/karabiner` a symlink to
it — the one install in this repo that's a symlink rather than a marker block
(why: the header of the karabiner section in `install.sh`).

```
config/
  karabiner.json        the whole config: profiles, rules, devices, fn keys
  assets/               Karabiner's importable-rule library (created by Karabiner)
  automatic_backups/    written by Karabiner on every change — gitignored
```

## Editing

Karabiner watches `config/` and reloads within about a second of
`karabiner.json` changing. So there's no install step after an edit, whichever
way it's made:

- **By hand / Claude Code** — edit `config/karabiner.json` directly (`jq` is
  fine for surgical changes). Format with Karabiner's own formatter afterwards
  so GUI saves don't produce whitespace-only diffs:
  `"$KARABINER_CLI" --format-json karabiner/config/karabiner.json`
- **Settings window** — writes the same file, so GUI changes show up in
  `git diff` like any other edit.

What the file *can't* carry: the macOS permission grants (Input Monitoring for
Karabiner-Core-Service, approving the DriverKit extension). Those are one-time,
per machine, by hand.

### Tools

`KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"`

| Command | Use |
| --- | --- |
| `--list-connected-devices` | vendor/product IDs for `devices[]` and `device_if` conditions |
| `--format-json <files>` | Karabiner's canonical formatting |
| `--lint-complex-modifications <files>` | validates *rule files* (the `assets/` shape: `{title, rules}`), not `karabiner.json` |
| `--select-profile <name>` | switch profile from a script |

Did a change take? `/var/log/karabiner/core_service.log` logs config loads,
errors and which devices are grabbed (`... hid device events monitor is started
(grabbed)`). Karabiner-EventViewer shows what a key or button actually emits.

## Rules

### MX Master 3 thumb button → Right Control (Wispr Flow push-to-talk)

Hold the thumb (gesture) button → Right Control held for exactly as long. Wispr
Flow binds Right Control as push-to-talk, and its built-in double-tap gives
hands-free.

- **What the button sends natively** (measured, no Logitech software running):
  `left_command` down + a ~5 ms `tab` tap on press, `left_command` up on
  release. The press/release of `left_command` is the signal, so the rule maps
  `left_command` → `right_control` and swallows `tab` (else: app switcher, or
  Ctrl+Tab), both only for this device (`device_if` vendor 1133 / product 45091).
- **Why Right Control**: Wispr requires a modifier-type key; MacBook keyboards
  have no physical Right Control, so nothing typed collides with it, and a
  Karabiner-sent Control is reliable (a virtual `fn` reportedly isn't).
- **`devices[]` entry with `"ignore": false`**: the mouse presents as keyboard
  *and* pointing device, and Karabiner leaves pointing devices alone by default.
  Side effect: Karabiner grabs the whole mouse and re-emits all of it through
  its virtual devices — normal, but nothing else can then read the mouse's raw
  HID.
- **Requires Logi Options+ to be gone**, not just quit. Its background agent
  (`com.logi.cp-dev-mgr`, from `/Library/LaunchAgents/com.logi.optionsplus.plist`)
  tells the mouse to divert buttons to it over Logitech's HID++ channel, so
  they never reach HID at all — not for Karabiner, not for Wispr. `launchctl
  bootout` only stops it until next login; uninstall Options+ with its own
  uninstaller.
