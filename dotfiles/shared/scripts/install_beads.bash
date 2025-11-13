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

# Path to target binary
bd_binary_path="${HOME}/.local/bin/bd"

# If an existing binary is present and working, report current version,
# but do not exit — always install/update to the latest version.
if [[ -x "${bd_binary_path}" ]] && "${bd_binary_path}" --version &> /dev/null; then
  version_output=$("${bd_binary_path}" --version 2>&1 | head -n 1)
  echo "[INFO] Existing installation detected: ${version_output} — updating to latest"
else
  echo "Installing native binary..."
fi

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
