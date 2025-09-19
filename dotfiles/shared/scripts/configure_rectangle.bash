#!/usr/bin/env bash

# Configure Rectangle window manager with Windows-like shortcuts
# This script automates Rectangle configuration using defaults commands

set -euo pipefail

DRY_RUN="${1:-false}"

# Only run on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  if [[ "${DRY_RUN}" = true ]]; then
    echo "RECTANGLE CONFIG:"
    echo "* Would: skip Rectangle configuration (not macOS)"
  else
    echo "Skipping Rectangle configuration (not macOS)"
  fi
  exit 0
fi

if [[ "${DRY_RUN}" = true ]]; then
  echo "RECTANGLE CONFIG:"
  echo "* Would: configure Ctrl + Shift + number key shortcuts for width ratios"
  echo "* Would: configure Ctrl + Shift + M for maximize"
  echo "* Would: configure Ctrl + Shift + Arrow for multi-monitor"
  exit 0
fi

echo "Configuring Rectangle with Ctrl+Shift shortcuts..."

# Stop Rectangle to allow configuration changes
osascript -e 'tell application "Rectangle" to quit' 2> /dev/null || true
sleep 1

# Basic settings
defaults write com.knollsoft.Rectangle allowAnyShortcut -bool true
defaults write com.knollsoft.Rectangle alternateDefaultShortcuts -bool false
defaults write com.knollsoft.Rectangle subsequentExecutionMode -int 2

# Maximize: Ctrl + Shift + M
defaults write com.knollsoft.Rectangle maximize -dict \
  keyCode -int 46 \
  modifierFlags -int 393216

# Width positioning using number keys: Ctrl + Shift + 1/2/3/4
# Left Half: Ctrl + Shift + 1 (left 1/2)
defaults write com.knollsoft.Rectangle leftHalf -dict \
  keyCode -int 18 \
  modifierFlags -int 393216

# First Three-Quarters: Ctrl + Shift + 2 (left 3/4)
defaults write com.knollsoft.Rectangle firstThreeFourths -dict \
  keyCode -int 19 \
  modifierFlags -int 393216

# Right Half: Ctrl + Shift + 3 (right 1/2)
defaults write com.knollsoft.Rectangle rightHalf -dict \
  keyCode -int 20 \
  modifierFlags -int 393216

# Last Fourth: Ctrl + Shift + 4 (right 1/4)
defaults write com.knollsoft.Rectangle lastFourth -dict \
  keyCode -int 21 \
  modifierFlags -int 393216

# Multi-monitor movement - Ctrl + Shift + Arrow
# Next Display: Ctrl + Shift + Right Arrow
defaults write com.knollsoft.Rectangle nextDisplay -dict \
  keyCode -int 124 \
  modifierFlags -int 393216

# Previous Display: Ctrl + Shift + Left Arrow
defaults write com.knollsoft.Rectangle previousDisplay -dict \
  keyCode -int 123 \
  modifierFlags -int 393216

# Disable conflicting shortcuts by removing their key bindings
# Remove centerThird to avoid conflicts with other apps
defaults delete com.knollsoft.Rectangle centerThird 2> /dev/null || true

# Restart Rectangle to apply changes
open -a Rectangle
sleep 1

echo "Rectangle configuration complete."
echo ""
echo "New shortcuts:"
echo "  Ctrl + Shift + M             - Maximize"
echo "  Ctrl + Shift + 1/2/3/4       - Width ratios: Left 1/2, Left 3/4, Right 1/2, Right 1/4"
echo "  Ctrl + Shift + Left/Right    - Multi-monitor movement"
