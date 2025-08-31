#!/usr/bin/env bash

# Nil (Nix Language Server) Installation Script
# Installs nil language server using cargo

set -e

DRY_RUN="${1:-false}"

# Check if nil is already installed
check_nil_installation() {
  if command -v nil &> /dev/null; then
    local nil_version
    nil_version=$(nil --version 2>&1 || echo "version check failed")
    echo "[nil] Already installed: ${nil_version}"
    return 0
  fi
  return 1
}

# Check if cargo is available
check_cargo_available() {
  if ! command -v cargo &> /dev/null; then
    echo "[nil] ERROR: cargo not found. Please install Rust first:"
    echo "  macOS:  brew install rust"
    echo "  Linux:  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    return 1
  fi
  return 0
}

echo -n "[nil] "

# Check if already installed
# shellcheck disable=SC2310  # Function invocation in 'if' condition is acceptable here
if check_nil_installation; then
  exit 0
fi

# Check for cargo
# shellcheck disable=SC2310  # Function invocation in 'if' condition is acceptable here
if ! check_cargo_available; then
  exit 1
fi

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[DRY RUN] Would install nil via cargo from GitHub repository"
  exit 0
fi

echo "Installing via cargo..."

# Install nil from GitHub repository
if cargo install --git https://github.com/oxalica/nil nil; then
  echo "[nil] [OK] Installation successful"

  # Verify the installation
  if command -v nil &> /dev/null; then
    nil_version=$(nil --version 2>&1 || echo "version check failed")
    echo "[nil] Version: ${nil_version}"
  else
    echo "[nil] [WARNING] Installation succeeded but nil not found in PATH"
    echo "[nil] Make sure ~/.cargo/bin is in your PATH"
  fi
else
  echo "[nil] [ERROR] Installation failed"
  exit 1
fi
