#!/usr/bin/env osascript
-- macos-focus.scpt — bring the terminal app to the front
--
-- Works for normal windows, hidden apps, and fullscreen Spaces.
-- Requires "When switching to an application, switch to a Space with open
-- windows for the application" in System Settings → Desktop & Dock.
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

-- Bring the app to the front, switching to its Space if needed.
-- Requires "When switching to an application, switch to a Space with open
-- windows for the application" to be enabled in System Settings → Desktop & Dock.
on focusApp(appName)
  tell application appName to activate
end focusApp
