#!/bin/bash
set -e

echo "Installing pensive-assistant feature..."

FEATURE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARBALL_PATH="${FEATURE_DIR}/dist/pensive-tools.tar.gz"
ENV_PATH_FILE="${FEATURE_DIR}/dist/env-path"

# ============================================
# Get tarball (local or from OCI registry)
# ============================================
# Tarball is stored separately from feature metadata to avoid OCI manifest conflicts
OCI_REGISTRY="ghcr.io/mrdavidlaing/laingville/pensive-assistant-tarball"
OCI_TAG="${PENSIVE_TOOLS_VERSION:-latest}"

# Detect architecture (needed for tarball pull and oras install)
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    ORAS_ARCH="amd64"
    ;;
  aarch64 | arm64)
    ORAS_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

if [ -f "$TARBALL_PATH" ] && [ -f "$ENV_PATH_FILE" ]; then
  echo "Using local tarball from dist/"
else
  echo "Local tarball not found, pulling from OCI registry..."
  mkdir -p "${FEATURE_DIR}/dist"

  # Install oras if not available
  if ! command -v oras > /dev/null 2>&1; then
    echo "Installing oras..."
    ORAS_VERSION="1.3.0"
    case "$ORAS_ARCH" in
      amd64)
        ORAS_SHA256="6cdc692f929100feb08aa8de584d02f7bcc30ec7d88bc2adc2054d782db57c64"
        ;;
      arm64)
        ORAS_SHA256="7649738b48fde10542bcc8b0e9b460ba83936c75fb5be01ee6d4443764a14352"
        ;;
    esac
    ORAS_URL="https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_${ORAS_ARCH}.tar.gz"
    ORAS_TMP=$(mktemp)
    curl -fsSL "$ORAS_URL" -o "$ORAS_TMP"
    echo "${ORAS_SHA256}  ${ORAS_TMP}" | sha256sum -c - || {
      echo "Error: oras checksum verification failed"
      rm -f "$ORAS_TMP"
      exit 1
    }
    mkdir -p /usr/local/bin
    tar xz -C /usr/local/bin oras < "$ORAS_TMP"
    rm -f "$ORAS_TMP"
  fi

  # Pull tarball from OCI registry (architecture-specific tag)
  # Note: We pull arch-specific tags directly because oras artifact manifests
  # don't support automatic platform selection like Docker image manifests
  cd "${FEATURE_DIR}/dist"
  OCI_TAG_ARCH="${OCI_TAG}-${ORAS_ARCH}"
  if /usr/local/bin/oras pull "${OCI_REGISTRY}:${OCI_TAG_ARCH}"; then
    echo "Successfully pulled from ${OCI_REGISTRY}:${OCI_TAG_ARCH}"
  else
    echo "Error: Failed to pull from OCI registry."
    echo ""
    echo "Options:"
    echo "  1. Build locally: 'just pensive-assistant-build'"
    echo "  2. Ensure the feature is published to ${OCI_REGISTRY}"
    exit 1
  fi
  cd -
fi

if [ ! -f "$TARBALL_PATH" ] || [ ! -f "$ENV_PATH_FILE" ]; then
  echo "Error: Required files not found after pull attempt."
  exit 1
fi

ENV_PATH=$(cat "$ENV_PATH_FILE")

# ============================================
# Extract nix tools from tarball
# ============================================
echo "Extracting pensive tools from tarball..."

# Validate tarball contains only /nix/store paths (defense in depth)
if tar -tzf "$TARBALL_PATH" | grep -qvE "^nix/store/"; then
  echo "Error: Tarball contains paths outside /nix/store - refusing to extract"
  exit 1
fi

tar -xzf "$TARBALL_PATH" -C /

# Add nix tools and bun globals to PATH via profile.d (sourced by login shells and bash -l)
cat > /etc/profile.d/pensive-assistant.sh << BASHEOF
# pensive-assistant tools
export PATH="${ENV_PATH}/bin:\$HOME/.bun/bin:\$PATH"
BASHEOF
chmod +x /etc/profile.d/pensive-assistant.sh

# Also add to bashrc for interactive non-login shells
cat >> /etc/bash.bashrc << BASHEOF

# pensive-assistant tools
export PATH="${ENV_PATH}/bin:\$HOME/.bun/bin:\$PATH"
BASHEOF

# ============================================
# Install Claude Code via bun
# ============================================
echo "Installing Claude Code..."
if command -v bun > /dev/null 2>&1; then
  bun install -g @anthropic-ai/claude-code
  echo "Claude Code installed via bun"
else
  echo "Warning: bun not found, skipping Claude Code installation"
fi

# ============================================
# Set up user tools in ~/.local/bin
# ============================================
TARGET_USER="${_REMOTE_USER:-}"
if [ -z "$TARGET_USER" ]; then
  for user in vscode coder node; do
    if id "$user" > /dev/null 2>&1; then
      TARGET_USER="$user"
      break
    fi
  done
fi

if [ -n "$TARGET_USER" ]; then
  REMOTE_HOME=$(grep "^${TARGET_USER}:" /etc/passwd | cut -d: -f6)
  if [ -n "$REMOTE_HOME" ] && [ -d "$REMOTE_HOME" ]; then
    echo "Setting up tools for user ${TARGET_USER}..."
    mkdir -p "${REMOTE_HOME}/.local/bin"

    # Symlink nix tools to ~/.local/bin
    for tool in bd zellij lazygit; do
      if [ -x "${ENV_PATH}/bin/${tool}" ]; then
        ln -sf "${ENV_PATH}/bin/${tool}" "${REMOTE_HOME}/.local/bin/${tool}"
        echo "  Linked ${tool}"
      fi
    done

    chown -R "${TARGET_USER}:${TARGET_USER}" "${REMOTE_HOME}/.local"
  fi
fi

echo ""
echo "pensive-assistant feature installed successfully!"
echo ""
echo "Available tools:"
echo "  beads (bd)  - Issue tracking"
echo "  zellij      - Terminal multiplexer"
echo "  lazygit     - Git TUI"
echo "  claude      - AI coding assistant"
