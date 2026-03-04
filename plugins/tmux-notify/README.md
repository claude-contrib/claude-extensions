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

## Configuration

Set options in `~/.tmux.conf` for persistence, or at runtime with `tmux set-option`:

| Option | Default | Values | Description |
|--------|---------|--------|-------------|
| `@claude-notify-bell` | `on` | `on` / `off` | Write `\a` to the pane TTY (visual/audible bell) |
| `@claude-notify-message` | `off` | `on` / `off` | Show contextual message when Claude's window is inactive |
| `@claude-notify-auto-focus` | `off` | `on` / `off` | Select Claude's pane within its window |

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

## How it works

The plugin hooks into two Claude Code events — `Stop` (Claude finishes responding) and `Notification` (Claude needs attention, e.g. a permission prompt) — and runs `tmux_notify.sh` in the context of the pane where Claude is running.

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

## Contributing

Issues and pull requests welcome at [claude-contrib/claude-extensions](https://github.com/claude-contrib/claude-extensions).

## License

MIT
