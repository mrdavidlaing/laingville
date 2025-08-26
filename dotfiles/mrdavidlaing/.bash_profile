# ~/.bash_profile
#
# Bash login shell initialization
# This file is sourced by bash login shells (like macOS Terminal and WezTerm)

# First, source universal shell environment (POSIX compatible)
# This provides environment variables needed by scripts and all shell types
if [[ -f ~/.profile ]]; then
    source ~/.profile
fi

# Then, source interactive bash configuration if running interactively
# This provides aliases, prompts, and interactive tools specific to bash
if [[ -f ~/.bashrc && $- == *i* ]]; then
    source ~/.bashrc
fi