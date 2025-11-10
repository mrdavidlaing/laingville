#!/usr/bin/env bash

# Beads (bd) Installation Script
# Installs Beads native binary using official installer to ~/.local/bin

set -e

DRY_RUN="${1:-false}"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[Beads (bd)] [DRY RUN] Would install native binary via curl installer"
  exit 0
fi

echo -n "[Beads (bd)] "

# Check if bd binary is already installed and working
bd_binary_path="${HOME}/.local/bin/bd"

if [[ -f "${bd_binary_path}" ]] && [[ -x "${bd_binary_path}" ]]; then
  # Verify it's actually working by checking version
  if "${bd_binary_path}" --version &> /dev/null; then
    version_output=$("${bd_binary_path}" --version 2>&1 | head -n 1)
    echo "[OK] Native binary already installed and working: ${version_output}"
    exit 0
  fi
fi

echo "Installing native binary..."

# Ensure ~/.local/bin exists
mkdir -p "${HOME}/.local/bin"

# Use native binary installer - installs to ~/.local/bin/bd
installer_script=$(curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh)
if echo "${installer_script}" | bash; then
  echo "[Beads (bd)] [OK] Installation successful"
  echo "[Beads (bd)] Native binary installed to ~/.local/bin/bd"

  # Verify the installation
  if command -v bd &> /dev/null; then
    bd_version=$(bd --version 2> /dev/null | head -n 1 || echo "version check failed")
    echo "[Beads (bd)] Version: ${bd_version}"
  fi
else
  echo "[Beads (bd)] [ERROR] Installation failed"
  exit 1
fi
