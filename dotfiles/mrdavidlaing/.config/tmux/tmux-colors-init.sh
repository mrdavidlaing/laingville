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

if [[ "$1" == "-CC" ]]; then
  exec tmux -CC
else
  exec tmux
fi
