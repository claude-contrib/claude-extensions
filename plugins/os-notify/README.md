# os-notify

> Native desktop notifications for Claude Code on macOS and Linux — get notified when Claude needs your input, even when you've switched to another app.

`os-notify` is the cross-platform successor to [`macos-notify`](../macos-notify/README.md). It sends a notification on the `Notification` event (`permission_prompt`, `elicitation_dialog`) with the project name (`owner/repo` or directory basename) as the title and "Claude needs your input — \<branch\>" as the body. For task-completion alerts use [`tmux-notify`](../tmux-notify/README.md).

## Platform support

| Feature | macOS | Linux |
|---------|-------|-------|
| Notification | `terminal-notifier`, falls back to `osascript` | `notify-send` (libnotify) |
| Sound | yes | only if your notification daemon honors the `sound-name` hint |
| Suppress when terminal is focused | yes | not yet — always notifies |
| Click-to-focus (incl. tmux window) | yes, with `terminal-notifier` | not yet |

Other operating systems are a silent no-op.

## Requirements

- **macOS:** [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) is recommended for click-to-focus (`brew install terminal-notifier`). Without it, plain `osascript` notifications are shown with no click action.
- **Linux:** `notify-send` — `apt install libnotify-bin`, `dnf install libnotify`, or `pacman -S libnotify`. A notification daemon must be running (any desktop environment provides one).

## Installation

```
/plugin install os-notify@claude-extensions
```

## Configuration

Options are tmux options, as in `macos-notify`:

| Option | Default | Description |
|--------|---------|-------------|
| `@claude-notify-terminal` | `Ghostty` | macOS only. Application name used for focus detection and click-to-focus (`Terminal`, `iTerm2`, `Alacritty`, `WezTerm`, `kitty`, `Ghostty`). |
| `@claude-notify-sound` | `on` | Play a sound with each notification |

```tmux
set -g @claude-notify-terminal Ghostty
set -g @claude-notify-sound on
```

## macOS permissions

1. Allow notifications: **System Settings → Notifications → terminal-notifier → Allow Notifications**.
2. For click-to-focus, set the style to **Alerts** (Banners don't fire the click action).
3. To slide to the terminal's Space on click, enable **Desktop & Dock → "When switching to an application, switch to a Space with open windows for the application"**.

## Migrating from macos-notify

Uninstall `macos-notify` and install `os-notify`; the tmux options are unchanged. Don't run both, or you'll get duplicate notifications.

## Troubleshooting

- **No notification on Linux:** run `notify-send test` in your terminal. If that shows nothing, the problem is your notification daemon, not the plugin.
- **No notification on macOS:** run `terminal-notifier -message test`, and check the permissions above.
- Set `DEBUG=1` in the hook's environment for a shell trace.

## Layout

```
scripts/os-notify.sh      shared logic: event handling, project/branch/tmux helpers
scripts/backends/macos.sh   _os_send, _os_is_terminal_focused for macOS
scripts/backends/linux.sh   same interface for Linux
```

A new backend only has to define `_os_check_dependencies`, `_os_is_terminal_focused` and `_os_send`.

## License

MIT
