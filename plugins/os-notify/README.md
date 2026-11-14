# os-notify

> Native desktop notifications for Claude Code on macOS and Linux — get notified when Claude needs your input, even when you've switched to another app.

`os-notify` replaces the former `macos-notify` plugin and adds Linux support. It sends a notification on the `Notification` event (`permission_prompt`, `elicitation_dialog`) with the project name (`owner/repo` or directory basename) as the title and "Claude needs your input — \<branch\>" as the body. For task-completion alerts use [`tmux-notify`](../tmux-notify/README.md).

## Platform support

| Feature | macOS | Linux (X11) | Linux (Wayland) |
|---------|-------|-------------|-----------------|
| Notification | `terminal-notifier`, falls back to `osascript` | `notify-send` (libnotify) | `notify-send` |
| Sound | yes | if your notification daemon honors the `sound-name` hint | same |
| Suppress when terminal is focused | yes | yes (`xprop`) | not yet — always notifies |
| Click-to-focus (incl. tmux window) | yes, with `terminal-notifier` | yes, needs `notify-send` ≥ 0.8 and a daemon with action support | not yet |

Other operating systems are a silent no-op. Wayland has no portable way to read the focused window or take focus, so those sessions get plain notifications.

## Requirements

- **macOS:** [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) is recommended for click-to-focus (`brew install terminal-notifier`). Without it, plain `osascript` notifications are shown with no click action.
- **Linux:** `notify-send` — `apt install libnotify-bin`, `dnf install libnotify`, or `pacman -S libnotify`. A notification daemon must be running (any desktop environment provides one).
- **Linux, X11 (optional):** `xprop` (package `xorg-xprop` / `x11-utils`) for focus detection. To raise the window on click, one of `i3-msg` (i3), `wmctrl` or `xdotool`.

## Installation

```
/plugin install os-notify@claude-extensions
```

## Configuration

Options are tmux options, as in `macos-notify`:

| Option | Default | Description |
|--------|---------|-------------|
| `@claude-notify-terminal` | `Ghostty` | The terminal used for focus detection and click-to-focus. macOS: application name (`Terminal`, `iTerm2`, `Alacritty`, `WezTerm`, `kitty`, `Ghostty`). Linux/X11: window class or instance from `xprop WM_CLASS`, case-insensitive; the last dotted part is enough (`ghostty`, `wezterm`, `kitty`, `Alacritty`). |
| `@claude-notify-sound` | `on` | Play a sound with each notification |

```tmux
set -g @claude-notify-terminal Ghostty
set -g @claude-notify-sound on
```

Different terminal per OS? Set it conditionally:

```tmux
if-shell 'test "$(uname)" = Darwin' \
  'set -g @claude-notify-terminal Ghostty' \
  'set -g @claude-notify-terminal wezterm'
```

## macOS permissions

1. Allow notifications: **System Settings → Notifications → terminal-notifier → Allow Notifications**.
2. For click-to-focus, set the style to **Alerts** (Banners don't fire the click action).
3. To slide to the terminal's Space on click, enable **Desktop & Dock → "When switching to an application, switch to a Space with open windows for the application"**.

## Linux window matching

On X11 the terminal window is found with `$WINDOWID` when your terminal sets it, otherwise by matching `@claude-notify-terminal` against the window's `WM_CLASS`. To see yours, run `xprop WM_CLASS` and click the terminal. If you have several windows of the same terminal and `$WINDOWID` is not set, the first one matches.

## Migrating from macos-notify

`macos-notify` has been removed. Uninstall it and install `os-notify`; the tmux options are unchanged.

## Troubleshooting

- **No notification on Linux:** run `notify-send test` in your terminal. If that shows nothing, the problem is your notification daemon, not the plugin.
- **No notification on macOS:** run `terminal-notifier -message test`, and check the permissions above.
- **Linux: notifications show while the terminal is focused, or click does nothing:** check `xprop WM_CLASS` against `@claude-notify-terminal`, and that `$DISPLAY` is set and the session is not Wayland.
- Set `DEBUG=1` in the hook's environment for a shell trace.

## Layout

```
scripts/os-notify.sh      shared logic: event handling, project/branch/tmux helpers
scripts/backends/macos.sh   _os_send, _os_is_terminal_focused for macOS
scripts/backends/linux.sh   same interface for Linux (notify-send, X11 focus detection and activation)
```

A new backend only has to define `_os_check_dependencies`, `_os_is_terminal_focused` and `_os_send`.

## License

MIT
