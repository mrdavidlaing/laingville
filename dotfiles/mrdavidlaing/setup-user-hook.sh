#!/usr/bin/env bash
set -euo pipefail

# Check if current login shell contains bash
current_shell=$(getent passwd "$USER" | cut -d: -f7)

if [[ "$current_shell" != *"bash"* ]]; then
  echo "Error: Your login shell is not bash" >&2
  echo "Current shell: $current_shell" >&2
  echo "To fix this, run: chsh -s $(command -v bash)" >&2
  exit 1
fi
