#!/usr/bin/env bash
set -euo pipefail
DRY=false
if [ "${1-}" = "--dry-run" ]; then
  DRY=true
fi
shell_bin=$(command -v bash || true)
if [ -n "${shell_bin}" ]; then
  if $DRY; then
    echo "Would set login shell to: ${shell_bin}"
  else
    chsh -s "${shell_bin}" "$USER"
  fi
else
  echo "Warning: bash not found in PATH" >&2
fi
