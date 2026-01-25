#!/bin/bash
set -e

echo "Installing pensive-assistant feature (Ubuntu mode)..."

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    BINARY_ARCH="amd64"
    ;;
  aarch64 | arm64)
    BINARY_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

TARGET_USER="${_REMOTE_USER:-}"
if [ -z "$TARGET_USER" ]; then
  for user in vscode coder node; do
    if id "$user" > /dev/null 2>&1; then
      TARGET_USER="$user"
      break
    fi
  done
fi

if [ -z "$TARGET_USER" ]; then
  echo "Error: Could not determine target user"
  exit 1
fi

REMOTE_HOME=$(grep "^${TARGET_USER}:" /etc/passwd | cut -d: -f6)
if [ -z "$REMOTE_HOME" ] || [ ! -d "$REMOTE_HOME" ]; then
  echo "Error: Could not determine home directory for user ${TARGET_USER}"
  exit 1
fi

echo "Setting up tools for user ${TARGET_USER} (home: ${REMOTE_HOME})..."
mkdir -p "${REMOTE_HOME}/.local/bin"

install_beads() {
  echo "Installing beads (bd)..."
  local version="${BEADS_VERSION:-latest}"

  if [ "$version" = "latest" ]; then
    local latest_tag=$(curl -fsSL https://api.github.com/repos/steveyegge/beads/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    version="${latest_tag#v}"
  else
    version="${version#v}"
  fi

  local archive="beads_${version}_linux_${BINARY_ARCH}.tar.gz"
  local url="https://github.com/steveyegge/beads/releases/download/v${version}/${archive}"

  curl -fsSL "$url" | tar -xz -C "${REMOTE_HOME}/.local/bin" bd
  chmod +x "${REMOTE_HOME}/.local/bin/bd"
  echo "  ✓ beads ${version} installed"
}

install_zellij() {
  echo "Installing zellij..."

  local version="${ZELLIJ_VERSION:-latest}"
  local url

  if [ "$version" = "latest" ]; then
    local latest_tag=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    version="${latest_tag#v}"
    url="https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-${ARCH}-unknown-linux-musl.tar.gz"
  else
    version="${version#v}"
    url="https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-${ARCH}-unknown-linux-musl.tar.gz"
  fi

  curl -fsSL "$url" | tar -xz -C "${REMOTE_HOME}/.local/bin" zellij
  chmod +x "${REMOTE_HOME}/.local/bin/zellij"

  echo "  ✓ zellij ${version} installed"
}

install_lazygit() {
  echo "Installing lazygit..."

  local lazygit_arch
  case "$ARCH" in
    x86_64)
      lazygit_arch="x86_64"
      ;;
    aarch64 | arm64)
      lazygit_arch="arm64"
      ;;
    *)
      echo "Unsupported architecture for lazygit: $ARCH"
      return 1
      ;;
  esac

  local version="${LAZYGIT_VERSION:-latest}"

  if [ "$version" = "latest" ]; then
    local latest_tag=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    version="${latest_tag#v}"
  else
    version="${version#v}"
  fi

  local archive="lazygit_${version}_linux_${lazygit_arch}.tar.gz"
  local url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/${archive}"

  curl -fsSL "$url" | tar -xz -C "${REMOTE_HOME}/.local/bin" lazygit
  chmod +x "${REMOTE_HOME}/.local/bin/lazygit"

  echo "  ✓ lazygit ${version} installed"
}

install_bun() {
  echo "Installing bun..."

  export BUN_INSTALL="${REMOTE_HOME}/.bun"
  curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1

  chown -R "${TARGET_USER}:${TARGET_USER}" "${REMOTE_HOME}/.bun"

  local bun_version=$("${REMOTE_HOME}/.bun/bin/bun" --version)
  echo "  ✓ bun ${bun_version} installed"
}

install_opencode() {
  echo "Installing OpenCode..."

  if [ -x "${REMOTE_HOME}/.bun/bin/bun" ]; then
    "${REMOTE_HOME}/.bun/bin/bun" add -g opencode-ai > /dev/null 2>&1
    chown -R "${TARGET_USER}:${TARGET_USER}" "${REMOTE_HOME}/.bun"

    local opencode_version=$("${REMOTE_HOME}/.bun/bin/opencode" --version 2> /dev/null | head -1)
    echo "  ✓ OpenCode ${opencode_version} installed"
  else
    echo "  ⚠ Warning: bun not found, skipping OpenCode installation"
  fi
}

install_claude_code() {
  echo "Installing Claude Code..."

  if [ -x "${REMOTE_HOME}/.bun/bin/bun" ]; then
    "${REMOTE_HOME}/.bun/bin/bun" install -g @anthropic-ai/claude-code > /dev/null 2>&1
    chown -R "${TARGET_USER}:${TARGET_USER}" "${REMOTE_HOME}/.bun"

    local claude_version=$("${REMOTE_HOME}/.bun/bin/claude" --version 2> /dev/null | head -1)
    echo "  ✓ Claude Code ${claude_version} installed"
  else
    echo "  ⚠ Warning: bun not found, skipping Claude Code installation"
  fi
}

add_to_path() {
  echo "Adding tools to PATH..."

  cat >> "${REMOTE_HOME}/.bashrc" << 'BASHEOF'

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
BASHEOF

  cat >> "${REMOTE_HOME}/.profile" << 'PROFILEOF'

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
PROFILEOF

  echo "  ✓ PATH updated in ~/.bashrc and ~/.profile"
}

install_beads
install_zellij
install_lazygit
install_bun
install_opencode
install_claude_code
add_to_path

chown -R "${TARGET_USER}:${TARGET_USER}" "${REMOTE_HOME}/.local"
chown -R "${TARGET_USER}:${TARGET_USER}" "${REMOTE_HOME}/.bun" 2> /dev/null || true

echo ""
echo "✓ pensive-assistant feature installed successfully (Ubuntu mode)!"
echo ""
echo "Available tools:"
echo "  bd         - Issue tracking (beads)"
echo "  zellij     - Terminal multiplexer"
echo "  lazygit    - Git TUI"
echo "  bun        - JavaScript runtime and toolkit"
echo "  opencode   - OpenCode AI CLI (context-aware AI coding assistant)"
echo "  claude     - Claude Code CLI (Anthropic's official CLI)"
echo ""
echo "Restart your shell or run: source ~/.bashrc"
