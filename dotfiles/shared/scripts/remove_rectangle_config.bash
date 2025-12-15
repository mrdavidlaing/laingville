#!/usr/bin/env bash

# Remove Rectangle (com.knollsoft.Rectangle) persisted configuration on macOS.
# Useful after migrating from Rectangle to AeroSpace to avoid lingering shortcuts/settings.

set -euo pipefail

DRY_RUN="${1:-false}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  if [[ "${DRY_RUN}" = true ]]; then
    echo "RECTANGLE CLEANUP:"
    echo "* Would: skip (not macOS)"
  else
    echo "Skipping Rectangle cleanup (not macOS)"
  fi
  exit 0
fi

domain="com.knollsoft.Rectangle"
plist="${HOME}/Library/Preferences/${domain}.plist"

if [[ "${DRY_RUN}" = true ]]; then
  echo "RECTANGLE CLEANUP:"
  echo "* Would: quit Rectangle if running"
  echo "* Would: defaults delete ${domain}"
  echo "* Would: remove ${plist}"
  exit 0
fi

osascript -e 'tell application "Rectangle" to quit' 2> /dev/null || true

# Remove persisted defaults for the domain (ignore if already absent)
defaults delete "${domain}" 2> /dev/null || true

# Remove preference plist if present (ignore if absent)
rm -f "${plist}" 2> /dev/null || true

echo "Rectangle configuration removed (if present)."
