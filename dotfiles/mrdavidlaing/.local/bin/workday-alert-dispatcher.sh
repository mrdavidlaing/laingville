#!/bin/bash
# Workday Alert Dispatcher
# Determines which alert to show based on current time
# Called by launch agent every minute during 17:45-18:00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get current time in minutes since midnight
CURRENT_HOUR=$(date +%H)
CURRENT_MIN=$(date +%M)
CURRENT_TIME=$((CURRENT_HOUR * 60 + CURRENT_MIN))

# Define alert times (in minutes since midnight)
TIME_17_45=$((17 * 60 + 45))
TIME_17_50=$((17 * 60 + 50))
TIME_17_55=$((17 * 60 + 55))
TIME_18_00=$((18 * 60))

# Show appropriate alert based on current time
if [ "$CURRENT_TIME" -ge "$TIME_17_45" ] && [ "$CURRENT_TIME" -lt "$TIME_17_50" ]; then
  osascript "$SCRIPT_DIR/workday-alert-15min.applescript" 2> /dev/null
elif [ "$CURRENT_TIME" -ge "$TIME_17_50" ] && [ "$CURRENT_TIME" -lt "$TIME_17_55" ]; then
  osascript "$SCRIPT_DIR/workday-alert-10min.applescript" 2> /dev/null
elif [ "$CURRENT_TIME" -ge "$TIME_17_55" ] && [ "$CURRENT_TIME" -lt "$TIME_18_00" ]; then
  osascript "$SCRIPT_DIR/workday-alert-5min.applescript" 2> /dev/null
elif [ "$CURRENT_TIME" -ge "$TIME_18_00" ]; then
  # Run the final warning and sleep
  bash "$SCRIPT_DIR/workday-countdown-wrapper.sh"
fi
