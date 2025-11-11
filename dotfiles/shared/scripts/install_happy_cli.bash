#!/usr/bin/env bash

# Happy CLI Installation Script
# Clones happy-cli from GitHub and builds from source
# Installs to: ~/.local/share/happy-cli/
# Symlinks binaries to: ~/.local/bin/

set -e

DRY_RUN="${1:-false}"

INSTALL_DIR="${HOME}/.local/share/happy-cli"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/slopus/happy-cli.git"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[Happy CLI] [DRY RUN] Would clone ${REPO_URL} to ${INSTALL_DIR}"
  echo "[Happy CLI] [DRY RUN] Would build with yarn and symlink binaries to ${BIN_DIR}"
  exit 0
fi

echo -n "[Happy CLI] "

# Check if git is available
if ! command -v git &> /dev/null; then
  echo "[ERROR] git is not installed. Please install git first."
  exit 1
fi

# Check if yarn is available (required by happy-cli)
if ! command -v yarn &> /dev/null; then
  echo "[ERROR] yarn is not installed. Please install yarn first."
  echo "[Happy CLI] Install with: npm install -g yarn"
  exit 1
fi

# Check if already installed - if so, update instead of fresh install
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "Updating to latest version from GitHub main branch..."
else
  echo "Installing from GitHub main branch..."
fi

# Create parent directory if needed
mkdir -p "$(dirname "${INSTALL_DIR}")"

# Clone or update the repository
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "[Happy CLI] Repository already cloned, updating..."
  cd "${INSTALL_DIR}"
  git fetch origin
  git reset --hard origin/main
else
  echo "[Happy CLI] Cloning repository..."
  git clone "${REPO_URL}" "${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
fi

echo "[Happy CLI] Installing dependencies..."
if ! yarn install; then
  echo "[Happy CLI] [ERROR] Failed to install dependencies"
  exit 1
fi

echo "[Happy CLI] Building from source..."
if ! yarn build; then
  echo "[Happy CLI] [ERROR] Build failed"
  exit 1
fi

echo "[Happy CLI] Creating symlinks..."

# Ensure bin directory exists
mkdir -p "${BIN_DIR}"

# Create symlinks for the binaries
for binary in happy happy-mcp; do
  binary_path="${INSTALL_DIR}/bin/${binary}.mjs"
  symlink_path="${BIN_DIR}/${binary}"

  if [[ -f "${binary_path}" ]]; then
    ln -sf "${binary_path}" "${symlink_path}"
    chmod +x "${symlink_path}"
    echo "[Happy CLI]   ✓ Linked ${binary} -> ${symlink_path}"
  else
    echo "[Happy CLI]   ⚠ Warning: ${binary_path} not found"
  fi
done

echo "[Happy CLI] [OK] Installation successful"

# Verify the installation
if command -v happy &> /dev/null; then
  happy_version=$(happy --version 2> /dev/null | head -n 1 || echo "version check failed")
  echo "[Happy CLI] Version: ${happy_version}"
  echo "[Happy CLI] Location: ${INSTALL_DIR}"
  echo "[Happy CLI] To update: cd ${INSTALL_DIR} && git pull && yarn install && yarn build"
else
  echo "[Happy CLI] [WARNING] Installation completed but 'happy' command not found in PATH"
  echo "[Happy CLI] Ensure ${BIN_DIR} is in your PATH"
fi
