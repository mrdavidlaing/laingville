#!/usr/bin/env bash

# Bun Installation Script
# Installs Bun JavaScript runtime using official installer to ~/.bun/bin

set -e

DRY_RUN="${1:-false}"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[Bun] [DRY RUN] Would install Bun runtime via official installer"
  exit 0
fi

echo -n "[Bun] "

# Path to target binary
bun_binary_path="${HOME}/.bun/bin/bun"

# If an existing binary is present and working, report current version,
# but do not exit — always install/update to the latest version.
if [[ -x "${bun_binary_path}" ]] && "${bun_binary_path}" --version &> /dev/null; then
  version_output=$("${bun_binary_path}" --version 2>&1 | head -n 1)
  echo "[INFO] Existing installation detected: ${version_output} — updating to latest"
else
  echo "Installing Bun runtime..."
fi

# Use official bun installer - installs to ~/.bun/bin/bun
# The installer script handles all platform-specific setup
installer_script=$(curl -fsSL https://bun.sh/install)
if echo "${installer_script}" | bash; then
  echo "[Bun] [OK] Installation successful"
  echo "[Bun] Runtime installed to ~/.bun/bin/bun"

  # Symlink to ~/.local/bin so it's in PATH without modifying shell configs
  # (since ~/.local/bin is already in PATH via .profile)
  mkdir -p "${HOME}/.local/bin"
  ln -sf "${bun_binary_path}" "${HOME}/.local/bin/bun"
  ln -sf "${HOME}/.bun/bin/bunx" "${HOME}/.local/bin/bunx"
  echo "[Bun] Symlinked to ~/.local/bin for PATH access"

  # Verify the installation
  if [[ -x "${bun_binary_path}" ]]; then
    bun_version=$("${bun_binary_path}" --version 2> /dev/null || echo "version check failed")
    echo "[Bun] Version: ${bun_version}"
  fi
else
  echo "[Bun] [ERROR] Installation failed"
  exit 1
fi
