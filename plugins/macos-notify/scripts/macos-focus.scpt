#!/usr/bin/env osascript
-- macos-focus.scpt — bring the terminal app to the front
--
-- Works for normal windows, hidden apps, and fullscreen Spaces.
-- Requires "When switching to an application, switch to a Space with open
-- windows for the application" in System Settings → Desktop & Dock.
--
-- Arguments:
--   1: macOS application name (e.g. "Ghostty", "iTerm2", "Terminal")

on run argv
  set appName to item 1 of argv
  if appName is not "" then
    tell application appName to activate
  end if
end run
