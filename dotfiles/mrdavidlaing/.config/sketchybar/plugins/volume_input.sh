#!/bin/bash
# Input volume (microphone) plugin for Sketchybar

VOLUME=$(osascript -e 'input volume of (get volume settings)')

if [ "$VOLUME" -gt 0 ]; then
    ICON="🎤"
    LABEL="${VOLUME}%"
else
    ICON="🎤"
    LABEL="off"
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
