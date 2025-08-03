#!/bin/bash

# Claude Code Installation Script
# Installs Claude Code native binary using official installer
# Removes any existing npm installations first

set -e

DRY_RUN="${1:-false}"

# Function to check if claude is installed via npm
check_npm_installation() {
    # Check global npm installation
    if npm list -g @anthropic/claude-cli &>/dev/null || npm list -g claude-code &>/dev/null; then
        echo "global"
        return 0
    fi
    
    # Check local npm installation (check if we're in a project with claude in package.json)
    if [ -f "package.json" ] && (grep -q "@anthropic/claude-cli" package.json 2>/dev/null || grep -q "claude-code" package.json 2>/dev/null); then
        echo "local"
        return 0
    fi
    
    return 1
}

# Function to remove npm installation
remove_npm_installation() {
    local install_type="$1"
    
    if [ "$install_type" = "global" ]; then
        echo "[Claude Code] Removing global npm installation..."
        npm uninstall -g @anthropic/claude-cli 2>/dev/null || true
        npm uninstall -g claude-code 2>/dev/null || true
    elif [ "$install_type" = "local" ]; then
        echo "[Claude Code] Warning: Local npm installation detected in package.json"
        echo "[Claude Code] Please manually remove claude from your project dependencies"
        echo "[Claude Code] The binary installation will take precedence in PATH"
    fi
}

if [ "$DRY_RUN" = "true" ]; then
    echo "[Claude Code] Would check for existing npm installations and remove if found"
    echo "[Claude Code] Would install native binary via curl installer"
    exit 0
fi

echo -n "[Claude Code] "

# Check for existing npm installations
if npm_install_type=$(check_npm_installation 2>/dev/null); then
    remove_npm_installation "$npm_install_type"
fi

# Check if claude binary is already installed (and ensure it's the native version)
if command -v claude &> /dev/null; then
    # Check if it's the native binary (native binary is installed to ~/.local/bin)
    claude_path=$(which claude)
    if [[ "$claude_path" == *"/.local/bin/claude" ]]; then
        echo "✅ Native binary already installed"
        exit 0
    else
        echo "Found claude at $claude_path, will install native binary to take precedence..."
    fi
fi

echo "Installing native binary..."

# Use native binary installer - installs to ~/.local/bin/claude
if curl -fsSL https://claude.ai/install.sh | bash -s latest; then
    echo "[Claude Code] ✅ Installation successful"
    echo "[Claude Code] Native binary installed to ~/.local/bin/claude"
    
    # Verify the installation
    if command -v claude &> /dev/null; then
        claude_version=$(claude --version 2>/dev/null || echo "version check failed")
        echo "[Claude Code] Version: $claude_version"
    fi
else
    echo "[Claude Code] ❌ Installation failed"
    exit 1
fi