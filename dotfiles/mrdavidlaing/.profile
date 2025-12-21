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

# Ensure programs installed with bun add -g <name> are available in the path
export PATH="$HOME/.cache/.bun/bin:$PATH"

# Add Scoop shims to PATH when available (Git Bash on Windows)
if [ -d "$HOME/scoop/shims" ]; then
    export PATH="$HOME/scoop/shims:$PATH"
fi

# Homebrew initialization for Apple Silicon Macs
# This needs to be available for scripts and all shell types
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Set default editor for all applications (needed by git, scripts)
export EDITOR=nvim

# Happy CLI - Use self-hosted relay server on baljeet
export HAPPY_SERVER_URL="https://baljeet-tailnet.cyprus-macaroni.ts.net"

# Load 1Password environment secrets if available
# Scripts and interactive shells both need access to environment secrets
if [ -f "$HOME/.config/env.secrets.local" ]; then
    . "$HOME/.config/env.secrets.local"
fi

# 1Password SSH Agent configuration
# Set SSH_AUTH_SOCK based on OS for 1Password SSH agent integration
# Always override system SSH agent with 1Password agent if available
# macOS
if [ "$(uname)" = "Darwin" ]; then
    op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [ -S "$op_sock" ]; then
        export SSH_AUTH_SOCK="$op_sock"
    fi
# Linux (including WSL)
elif [ "$(uname)" = "Linux" ]; then
    op_sock="$HOME/.1password/agent.sock"
    if [ -S "$op_sock" ]; then
        export SSH_AUTH_SOCK="$op_sock"
    fi
fi

# WSL-specific configuration for scripts and shells
if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    # Configure Git to use Windows SSH for 1Password agent integration
    # This needs to be available for git scripts, not just interactive use
    if command -v ssh.exe >/dev/null 2>&1; then
        export GIT_SSH_COMMAND="ssh.exe"
    fi

    # Use wslview for opening URLs in Windows browser (requires wslu package)
    # This fixes "xdg-open: command not found" errors
    if command -v wslview >/dev/null 2>&1; then
        export BROWSER=wslview
    fi
fi
