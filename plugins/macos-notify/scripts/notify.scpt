#!/usr/bin/env osascript
-- notify.scpt — send a macOS Notification Center alert
--
-- Arguments:
--   1: title
--   2: subtitle
--   3: message
--   4: sound name (e.g. "Glass", "Ping") — pass empty string to omit sound

on run argv
  set notifTitle    to item 1 of argv
  set notifSubtitle to item 2 of argv
  set notifMessage  to item 3 of argv
  set notifSound    to item 4 of argv

  if notifSound is "" then
    display notification notifMessage with title notifTitle subtitle notifSubtitle
  else
    display notification notifMessage with title notifTitle subtitle notifSubtitle sound name notifSound
  end if
end run
