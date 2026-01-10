#!/usr/bin/env bash

# Remove Happy CLI installation
# Removes: ~/.local/share/happy-cli/ (source code)
# Removes: ~/.local/bin/happy, ~/.local/bin/happy-mcp (symlinks)

set -euo pipefail

DRY_RUN="${1:-false}"

INSTALL_DIR="${HOME}/.local/share/happy-cli"
BIN_DIR="${HOME}/.local/bin"
BINARIES=(happy happy-mcp)

if [[ "${DRY_RUN}" = true ]]; then
  echo "HAPPY CLI REMOVAL:"
  for binary in "${BINARIES[@]}"; do
    echo "* Would: remove symlink ${BIN_DIR}/${binary}"
  done
  echo "* Would: remove directory ${INSTALL_DIR}"
  exit 0
fi

echo -n "[Happy CLI] "

removed_something=false

# Remove symlinks
for binary in "${BINARIES[@]}"; do
  symlink_path="${BIN_DIR}/${binary}"
  if [[ -L "${symlink_path}" ]] || [[ -f "${symlink_path}" ]]; then
    rm -f "${symlink_path}"
    echo "[Happy CLI]   Removed: ${symlink_path}"
    removed_something=true
  fi
done

# Remove install directory
if [[ -d "${INSTALL_DIR}" ]]; then
  rm -rf "${INSTALL_DIR}"
  echo "[Happy CLI]   Removed: ${INSTALL_DIR}"
  removed_something=true
fi

if [[ "${removed_something}" = true ]]; then
  echo "[Happy CLI] [OK] Removal complete"
else
  echo "[Happy CLI] [OK] Nothing to remove (not installed)"
fi
