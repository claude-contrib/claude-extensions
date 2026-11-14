#!/usr/bin/env osascript
-- macos-active.scpt — print the frontmost application
--
-- Arguments:
--   1: "pid" to print its unix process id; omit to print its name

on run argv
  tell application "System Events"
    set frontApp to first application process whose frontmost is true
    if (count of argv) > 0 and item 1 of argv is "pid" then
      return unix id of frontApp
    end if
    return name of frontApp
  end tell
end run
