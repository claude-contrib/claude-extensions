#!/usr/bin/env osascript
-- macos-focus.scpt — bring the terminal app to the front
--
-- Works for normal windows, hidden apps, and fullscreen Spaces.
-- Uses activate to initiate the Space switch, then sets frontmost via
-- System Events to ensure the process comes forward in all cases.
--
-- Arguments:
--   1: TERM_PROGRAM value (e.g. "ghostty", "iTerm.app", "Apple_Terminal")

on run argv
  set termProgram to item 1 of argv
  set appName to getAppName(termProgram)
  if appName is not "" then
    focusApp(appName)
  end if
end run

-- Map TERM_PROGRAM identifier to the macOS application name
on getAppName(termProgram)
  if termProgram is "Apple_Terminal" then
    return "Terminal"
  else if termProgram is "iTerm.app" then
    return "iTerm2"
  else if termProgram is "alacritty" then
    return "Alacritty"
  else if termProgram is "WezTerm" then
    return "WezTerm"
  else if termProgram is "kitty" then
    return "kitty"
  else if termProgram is "ghostty" then
    return "Ghostty"
  end if
  return ""
end getAppName

-- Activate the app and force it to the front via System Events.
-- activate alone triggers the Space switch animation but may not complete
-- the transition for fullscreen apps; setting frontmost ensures it does.
on focusApp(appName)
  tell application appName to activate
  tell application "System Events"
    tell process appName
      set frontmost to true
    end tell
  end tell
end focusApp
