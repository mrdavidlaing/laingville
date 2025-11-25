# Workday Forced Stop Implementation Plan

**Date**: 2025-11-23
**Status**: Implemented
**Platform**: macOS (mo-inator only)

## Problem Statement (Updated 2025-11-25)

Original problem: Working past 18:00 due to "one more thing" syndrome with countdown timer that respawns continuously if dismissed, making computer unusable.

New requirement: Dismissible alerts at 5-minute intervals with final "last chance" warning before forced sleep.

## Solution Overview

Implement a friendly work stop mechanism using native macOS tools (launchd + AppleScript):

1. **17:45** - "15 minutes remaining" alert (dismissible)
2. **17:50** - "10 minutes remaining" alert (dismissible)
3. **17:55** - "5 minutes remaining" alert (dismissible)
4. **18:00** - "Last Chance! Sleeping in 30 seconds" countdown, then forced sleep via `pmset sleepnow`

### Design Constraints

- Mon-Fri only (weekdays)
- Each alert is dismissible (user regains control of computer)
- Final 18:00 alert shows 30-second countdown before forced sleep
- Pure launchd + AppleScript (no third-party apps)
- Scripts stored in `~/.local/bin/` (via dotfiles symlinks)

## Implementation Details (Updated 2025-11-25)

### Files to Create

All files created in `dotfiles/mrdavidlaing/.local/bin/`:

#### Alert Scripts (Individual dismissible alerts)

1. **`workday-alert-15min.applescript`** - Simple alert: "15 minutes remaining"
2. **`workday-alert-10min.applescript`** - Simple alert: "10 minutes remaining"
3. **`workday-alert-5min.applescript`** - Simple alert: "5 minutes remaining"
4. **`workday-final-warning.applescript`** - Countdown alert with 30-second timer before forced sleep

Each alert displays and exits when user clicks OK (user controls computer again).

#### Dispatcher and Wrapper Scripts

**`workday-alert-dispatcher.sh`** - Smart dispatcher that:
- Runs at each scheduled time (17:45, 17:50, 17:55, 18:00)
- Determines which alert to show based on current time
- Calls appropriate alert script
- At 18:00: calls `workday-countdown-wrapper.sh`

**`workday-countdown-wrapper.sh`** - Final warning and sleep:
- Shows 30-second countdown dialog with "Last Chance!" message
- Auto-dismisses countdown every second to keep it fresh
- After 30 seconds: forces immediate sleep via `pmset sleepnow`

### Launch Agent Configuration

File created in `dotfiles/mrdavidlaing/Library/LaunchAgents/`:

**`com.mrdavidlaing.workday-countdown.plist`** - Single launch agent that:
- Triggers `workday-alert-dispatcher.sh` at 4 times per day (17:45, 17:50, 17:55, 18:00)
- Runs Mon-Fri only (weekdays)
- Dispatcher determines which alert to show based on time

See: `dotfiles/mrdavidlaing/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist`

The plist triggers `workday-alert-dispatcher.sh` at 17:45, 17:50, 17:55, and 18:00 on weekdays (Mon-Fri).
The dispatcher script determines which alert to show based on the current time.

## Directory Structure

```
dotfiles/mrdavidlaing/
├── .local/
│   └── bin/
│       ├── workday-alert-15min.applescript
│       ├── workday-alert-10min.applescript
│       ├── workday-alert-5min.applescript
│       ├── workday-alert-dispatcher.sh
│       ├── workday-final-warning.applescript
│       └── workday-countdown-wrapper.sh
└── Library/
    └── LaunchAgents/
        └── com.mrdavidlaing.workday-countdown.plist
```

## Installation

After running `setup-user`, the files will be symlinked to:
- `~/.local/bin/workday-*.applescript` - Alert scripts
- `~/.local/bin/workday-*.sh` - Dispatcher and wrapper scripts
- `~/Library/LaunchAgents/*.plist` - Launch agent

Then load the launch agent:

```bash
launchctl load ~/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist
```

## Emergency Override

If you genuinely need to work late (emergency):

```bash
# Disable for the rest of the day
launchctl unload ~/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist

# Kill current alerts if running
pkill -f "osascript.*workday-alert"
```

Re-enable next day by running `launchctl load` again, or reboot (agents auto-load on login).

## Testing

```bash
# Test individual alerts manually
osascript ~/.local/bin/workday-alert-15min.applescript
osascript ~/.local/bin/workday-alert-10min.applescript
osascript ~/.local/bin/workday-alert-5min.applescript
osascript ~/.local/bin/workday-final-warning.applescript

# Test dispatcher script (will immediately sleep your Mac!)
~/.local/bin/workday-suspend.sh

# Verify launch agents are loaded
launchctl list | grep workday
```

## Future Enhancements

- Add holiday calendar integration (skip bank holidays)
- Add "vacation mode" disable flag
- Make times configurable via environment variables
- Add audio warning at 17:55

## Implementation Tasks (Updated 2025-11-25)

### Original Implementation (Completed)
1. [x] Create `dotfiles/mrdavidlaing/Library/LaunchAgents/` directory
2. [x] Update `symlinks.yaml` to include `Library/LaunchAgents/` directory
3. [x] Create `workday-countdown.applescript` with floating timer UI
4. [x] Create `workday-countdown-wrapper.sh` with respawn logic
5. [x] Create `workday-suspend.sh` with cleanup and sleep command
6. [x] Create both `.plist` launch agent files

### Updated Implementation (Completed)
7. [x] Create 4 individual alert scripts (15min, 10min, 5min, final warning)
8. [x] Create `workday-alert-dispatcher.sh` smart router
9. [x] Rewrite `workday-countdown-wrapper.sh` for final warning + sleep
10. [x] Simplify `com.mrdavidlaing.workday-countdown.plist` to single agent
11. [x] Remove `com.mrdavidlaing.workday-suspend.plist` (merged into countdown)
12. [x] Update documentation with new approach

### Testing & Deployment
13. [ ] Test on macOS (mo-inator) during 17:45-18:00 window
14. [ ] Verify alerts appear and can be dismissed
15. [ ] Verify final warning shows 30-second countdown
16. [ ] Verify Mac sleeps at 18:00

## Implementation Notes

- Scripts are symlinked via `symlinks.yaml` on all macOS systems
- LaunchAgents are only loaded on `mo-inator` via hostname check in `setup-user-hook.sh`
- On other Macs, the files exist but agents are explicitly unloaded
