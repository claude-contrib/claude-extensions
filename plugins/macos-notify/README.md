# macos-notify

> Native macOS Notification Center alerts for Claude Code — get notified when Claude finishes a task or needs your input, even when you've switched to another app.

## What it does

`macos-notify` sends macOS Notification Center popups when Claude Code:
- **Completes a task** (`Stop` event) — "Task complete — \<branch\>"
- **Needs your attention** (`Notification` event) — "Needs your input — \<branch\>"

Notifications show the project name (`owner/repo` or directory basename) as the title.

**Click-to-focus** — clicking the notification brings your terminal app to the front and, when running inside tmux, switches to the correct session window.

It is complementary to `tmux-notify` (which handles in-terminal bells and status bar messages). Install both to get notifications at every level — inside your terminal and in the macOS notification layer.

## Requirements

- macOS (no-op on Linux/Windows)
- [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) for click-to-focus support:

  ```bash
  brew install terminal-notifier
  ```

## Installation

```
/plugin install macos-notify@claude-extensions
```

## macOS permissions

### 1. Allow notifications

The first time a notification fires, macOS will ask whether to allow notifications from `terminal-notifier`. Grant permission in:

**System Settings → Notifications → terminal-notifier → Allow Notifications**

### 2. Set notification style to Alerts (required for click-to-focus)

By default macOS uses **Banners** (transient). Clicking the "Show" button on a Banner does **not** trigger the focus action. Change the style to **Alerts** (persistent) so clicking the notification fires the focus command:

**System Settings → Notifications → terminal-notifier → Alerts**

Without this, notifications still appear and sound plays — but clicking won't focus your terminal or navigate your tmux window.

## Configuration

Options are set via tmux session options:

| Option | Default | Description |
|--------|---------|-------------|
| `@claude-notify-term-program` | `ghostty` | Terminal app identifier for click-to-focus. Required when running inside tmux because `$TERM_PROGRAM` reports `tmux` rather than the outer terminal. |
| `@claude-notify-sound` | `on` | Play a sound with each notification (`Glass` on Stop, `Ping` on Notification) |

Set options globally in your `~/.tmux.conf`:

```tmux
set -g @claude-notify-term-program ghostty
set -g @claude-notify-sound on
```

Or at runtime:

```bash
tmux set-option -g @claude-notify-term-program ghostty
tmux set-option -g @claude-notify-sound off
```

## Supported terminals

| Terminal | `@claude-notify-term-program` value |
|----------|-------------------------------------|
| Terminal.app | `Apple_Terminal` |
| iTerm2 | `iTerm.app` |
| Alacritty | `alacritty` |
| WezTerm | `WezTerm` |
| kitty | `kitty` |
| Ghostty | `ghostty` (default) |

## Works alongside tmux-notify

`macos-notify` and `tmux-notify` are independent and complementary:

- `tmux-notify` — in-terminal bell, status bar message, auto-focus within tmux
- `macos-notify` — system-level popup visible from any app, click-to-focus from outside

Install both for full coverage:

```
/plugin install tmux-notify@claude-extensions
/plugin install macos-notify@claude-extensions
```

## Troubleshooting

**No notification appears**
- Check System Settings → Notifications → terminal-notifier → Allow Notifications is on
- Run `terminal-notifier -message test` from your terminal to verify it works

**Notification appears but "Show" click does nothing**
- Change notification style to **Alerts** in System Settings → Notifications → terminal-notifier

**Click-to-focus opens terminal but wrong tmux window**
- Verify `@claude-notify-term-program` matches your terminal app (see table above)
- The plugin captures the tmux client TTY at hook-fire time; if your layout changes between notification and click it may navigate to the original window

**Ghostty notifications require permission from Ghostty, not terminal-notifier**
- If you were previously running Claude Code from Ghostty directly (not via terminal-notifier), grant notification access to Ghostty as well

## Contributing

Issues and pull requests welcome at [claude-contrib/claude-extensions](https://github.com/claude-contrib/claude-extensions).

## License

MIT
