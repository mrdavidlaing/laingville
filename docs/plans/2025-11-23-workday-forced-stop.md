# Workday Forced Stop Implementation Plan

**Date**: 2025-11-23
**Status**: Implemented
**Platform**: macOS (mo-inator only)

## Problem Statement

Working past 18:00 due to "one more thing" syndrome - Slack conversations, meetings, or tasks that extend the workday to 20:00. By this time, emotional tiredness is high and west coast colleagues are just getting started, making it hard to disengage.

## Solution Overview

Implement a forced work stop mechanism using native macOS tools (launchd + AppleScript):

1. **17:45** - Large countdown timer appears (15 minutes warning)
2. **18:00** - Mac is forced to sleep via `pmset sleepnow`

### Design Constraints

- Mon-Fri only (weekdays)
- Timer respawns if closed (truly forced, cannot dismiss)
- Pure launchd + AppleScript (no third-party apps)
- Scripts stored in `~/.local/bin/` (via dotfiles symlinks)

## Implementation Details

### Files to Create

All files will be created in `dotfiles/mrdavidlaing/.local/bin/`:

#### 1. `workday-countdown.applescript`

An AppleScript application that displays a floating, always-on-top countdown timer:

- Large, prominent countdown display
- Cannot be hidden behind other windows
- If closed, respawns immediately via wrapper script
- Counts down from 15 minutes to 0
- Provides social cover for leaving meetings: "My machine is about to lock"

```applescript
-- Pseudocode structure
on run
    set targetTime to (current date) + (15 * minutes)
    repeat while (current date) < targetTime
        set remainingSeconds to (targetTime - (current date))
        display dialog with countdown...
        delay 1
    end repeat
end run
```

#### 2. `workday-countdown-wrapper.sh`

Bash wrapper that ensures the timer respawns if closed:

```bash
#!/bin/bash
# Continuously run the countdown timer
# If it exits (user closed), restart it immediately
while true; do
    osascript ~/.local/bin/workday-countdown.applescript
    # Small delay to prevent CPU spin if something goes wrong
    sleep 1
done
```

#### 3. `workday-suspend.sh`

Script that triggers the forced sleep:

```bash
#!/bin/bash
# Kill the countdown timer process
pkill -f "workday-countdown"

# Force immediate sleep
pmset sleepnow
```

### Launch Agent Configuration

Files to create in `dotfiles/mrdavidlaing/Library/LaunchAgents/`:

#### 4. `com.mrdavidlaing.workday-countdown.plist`

Triggers the countdown timer at 17:45 on weekdays:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mrdavidlaing.workday-countdown</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>~/.local/bin/workday-countdown-wrapper.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <!-- Monday through Friday at 17:45 -->
        <dict>
            <key>Weekday</key><integer>1</integer>
            <key>Hour</key><integer>17</integer>
            <key>Minute</key><integer>45</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>2</integer>
            <key>Hour</key><integer>17</integer>
            <key>Minute</key><integer>45</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>3</integer>
            <key>Hour</key><integer>17</integer>
            <key>Minute</key><integer>45</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>4</integer>
            <key>Hour</key><integer>17</integer>
            <key>Minute</key><integer>45</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>5</integer>
            <key>Hour</key><integer>17</integer>
            <key>Minute</key><integer>45</integer>
        </dict>
    </array>
</dict>
</plist>
```

#### 5. `com.mrdavidlaing.workday-suspend.plist`

Triggers the forced sleep at 18:00 on weekdays:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mrdavidlaing.workday-suspend</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>~/.local/bin/workday-suspend.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <!-- Monday through Friday at 18:00 -->
        <dict>
            <key>Weekday</key><integer>1</integer>
            <key>Hour</key><integer>18</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>2</integer>
            <key>Hour</key><integer>18</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>3</integer>
            <key>Hour</key><integer>18</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>4</integer>
            <key>Hour</key><integer>18</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>5</integer>
            <key>Hour</key><integer>18</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
    </array>
</dict>
</plist>
```

## Directory Structure

```
dotfiles/mrdavidlaing/
├── .local/
│   └── bin/
│       ├── workday-countdown.applescript
│       ├── workday-countdown-wrapper.sh
│       └── workday-suspend.sh
└── Library/
    └── LaunchAgents/
        ├── com.mrdavidlaing.workday-countdown.plist
        └── com.mrdavidlaing.workday-suspend.plist
```

## Installation

After running `setup-user`, the files will be symlinked to:
- `~/.local/bin/workday-*.sh` - Scripts
- `~/Library/LaunchAgents/*.plist` - Launch agents

Then load the launch agents:

```bash
launchctl load ~/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist
launchctl load ~/Library/LaunchAgents/com.mrdavidlaing.workday-suspend.plist
```

## Emergency Override

If you genuinely need to work late (emergency):

```bash
# Disable for the rest of the day
launchctl unload ~/Library/LaunchAgents/com.mrdavidlaing.workday-suspend.plist
launchctl unload ~/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist

# Kill current timer if running
pkill -f "workday-countdown"
```

Re-enable next day by running `launchctl load` again, or reboot (agents auto-load on login).

## Testing

```bash
# Test countdown timer manually
osascript ~/.local/bin/workday-countdown.applescript

# Test suspend script (will immediately sleep your Mac!)
~/.local/bin/workday-suspend.sh

# Verify launch agents are loaded
launchctl list | grep workday
```

## Future Enhancements

- Add holiday calendar integration (skip bank holidays)
- Add "vacation mode" disable flag
- Make times configurable via environment variables
- Add audio warning at 17:55

## Implementation Tasks

1. [x] Create `dotfiles/mrdavidlaing/Library/LaunchAgents/` directory
2. [x] Update `symlinks.yaml` to include `Library/LaunchAgents/` directory
3. [x] Create `workday-countdown.applescript` with floating timer UI
4. [x] Create `workday-countdown-wrapper.sh` with respawn logic
5. [x] Create `workday-suspend.sh` with cleanup and sleep command
6. [x] Create both `.plist` launch agent files
7. [ ] Test on macOS (mo-inator)
8. [ ] Document in dotfiles README

## Implementation Notes

- Scripts are symlinked via `symlinks.yaml` on all macOS systems
- LaunchAgents are only loaded on `mo-inator` via hostname check in `setup-user-hook.sh`
- On other Macs, the files exist but agents are explicitly unloaded
