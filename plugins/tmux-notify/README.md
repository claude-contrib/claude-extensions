# tmux-notify

> Get notified in tmux when Claude Code finishes a task or needs your attention — per-pane, with no status bar conflicts.

## What it does

When you run Claude Code in a background tmux pane, you need a reliable signal when it's done. Status bar widgets break when you have multiple Claude instances because they share state across windows. `tmux-notify` works at the pane level using four independent mechanisms:

- **Bell** — writes `\a` directly to the pane's TTY so your terminal flashes/beeps regardless of which window is active
- **Window rename** — renames the window to `claude - <tool>` (e.g. `claude - Bash`) while Claude is working, then restores the original name when it finishes
- **Display-message** — shows a contextual message in the tmux status area when Claude's window is out of focus
- **Auto-focus** — selects Claude's pane within its window when Claude completes or needs attention

Bell and window rename are on by default; display-message and auto-focus are opt-in. All four work independently.

## Installation

```
/plugin install tmux-notify@claude-extensions
```

## Dependencies

- **tmux** — required
- **bash** — required (used by the hook script)
- **jq** — optional but recommended. Without `jq`, JSON parsing falls back to `sed`, which silently fails on values containing escaped quotes, newlines, or special characters. Install `jq` for reliable operation.

## Configuration

Set options in `~/.tmux.conf` for persistence, or at runtime with `tmux set-option`:

| Option | Default | Values | Description |
|--------|---------|--------|-------------|
| `@claude-notify-bell` | `on` | `on` / `off` | Write `\a` to the pane TTY (visual/audible bell) |
| `@claude-notify-auto-rename` | `on` | `on` / `off` | Rename window to `claude - <tool>` during tool use, restore on Stop |
| `@claude-notify-message` | `off` | `on` / `off` | Show contextual message when Claude's window is inactive |
| `@claude-notify-auto-focus` | `off` | `on` / `off` | Select Claude's pane within its window |

> **Note:** Option values are case-sensitive. Only the exact lowercase strings `on` and `off` are recognised. Values like `ON`, `true`, or `1` are treated as `off`.

**`~/.tmux.conf` example:**

```
set-option -g @claude-notify-bell on
set-option -g @claude-notify-auto-rename on
set-option -g @claude-notify-message on
set-option -g @claude-notify-auto-focus off
```

**Runtime (takes effect immediately):**

```bash
tmux set-option -g @claude-notify-auto-rename off
tmux set-option -g @claude-notify-message on
tmux set-option -g @claude-notify-auto-focus off
```

Options set with `-g` are global (apply to all sessions). Omit `-g` to scope an option to the current session only. Global options are recommended to ensure the hook script always finds the configured values regardless of which session Claude is running in.

## How it works

The plugin hooks into three Claude Code events:

- **`PreToolUse`** — fires before Claude uses any tool (matcher: `*`); used to trigger window rename
- **`Stop`** — fires when Claude finishes responding (matcher: `*`)
- **`Notification`** — fires only for user-interaction events that require attention: `permission_prompt` and `elicitation_dialog`

> **Note:** Not all `Notification` event subtypes trigger this plugin. Only `permission_prompt` and `elicitation_dialog` are hooked, as these are the cases where you actually need to be alerted. Generic or informational notifications are intentionally excluded.

### Bell

Writes the ASCII bell character (`\a`) directly to `#{pane_tty}` — the TTY device of the pane where Claude is running. This triggers the terminal's bell action (visual flash, audible beep, or dock badge depending on your terminal settings) independently of which pane is currently focused.

### Window rename

On every `PreToolUse` event the window is renamed to `claude - <tool>` (e.g. `claude - Bash`, `claude - Read`). When Claude finishes (`Stop` event) the original name is restored.

The original name is captured on the first tool use of each session and saved to a pane-scoped tmux option. Names that look like they were set by Claude Code itself — version strings like `1.2.3` or names already starting with `claude` — are not saved, since they are not meaningful user names.

The saved name is keyed per pane (`@claude-saved-window-name-<pane_id>`), so multiple Claude instances in different panes each track their own original name independently.

### Display-message

Compares Claude's `#{window_id}` to the currently active window within the same tmux session. If they differ (i.e. you've switched away from Claude's window), it runs `tmux display-message` with a short, fixed message:

| Event | Message shown |
|-------|--------------|
| `Stop` | `Claude [window]: done` |
| `Notification` | `Claude [window]: waiting` |

Where `window` is the tmux window name of Claude's pane at the time the event fires.

### Auto-focus

Selects Claude's pane within its window via `tmux select-pane -t $TMUX_PANE`. Fires on both Stop and Notification events. Uses a short delay (0.25s) to run after Claude Code finishes its terminal UI update. Only affects the current window — it does not switch windows.

## Active pane detection

The script compares `#{pane_id}` of the active pane to `$TMUX_PANE` (the pane where Claude is running). If they match — meaning Claude's pane is already focused — all notifications and auto-focus are skipped. This prevents bells and popups when you're already looking at Claude.

Window rename is not affected by active pane detection — it fires unconditionally so the title always reflects what Claude is doing.

## Multiple Claude instances

Each pane that runs Claude has its own `$TMUX_PANE` environment variable set by tmux. The notification script uses `$TMUX_PANE` to target only its own pane, so two Claude instances running in separate panes each send their bell to their own TTY independently. No coordination needed.

## Troubleshooting

### Verify installation

Check that the tmux options are readable from any pane:

```bash
tmux show-option -g @claude-notify-bell
tmux show-option -g @claude-notify-auto-rename
tmux show-option -g @claude-notify-message
tmux show-option -g @claude-notify-auto-focus
```

If a line is missing, the option hasn't been set and the plugin will use its built-in default.

### Enable debug mode

Run the hook script manually with `DEBUG=1` to see detailed execution output:

```bash
echo '{"hook_event_name":"Stop"}' | DEBUG=1 bash /path/to/tmux-notify.sh
```

With `DEBUG=1`:
- All executed commands are printed (`set -x`)
- A warning is printed to stderr if `jq` is not found and the sed fallback is used
- A warning is printed to stderr if the bell write to the pane TTY fails

### Notifications don't fire

1. Confirm you are running Claude inside tmux (`echo $TMUX` should be non-empty)
2. Confirm `$TMUX_PANE` is set (`echo $TMUX_PANE` should print something like `%3`)
3. Check the hook is registered: look for `tmux-notify.sh` in `~/.claude/hooks.json`
4. Run the script manually with `DEBUG=1` (see above)

### Bell fires but display-message does not

`@claude-notify-message` defaults to `off`. Enable it:

```bash
tmux set-option -g @claude-notify-message on
```

Also note that display-message only fires when you are in the same tmux session as Claude but have a different window active. It is intentionally suppressed when you are already in Claude's window.

### Window name is not restored after Claude exits

The original name is only saved if it is not a Claude-set name. If the window was already named something like `1.2.3` (Claude's version string) when the first tool use fired, there is nothing to restore. Rename the window to a meaningful name before starting Claude, or disable `automatic-rename` in tmux so Claude Code cannot overwrite it before the first tool use.

### Bell or message fires when Claude's pane is already focused

This should not happen — the script skips all notifications when the active pane is Claude's pane. If you see this, run with `DEBUG=1` and check the output of the `_tmux_is_active_pane` check.

## Contributing

Issues and pull requests welcome at [claude-contrib/claude-extensions](https://github.com/claude-contrib/claude-extensions).

## License

MIT
