#!/usr/bin/env bash
# Configure FreshTomato Init script to run configuration scripts at boot
# This script runs ON the router via setup-server

set -euo pipefail

echo "Configuring FreshTomato Init script..."

# Set the Init script in NVRAM to run our configuration scripts at boot
nvram set script_init='#!/bin/sh
# Laingville dwaca router configuration - runs at boot

# Wait for USB mount and Entware availability (max 3 minutes)
USB_TIMEOUT=180
USB_ELAPSED=0
while [ ! -x /opt/bin/bash ] && [ $USB_ELAPSED -lt $USB_TIMEOUT ]; do
    echo "Waiting for Entware bash to be available... ($USB_ELAPSED/$USB_TIMEOUT seconds)"
    sleep 5
    USB_ELAPSED=$((USB_ELAPSED + 5))
done

if [ ! -x /opt/bin/bash ]; then
    echo "Warning: Entware bash not available after $USB_TIMEOUT seconds, skipping configuration"
    exit 0
fi

# Wait for JFFS to be ready and writable (max 5 minutes)
JFFS_TIMEOUT=300
JFFS_ELAPSED=0
while [ ! -w /jffs ] && [ $JFFS_ELAPSED -lt $JFFS_TIMEOUT ]; do
    echo "Waiting for JFFS to be writable... ($JFFS_ELAPSED/$JFFS_TIMEOUT seconds)"
    sleep 2
    JFFS_ELAPSED=$((JFFS_ELAPSED + 2))
done

if [ ! -w /jffs ]; then
    echo "Warning: JFFS not writable after $JFFS_TIMEOUT seconds, skipping MOTD setup"
fi

# Run configuration scripts if available
if [ -x /opt/bin/bash ]; then
    echo "Running laingville router configuration scripts..."

    # Apply MOTD (only if JFFS is writable)
    if [ -w /jffs ] && [ -f /opt/laingville/servers/dwaca/scripts/apply_motd.bash ]; then
        /opt/bin/bash /opt/laingville/servers/dwaca/scripts/apply_motd.bash
    elif [ ! -w /jffs ]; then
        echo "Skipping MOTD setup - JFFS not writable"
    fi

    # Apply user profile
    if [ -f /opt/laingville/servers/dwaca/scripts/apply_profile.bash ]; then
        /opt/bin/bash /opt/laingville/servers/dwaca/scripts/apply_profile.bash
    fi

    echo "Laingville router configuration complete"
else
    echo "Warning: Entware bash not available, skipping configuration"
fi
'

# Commit NVRAM changes to persist them
nvram commit

echo "Init script configured successfully in NVRAM"
echo ""
echo "The following scripts will run at boot:"
echo "  - apply_motd.bash (sets up MOTD)"
echo "  - apply_profile.bash (sets up SSH user profile)"
echo ""
echo "To verify: Check Administration → Scripts → Init in FreshTomato web UI"
