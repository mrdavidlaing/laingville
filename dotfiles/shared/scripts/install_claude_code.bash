#!/usr/bin/env bash

# Claude Code Installation Script
# Installs Claude Code native binary using official installer

set -e

DRY_RUN="${1:-false}"

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
