#!/usr/bin/osascript
-- Workday 15-minute warning
-- Displays a simple dismissible alert

on run
    display alert "Workday Ending" message "Your Mac will sleep at 18:00" & return & return & "Time remaining: 15 minutes" buttons {"OK"} default button "OK" as warning
end run
