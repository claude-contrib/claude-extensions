#!/usr/bin/env osascript
-- macos-focus.scpt — bring the terminal app to the front
--
-- Works for normal windows, hidden apps, and fullscreen Spaces.
-- Requires "When switching to an application, switch to a Space with open
-- windows for the application" in System Settings → Desktop & Dock.
--
-- Arguments:
--   1: macOS application name (e.g. "Ghostty", "iTerm2", "Terminal"), or ""
--   2: unix process id of the terminal app, or "" — preferred over the name

on run argv
  set appName to item 1 of argv
  set appPid to ""
  if (count of argv) > 1 then set appPid to item 2 of argv

  if appPid is not "" then
    tell application "System Events"
      set bundleId to bundle identifier of first application process whose unix id is (appPid as integer)
    end tell
    tell application id bundleId to activate
  else if appName is not "" then
    tell application appName to activate
  end if
end run
