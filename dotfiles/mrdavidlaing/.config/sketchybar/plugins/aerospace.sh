#!/bin/bash
# Aerospace workspace indicator plugin for Sketchybar
# Groups workspaces by monitor, ordered left-to-right with separators between groups

# Get the currently focused workspace
FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null)

# Get monitor count
MONITOR_COUNT=$(aerospace list-monitors 2>/dev/null | wc -l | tr -d ' ')

# Build ordered list of workspaces grouped by monitor (1, 2, 3...)
# This ensures left monitor's workspaces appear first, then middle, then right
ORDERED_WORKSPACES=""
declare -a WORKSPACE_MONITOR
for mon in $(seq 1 "$MONITOR_COUNT"); do
    for ws in $(aerospace list-workspaces --monitor "$mon" 2>/dev/null | sort -n); do
        ORDERED_WORKSPACES="$ORDERED_WORKSPACES $ws"
        WORKSPACE_MONITOR[$ws]=$mon
    done
done

# Get workspaces with windows
declare -a HAS_WINDOWS
for ws in $(aerospace list-workspaces --all 2>/dev/null); do
    if [ -n "$(aerospace list-windows --workspace "$ws" 2>/dev/null)" ]; then
        HAS_WINDOWS[$ws]=1
    fi
done

# Track separator positions (workspace slot after which to place separator)
declare -a SEPARATOR_AFTER
CURRENT_MONITOR=0
POS=0

for ws in $ORDERED_WORKSPACES; do
    # Only show workspaces 1-12
    if [ "$ws" -gt 12 ]; then
        continue
    fi

    MON=${WORKSPACE_MONITOR[$ws]:-0}

    # Check if monitor changed - mark separator position
    if [ "$CURRENT_MONITOR" -ne 0 ] && [ "$MON" -ne "$CURRENT_MONITOR" ]; then
        SEPARATOR_AFTER[$CURRENT_MONITOR]=$POS
    fi
    CURRENT_MONITOR=$MON

    POS=$((POS + 1))

    if [ "$ws" = "$FOCUSED_WORKSPACE" ]; then
        # Active workspace: blue text with blue underline
        sketchybar --set workspace.$POS \
            icon="$ws" \
            icon.color=0xff3daee9 \
            icon.drawing=on \
            background.color=0x00000000 \
            background.border_color=0xff3daee9 \
            background.border_width=2 \
            background.corner_radius=0 \
            background.height=28 \
            background.drawing=on \
            click_script="aerospace workspace $ws"
    elif [ "${HAS_WINDOWS[$ws]}" = "1" ]; then
        # Has windows but not focused: white text
        sketchybar --set workspace.$POS \
            icon="$ws" \
            icon.color=0xffeff0f1 \
            icon.drawing=on \
            background.drawing=off \
            click_script="aerospace workspace $ws"
    else
        # Empty workspace: dim gray text
        sketchybar --set workspace.$POS \
            icon="$ws" \
            icon.color=0xff6c6c6c \
            icon.drawing=on \
            background.drawing=off \
            click_script="aerospace workspace $ws"
    fi
done

# Hide any unused workspace slots (only if POS <= 12)
if [ "$POS" -lt 12 ]; then
    for i in $(seq $((POS + 1)) 12); do
        sketchybar --set workspace.$i icon.drawing=off background.drawing=off
    done
fi

# Position and show/hide separators
for sep in 1 2; do
    if [ -n "${SEPARATOR_AFTER[$sep]}" ]; then
        # Show separator and move it after the workspace
        sketchybar --set separator.$sep icon.drawing=on
        sketchybar --move separator.$sep after workspace.${SEPARATOR_AFTER[$sep]}
    else
        # Hide separator if not needed
        sketchybar --set separator.$sep icon.drawing=off
    fi
done
