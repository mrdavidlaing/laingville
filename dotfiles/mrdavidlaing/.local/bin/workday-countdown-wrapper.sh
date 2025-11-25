#!/bin/bash
# Workday Final Warning and Suspend Handler
# Displays final 30-second countdown then forces sleep

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show final countdown warning
osascript "$SCRIPT_DIR/workday-final-warning.applescript"

# Force immediate sleep
pmset sleepnow
