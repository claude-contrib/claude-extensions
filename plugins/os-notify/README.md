# os-notify

> Native desktop notifications for Claude Code on macOS and Linux — get notified when Claude needs your input, even when you've switched to another app.

`os-notify` replaces the former `macos-notify` plugin and adds Linux support. It sends a notification on the `Notification` event (`permission_prompt`, `elicitation_dialog`) and when Claude asks a question with `AskUserQuestion` ("Claude has a question"), with the project name (`owner/repo` or directory basename) as the title and "Claude needs your input — \<branch\>" as the body. When you are away, permission requests also get [Allow and Deny buttons](#allow-and-deny-from-the-notification). For task-completion alerts use [`tmux-notify`](../tmux-notify/README.md).

## Platform support

| Feature | macOS | Linux (X11) | Linux (Wayland) |
|---------|-------|-------------|-----------------|
| Notification | `terminal-notifier`, falls back to `osascript` | `notify-send` (libnotify) | `notify-send` |
| Sound | yes | if your notification daemon honors the `sound-name` hint | same |
| Suppress when terminal is focused | yes | yes (`xprop`) | not yet — always notifies |
| Click-to-focus (incl. tmux window) | yes, with `terminal-notifier` | yes, needs `notify-send` ≥ 0.8 and a daemon with action support | not yet |
| Allow / Deny buttons | yes, with `terminal-notifier` | yes, needs `notify-send` ≥ 0.8, a daemon with action support and `timeout` | same |

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

Nothing needs configuring: the terminal window is detected from the process tree (under tmux, from the tmux client attached to Claude's session). Options are tmux options, as in `macos-notify`:

| Option | Default | Description |
|--------|---------|-------------|
| `@claude-notify-terminal` | unset (auto-detect) | Optional override for the terminal used in focus detection and click-to-focus, for when auto-detection picks the wrong window. macOS: application name (`Ghostty`, `iTerm2`, …), case-insensitive. Linux/X11: window class or instance from `xprop WM_CLASS`, case-insensitive; the last dotted part is enough (`wezterm`, `kitty`). |
| `@claude-notify-sound` | `on` | Play a sound with each notification |
| `@claude-notify-buttons` | `on` | Show Allow and Deny buttons on permission notifications while you are away. `off` keeps plain notifications. |
| `@claude-notify-ask-timeout` | `25` | Seconds a permission notification waits for a click. Keep it below the hook `timeout` in `hooks/hooks.json` (30). |

```tmux
set -g @claude-notify-sound on
# only if auto-detection does not work for you:
set -g @claude-notify-terminal wezterm
```

## Allow and Deny from the notification

When Claude asks for permission to use a tool and you are not looking at its terminal, the notification carries **Allow** and **Deny** buttons, and the text shows what is being approved, such as `Allow Bash? git status`. Clicking one answers the request through a `PermissionRequest` hook.

- Nothing is decided unless you click a button. If you ignore or dismiss the notification, or it times out, the normal permission dialog appears as usual. Clicking the notification body focuses the terminal.
- With the terminal focused, no notification is shown and the dialog appears immediately.
- `AskUserQuestion` and `ExitPlanMode` are left to the terminal, because they need an answer and not a yes or no.
- The notification shows the start of the command, file path or URL (120 characters, one line), so it can end up in Notification Center. Turn the buttons off with `@claude-notify-buttons off` if commands in your sessions can contain secrets.
- On macOS, **Alerts** style shows the buttons at once, and **Banners** show them when you hover or expand the notification.

## How the terminal is detected

- **macOS:** the foreground app (per System Events) whose PID is an ancestor of the hook process. Clicking the notification activates that app by bundle id.
- **Linux/X11:** the window whose `_NET_WM_PID` is an ancestor of the hook process. `$WINDOWID` is used first when your terminal sets it.
- **Under tmux** the tmux server is detached from the terminal, so the ancestry starts from the most recently active tmux client attached to Claude's session.

Known limits: a sandboxed terminal (flatpak, snap) reports a PID that is not in the host process tree, and a terminal that runs behind a mux server breaks the chain. Terminals that keep all windows in one process (Ghostty) match any of their windows. In those cases set `@claude-notify-terminal`.

## macOS permissions

1. Allow notifications: **System Settings → Notifications → terminal-notifier → Allow Notifications**.
2. For click-to-focus, set the style to **Alerts** (Banners don't fire the click action).
3. To slide to the terminal's Space on click, enable **Desktop & Dock → "When switching to an application, switch to a Space with open windows for the application"**.

## Migrating from macos-notify

`macos-notify` has been removed. Uninstall it and install `os-notify`; the tmux options are unchanged.

## Troubleshooting

- **No notification on Linux:** run `notify-send test` in your terminal. If that shows nothing, the problem is your notification daemon, not the plugin.
- **No notification on macOS:** run `terminal-notifier -message test`, and check the permissions above.
- **Notifications show while the terminal is focused, or click does nothing:** auto-detection may have picked no window or the wrong one. Set `@claude-notify-terminal` (Linux: check `xprop WM_CLASS`). On Linux also check that `$DISPLAY` is set and the session is not Wayland.
- Set `DEBUG=1` in the hook's environment for a shell trace.

## Layout

```
scripts/os-notify.sh      shared logic: event handling, project/branch/tmux helpers
scripts/backends/macos.sh   _os_send, _os_ask, _os_is_terminal_focused for macOS
scripts/backends/linux.sh   same interface for Linux (notify-send, X11 focus detection and activation)
```

A new backend only has to define `_os_check_dependencies`, `_os_is_terminal_focused` and `_os_send`.

## License

MIT
