#!/usr/bin/env bash

# Cleanup legacy beads/bd installs that can shadow the Homebrew-managed `bd`.
# Historically `bd` was installed into ~/.local/bin via the official installer (or other methods).
# Our shell profile prepends ~/.local/bin, so that legacy binary can override /opt/homebrew/bin/bd.

set -euo pipefail

DRY_RUN="${1:-false}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  if [[ "${DRY_RUN}" = true ]]; then
    echo "BEADS CLEANUP:"
    echo "* Would: skip (not macOS)"
  else
    echo "Skipping beads cleanup (not macOS)"
  fi
  exit 0
fi

legacy_bd="${HOME}/.local/bin/bd"

if [[ "${DRY_RUN}" = true ]]; then
  echo "BEADS CLEANUP:"
  echo "* Would: remove legacy ${legacy_bd} if Homebrew bd is installed"
  exit 0
fi

# Only perform cleanup if Homebrew-managed bd exists
if ! command -v brew > /dev/null 2>&1; then
  echo "Skipping beads cleanup (brew not found)."
  exit 0
fi

if ! brew list --formula --quiet steveyegge/beads/bd > /dev/null 2>&1; then
  # Homebrew bd not installed; don't delete anything.
  echo "Skipping beads cleanup (Homebrew bd not installed)."
  exit 0
fi

brew_bd="$(brew --prefix steveyegge/beads/bd)/bin/bd"

if [[ ! -e "${legacy_bd}" ]]; then
  echo "No legacy bd at ${legacy_bd}."
  exit 0
fi

rm -f "${legacy_bd}"
echo "Removed legacy bd at ${legacy_bd} (use Homebrew bd at ${brew_bd})."
