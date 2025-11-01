#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate Claude Code settings from template
if [[ -x "$SCRIPT_DIR/.claude/generate-settings.sh" ]]; then
  "$SCRIPT_DIR/.claude/generate-settings.sh"
fi

# Skip check on Git Bash where this script running means we're already in bash
if [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]]; then
  exit 0
fi

# Skip check on NixOS/Nix systems where bash is in the Nix store
if [[ "${SHELL}" == /nix/store/* ]]; then
  exit 0
fi

# Skip check in Docker/container environments where shell checks are not reliable
if [[ "${DEVCONTAINER:-}" == "true" ]] || [[ -f /.dockerenv ]]; then
  exit 0
fi

# Get user's default shell cross-platform
user_shell=""
if command -v getent &> /dev/null; then
  user_shell=$(getent passwd "$USER" | cut -d: -f7)
elif command -v dscl &> /dev/null; then
  user_shell=$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')
else
  user_shell="${SHELL}"
fi

bash_path="${SHELL}"

# Check if bash is in /etc/shells
if ! grep -Fxq "${bash_path}" /etc/shells 2> /dev/null; then
  echo "Error: ${bash_path} is not in /etc/shells" >&2
  echo "To fix: echo '${bash_path}' | sudo tee -a /etc/shells" >&2
  exit 1
fi

# Check if default shell is bash
if [[ "${user_shell}" != *"/bash"* ]]; then
  echo "Error: Your login shell is not bash (current: ${user_shell})" >&2
  echo "To fix: chsh -s ${bash_path}" >&2
  exit 1
fi
