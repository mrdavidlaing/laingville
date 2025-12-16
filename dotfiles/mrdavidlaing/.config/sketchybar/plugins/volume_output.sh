#!/bin/bash
# Output volume plugin for Sketchybar

VOLUME=$(osascript -e 'output volume of (get volume settings)')
MUTED=$(osascript -e 'output muted of (get volume settings)')

if [ "$MUTED" = "true" ]; then
    ICON="🔇"
    LABEL="mute"
elif [ "$VOLUME" -gt 66 ]; then
    ICON="🔊"
    LABEL="${VOLUME}%"
elif [ "$VOLUME" -gt 33 ]; then
    ICON="🔉"
    LABEL="${VOLUME}%"
elif [ "$VOLUME" -gt 0 ]; then
    ICON="🔈"
    LABEL="${VOLUME}%"
else
    ICON="🔇"
    LABEL="0%"
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
