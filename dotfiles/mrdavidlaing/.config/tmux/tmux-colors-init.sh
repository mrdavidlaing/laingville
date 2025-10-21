#!/bin/bash
# tmux-colors-init.sh - Initialize proper terminal colors for tmux sessions

# Ensure proper terminal environment before starting tmux
export COLORTERM=truecolor

# If we're in an SSH session, make sure we have the right TERM
if [[ -n "$SSH_TTY" ]]; then
    # For SSH sessions, ensure we communicate 256-color capability
    if [[ "$TERM" == "xterm" || "$TERM" == "xterm-color" ]]; then
        export TERM=xterm-256color
    fi
fi

# Display current terminal settings
echo "Terminal environment:"
echo "  TERM: $TERM"
echo "  COLORTERM: $COLORTERM"
echo "  SSH_TTY: ${SSH_TTY:-"(not set)"}"
echo ""

# Start tmux with control mode if requested, or regular tmux
if [[ "$1" == "-CC" ]]; then
    echo "Starting tmux with control mode (-CC)..."
    tmux -CC
else
    echo "Starting regular tmux session..."
    tmux
fi