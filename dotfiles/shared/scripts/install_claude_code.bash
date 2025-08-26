#!/usr/bin/env bash

# Claude Code Installation Script
# Installs Claude Code native binary using official installer
# Removes any existing npm installations first

set -e

DRY_RUN="${1:-false}"

# Function to warn about npm installations
warn_npm_installations() {
  echo "[Claude Code] Checking for npm installations..."

  # List of possible package names to check
  packages=("@anthropic/claude-cli" "claude-code" "@anthropic-ai/claude-code")
  found_any=false

  # Check global npm installations (user-level)
  for package in "${packages[@]}"; do
    if npm list -g "${package}" &> /dev/null; then
      echo "[Claude Code] WARNING: Found global npm package: ${package}"
      echo "[Claude Code] Consider uninstalling with: npm uninstall -g ${package}"
      found_any=true
    fi
  done

  # Check for claude installations in $HOME (local npm packages)
  if [[ -f "${HOME}/package.json" ]]; then
    cd "${HOME}"
    for package in "${packages[@]}"; do
      if npm list "${package}" &> /dev/null; then
        echo "[Claude Code] WARNING: Found local npm package: ${package} in ${HOME}"
        echo "[Claude Code] Consider uninstalling with: npm uninstall ${package}"
        found_any=true
      fi
    done
  fi

  if [[ "${found_any}" = false ]]; then
    echo "[Claude Code] No npm installations found"
  fi
}

# Warn about any existing npm installations
warn_npm_installations

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[Claude Code] [DRY RUN] Would install native binary via curl installer"
  exit 0
fi

echo -n "[Claude Code] "

# Check if claude binary is already installed and working
claude_binary_path="${HOME}/.local/bin/claude"

if [[ -f "${claude_binary_path}" ]] && [[ -x "${claude_binary_path}" ]]; then
  # Verify it's actually working by checking version
  if "${claude_binary_path}" --version &> /dev/null; then
    version_output=$("${claude_binary_path}" --version 2>&1)
    echo "[OK] Native binary already installed and working: ${version_output}"
    exit 0
  fi
fi

# Also check if claude is available in PATH (in case it's installed elsewhere)
if command -v claude &> /dev/null; then
  claude_path=$(command -v claude)
  if [[ "${claude_path}" != "${claude_binary_path}" ]]; then
    echo "Found claude at ${claude_path}, will install native binary to take precedence..."
  fi
fi

echo "Installing native binary..."

# Use native binary installer - installs to ~/.local/bin/claude
installer_script=$(curl -fsSL https://claude.ai/install.sh)
if echo "${installer_script}" | bash -s latest; then
  echo "[Claude Code] [OK] Installation successful"
  echo "[Claude Code] Native binary installed to ~/.local/bin/claude"

  # Verify the installation
  if command -v claude &> /dev/null; then
    claude_version=$(claude --version 2> /dev/null || echo "version check failed")
    echo "[Claude Code] Version: ${claude_version}"
  fi
else
  echo "[Claude Code] [ERROR] Installation failed"
  exit 1
fi
