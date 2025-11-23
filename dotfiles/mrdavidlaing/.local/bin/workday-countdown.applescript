#!/usr/bin/osascript
-- Workday Countdown Timer
-- Displays a floating, always-on-top countdown timer
-- Shows 15 minutes warning before forced sleep at 18:00

on run
    -- Calculate end time (15 minutes from now)
    set targetTime to (current date) + (15 * minutes)

    -- Main countdown loop
    repeat while (current date) < targetTime
        set remainingSeconds to round ((targetTime - (current date)) as real)

        if remainingSeconds < 0 then
            exit repeat
        end if

        -- Format remaining time
        set mins to remainingSeconds div 60
        set secs to remainingSeconds mod 60
        set timeString to text -2 thru -1 of ("0" & mins) & ":" & text -2 thru -1 of ("0" & secs)

        -- Display countdown dialog
        -- Using "giving up after 1" makes it auto-dismiss after 1 second
        -- This allows the loop to continue and update the timer
        try
            display dialog "WORKDAY ENDING" & return & return & "Time remaining:" & return & return & timeString & return & return & "Mac will sleep at 18:00" buttons {"I understand"} default button 1 giving up after 1 with icon caution with title "Workday Timer"
        on error
            -- Dialog was dismissed by user, continue anyway
        end try
    end repeat
end run
