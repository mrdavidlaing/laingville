# ~/.profile
#
# Universal shell environment configuration for all POSIX shells
# This file is sourced by login shells (sh, bash, zsh, etc.) and should contain
# only POSIX-compatible syntax and environment variables needed by scripts.

# Add user's local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Add Nix profile to PATH (for Nix-installed packages)
if [ -d "$HOME/.nix-profile/bin" ]; then
    export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# Add Cargo (Rust) bin directory to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Add pnpm global bin directory to PATH
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Add Scoop shims to PATH when available (Git Bash on Windows)
if [ -d "$HOME/scoop/shims" ]; then
    export PATH="$HOME/scoop/shims:$PATH"
fi

# Set default editor for all applications
export EDITOR=nvim

# Homebrew initialization for Apple Silicon Macs
# This needs to be available for scripts and all shell types
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Ensure proper terminal capabilities for color support
# Set COLORTERM for true color support if not already set
if [ -z "$COLORTERM" ] && echo "$TERM" | grep -qE "256color|truecolor|24bit"; then
    export COLORTERM=truecolor
fi

# Force proper TERM for SSH sessions when using capable terminals
if [ -n "$SSH_TTY" ] && [ "$TERM" = "xterm-256color" ] && [ -z "$TMUX" ]; then
    # We're in an SSH session with a 256-color terminal
    export COLORTERM=truecolor
fi

# Happy CLI - Use self-hosted relay server on baljeet
# Default server is https://api.cluster-fluster.com
export HAPPY_SERVER_URL="http://baljeet-tailnet:3005"

# Load 1Password environment secrets if available
# Scripts and interactive shells both need access to environment secrets
if [ -f "$HOME/.config/env.secrets.local" ]; then
    . "$HOME/.config/env.secrets.local"
fi

# WSL-specific configuration for scripts and shells
if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    # Configure Git to use Windows SSH for 1Password agent integration
    # This needs to be available for git scripts, not just interactive use
    if command -v ssh.exe >/dev/null 2>&1; then
        export GIT_SSH_COMMAND="ssh.exe"
    fi
fi