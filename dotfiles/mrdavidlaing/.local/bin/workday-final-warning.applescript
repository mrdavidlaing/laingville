#!/usr/bin/osascript
-- Workday final warning - displays countdown before sleep
-- Shows 30-second countdown then forces sleep

on run
    set targetTime to (current date) + (30)
    
    repeat while (current date) < targetTime
        set remainingSeconds to round ((targetTime - (current date)) as real)
        
        if remainingSeconds < 0 then
            exit repeat
        end if
        
        -- Format remaining time
        set secs to remainingSeconds mod 60
        set timeString to text -2 thru -1 of ("0" & secs)
        
        -- Display the final countdown
        try
            display alert "Last Chance!" message "Mac will sleep in 30 seconds!" & return & return & "Time remaining: " & timeString buttons {"OK"} default button "OK" giving up after 1 as critical
        on error
            -- Dialog dismissed, continue countdown
        end try
        
        delay 1
    end repeat
end run
