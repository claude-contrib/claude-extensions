#!/usr/bin/env osascript
-- focus.scpt — bring the terminal app to the front
--
-- Arguments:
--   1: TERM_PROGRAM value (e.g. "ghostty", "iTerm.app", "Apple_Terminal")

on run argv
  set termProgram to item 1 of argv

  if termProgram is "Apple_Terminal" then
    tell application "Terminal" to activate
  else if termProgram is "iTerm.app" then
    tell application "iTerm2" to activate
  else if termProgram is "alacritty" then
    tell application "Alacritty" to activate
  else if termProgram is "WezTerm" then
    tell application "WezTerm" to activate
  else if termProgram is "kitty" then
    tell application "kitty" to activate
  else if termProgram is "ghostty" then
    tell application "Ghostty" to activate
  end if
end run
