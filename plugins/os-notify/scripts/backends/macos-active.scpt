#!/usr/bin/env osascript
-- macos-active.scpt — print the name of the frontmost application

on run
  tell application "System Events"
    get name of first application process whose frontmost is true
  end tell
end run
