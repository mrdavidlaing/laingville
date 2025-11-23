#!/bin/bash
# Workday Countdown Wrapper
# Continuously runs the countdown timer, respawning if user closes it
# This ensures the timer cannot be dismissed

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while true; do
  osascript "$SCRIPT_DIR/workday-countdown.applescript"

  # Small delay to prevent CPU spin if something goes wrong
  sleep 1
done
