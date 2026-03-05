# tmux-notify

> Get notified in tmux when Claude Code finishes a task or needs your attention — per-pane, with no status bar conflicts.

## What it does

When you run Claude Code in a background tmux pane, you need a reliable signal when it's done. Status bar widgets break when you have multiple Claude instances because they share state across windows. `tmux-notify` works at the pane level using three independent mechanisms:

- **Bell** — writes `\a` directly to the pane's TTY so your terminal flashes/beeps regardless of which window is active
- **Display-message** — shows a contextual message in the tmux status area when Claude's window is out of focus
- **Auto-focus** — selects Claude's pane within its window when Claude completes or needs attention

Bell is on by default; the other two are opt-in. All three work independently.

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
| `@claude-notify-message` | `off` | `on` / `off` | Show contextual message when Claude's window is inactive |
| `@claude-notify-auto-focus` | `off` | `on` / `off` | Select Claude's pane within its window |

> **Note:** Option values are case-sensitive. Only the exact lowercase strings `on` and `off` are recognised. Values like `ON`, `true`, or `1` are treated as `off`.

**`~/.tmux.conf` example:**

```
set-option -g @claude-notify-bell on
set-option -g @claude-notify-message on
set-option -g @claude-notify-auto-focus off
```

**Runtime (takes effect immediately):**

```bash
tmux set-option -g @claude-notify-message on
tmux set-option -g @claude-notify-auto-focus off
```

Options set with `-g` are global (apply to all sessions). Omit `-g` to scope an option to the current session only. Global options are recommended to ensure the hook script always finds the configured values regardless of which session Claude is running in.

## How it works

The plugin hooks into two Claude Code events:

- **`Stop`** — fires on every event when Claude finishes responding (matcher: `*`)
- **`Notification`** — fires only for user-interaction events that require attention: `permission_prompt` and `elicitation_dialog`

> **Note:** Not all `Notification` event subtypes trigger this plugin. Only `permission_prompt` and `elicitation_dialog` are hooked, as these are the cases where you actually need to be alerted. Generic or informational notifications are intentionally excluded.

### Bell

Writes the ASCII bell character (`\a`) directly to `#{pane_tty}` — the TTY device of the pane where Claude is running. This triggers the terminal's bell action (visual flash, audible beep, or dock badge depending on your terminal settings) independently of which pane is currently focused.

### Display-message

Compares Claude's `#{window_id}` to the currently active window within the same tmux session. If they differ (i.e. you've switched away from Claude's window), it runs `tmux display-message` with a short, fixed message:

| Event | Message shown |
|-------|--------------|
| `Stop` | `Claude [window]: done` |
| `Notification` | `Claude [window]: waiting` |

Where `window` is the tmux window name of Claude's pane.

### Auto-focus

Selects Claude's pane within its window via `tmux select-pane -t $TMUX_PANE`. Fires on both Stop and Notification events. Uses a short delay (0.5s) to run after Claude Code finishes its terminal UI update. Only affects the current window — it does not switch windows.

## Active pane detection

The script compares `#{pane_id}` of the active pane to `$TMUX_PANE` (the pane where Claude is running). If they match — meaning Claude's pane is already focused — all notifications and auto-focus are skipped. This prevents bells and popups when you're already looking at Claude.

## Multiple Claude instances

Each pane that runs Claude has its own `$TMUX_PANE` environment variable set by tmux. The notification script uses `$TMUX_PANE` to target only its own pane, so two Claude instances running in separate panes each send their bell to their own TTY independently. No coordination needed.

## Troubleshooting

### Verify installation

Check that the tmux options are readable from any pane:

```bash
tmux show-option -g @claude-notify-bell
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

### Bell or message fires when Claude's pane is already focused

This should not happen — the script skips all notifications when the active pane is Claude's pane. If you see this, run with `DEBUG=1` and check the output of the `_is_active_pane` check.

## Contributing

Issues and pull requests welcome at [claude-contrib/claude-extensions](https://github.com/claude-contrib/claude-extensions).

## License

MIT
