#!/bin/bash
# Workday Suspend Script
# Kills the countdown timer and forces the Mac to sleep

# Kill the countdown timer processes
pkill -f "workday-countdown"

# Force immediate sleep
pmset sleepnow
