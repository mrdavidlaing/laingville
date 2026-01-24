#!/usr/bin/env bash

# Perles Installation Script
# Installs perles (Beads TUI) from GitHub releases to ~/.local/bin

set -e

DRY_RUN="${1:-false}"
REPO="zjrosen/perles"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[Perles] [DRY RUN] Would install perles from GitHub releases"
  exit 0
fi

echo -n "[Perles] "

# Path to target binary
binary_path="${HOME}/.local/bin/perles"

# Ensure ~/.local/bin exists
mkdir -p "${HOME}/.local/bin"

# Determine OS and Architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "${ARCH}" in
  x86_64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *)
    echo "[ERROR] Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

# Check if jq is available, if not we might need a simpler way to parse JSON
if ! command -v jq &> /dev/null; then
  echo "[ERROR] jq is required for this installation script"
  exit 1
fi

# Get latest release version and download URL
echo "Fetching latest release info..."
latest_release_json=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
VERSION=$(echo "${latest_release_json}" | jq -r .tag_name | sed 's/^v//')
DOWNLOAD_URL=$(echo "${latest_release_json}" | jq -r ".assets[] | select(.name | contains(\"${OS}\") and contains(\"${ARCH}\") and endswith(\".tar.gz\")) | .browser_download_url")

if [[ -z "${DOWNLOAD_URL}" || "${DOWNLOAD_URL}" == "null" ]]; then
  echo "[ERROR] Could not find download URL for ${OS}/${ARCH}"
  exit 1
fi

# Check if we already have this version
if [[ -x "${binary_path}" ]]; then
  # Some binaries don't support --version or need to be in a git repo to report it correctly
  # For now, we'll just report that we are installing/updating
  echo "Updating to v${VERSION}..."
else
  echo "Installing v${VERSION}..."
fi

echo "Downloading from ${DOWNLOAD_URL}..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/perles.tar.gz"
tar -xzf "${TMP_DIR}/perles.tar.gz" -C "${TMP_DIR}"

# Find the binary in the extracted files (BSD find compatible - no -executable flag)
EXTRACTED_BINARY=$(find "${TMP_DIR}" -type f -name "perles" | head -n 1)

if [[ -z "${EXTRACTED_BINARY}" ]]; then
  echo "[ERROR] Could not find perles binary in extracted archive"
  exit 1
fi

mv "${EXTRACTED_BINARY}" "${binary_path}"
chmod +x "${binary_path}"

echo "[Perles] [OK] Installation successful: ${binary_path}"
