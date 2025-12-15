#!/usr/bin/env bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate Claude Code settings from template
if [[ -x "$SCRIPT_DIR/.claude/generate-settings.sh" ]]; then
  "$SCRIPT_DIR/.claude/generate-settings.sh"
fi

# Ensure SSH includes GitHub multi-account config (1Password SSH Agent).
# This keeps private keys in 1Password while letting OpenSSH pick a specific
# key using the corresponding public key in IdentityFile.
ssh_include_file="$HOME/.ssh/github-1password.conf"
ssh_config_file="$HOME/.ssh/config"
ssh_include_line="Include ~/.ssh/github-1password.conf"
if [[ -f "$ssh_include_file" ]]; then
  mkdir -p "$HOME/.ssh"
  touch "$ssh_config_file"
  if ! grep -Fxq "$ssh_include_line" "$ssh_config_file"; then
    tmp="$(mktemp)"
    printf "%s\n\n" "$ssh_include_line" > "$tmp"
    cat "$ssh_config_file" >> "$tmp"
    mv "$tmp" "$ssh_config_file"
  fi
fi

# macOS: Load workday LaunchAgents on mo-inator only
if [[ "$(uname)" == "Darwin" ]]; then
  hostname_short=$(scutil --get ComputerName 2> /dev/null || hostname -s 2> /dev/null || echo "unknown")
  if [[ "$hostname_short" == "mo-inator" ]]; then
    echo "Loading workday LaunchAgents for mo-inator..."
    # Load countdown agent (17:45 warning)
    if [[ -f "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist" ]]; then
      launchctl unload "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist" 2> /dev/null || true
      launchctl load "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist"
      echo "  Loaded: workday-countdown (17:45 Mon-Fri)"
    fi
    # Load suspend agent (18:00 sleep)
    if [[ -f "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-suspend.plist" ]]; then
      launchctl unload "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-suspend.plist" 2> /dev/null || true
      launchctl load "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-suspend.plist"
      echo "  Loaded: workday-suspend (18:00 Mon-Fri)"
    fi
  else
    # On other Macs, ensure workday agents are NOT loaded
    launchctl unload "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-countdown.plist" 2> /dev/null || true
    launchctl unload "$HOME/Library/LaunchAgents/com.mrdavidlaing.workday-suspend.plist" 2> /dev/null || true
  fi
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
