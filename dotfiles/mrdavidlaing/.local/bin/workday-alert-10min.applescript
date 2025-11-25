#!/usr/bin/osascript
-- Workday 10-minute warning
-- Displays a simple dismissible alert

on run
    display alert "Workday Ending" message "Your Mac will sleep at 18:00" & return & return & "Time remaining: 10 minutes" buttons {"OK"} default button "OK" as warning
end run
