#!/usr/bin/env bash
set -euo pipefail

# Check if current login shell contains bash (skip on Windows/Git Bash)
if [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]] || [[ -n "${WINDIR:-}" ]]; then
  # On Windows/Git Bash, we're already using bash - skip the check
  exit 0
fi

# Get current user (fallback if $USER not set)
current_user="${USER:-$(whoami)}"
current_shell=$(getent passwd "${current_user}" | cut -d: -f7)

if [[ "${current_shell}" != *"bash"* ]]; then
  echo "Error: Your login shell is not bash" >&2
  echo "Current shell: ${current_shell}" >&2
  echo "To fix this, run: chsh -s $(command -v bash)" >&2
  exit 1
fi
