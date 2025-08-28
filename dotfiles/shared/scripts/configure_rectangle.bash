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
  echo "* Would: configure Meta + number key shortcuts for width ratios"
  echo "* Would: configure Meta + Enter for maximize"
  echo "* Would: configure Meta + Shift for multi-monitor"
  exit 0
fi

echo "Configuring Rectangle with number key width ratios..."

# Stop Rectangle to allow configuration changes
osascript -e 'tell application "Rectangle" to quit' 2> /dev/null || true
sleep 1

# Basic settings
defaults write com.knollsoft.Rectangle allowAnyShortcut -bool true
defaults write com.knollsoft.Rectangle alternateDefaultShortcuts -bool false
defaults write com.knollsoft.Rectangle subsequentExecutionMode -int 2

# Maximize: ⌘ + Enter
defaults write com.knollsoft.Rectangle maximize -dict \
  keyCode -int 36 \
  modifierFlags -int 1048576

# Width positioning using number keys: ⌘ + 1/2/3/4
# Left Half: ⌘ + 1 (left 1/2)
defaults write com.knollsoft.Rectangle leftHalf -dict \
  keyCode -int 18 \
  modifierFlags -int 1048576

# First Three-Quarters: ⌘ + 2 (left 3/4)
defaults write com.knollsoft.Rectangle firstThreeFourths -dict \
  keyCode -int 19 \
  modifierFlags -int 1048576

# Right Half: ⌘ + 3 (right 1/2)
defaults write com.knollsoft.Rectangle rightHalf -dict \
  keyCode -int 20 \
  modifierFlags -int 1048576

# Last Fourth: ⌘ + 4 (right 1/4)
defaults write com.knollsoft.Rectangle lastFourth -dict \
  keyCode -int 21 \
  modifierFlags -int 1048576

# Multi-monitor movement - Shift + Command + Arrow
# Next Display: ⌘ + Shift + Right Arrow
defaults write com.knollsoft.Rectangle nextDisplay -dict \
  keyCode -int 124 \
  modifierFlags -int 1179648

# Previous Display: ⌘ + Shift + Left Arrow
defaults write com.knollsoft.Rectangle previousDisplay -dict \
  keyCode -int 123 \
  modifierFlags -int 1179648

# Restart Rectangle to apply changes
open -a Rectangle
sleep 1

echo "Rectangle configuration complete."
echo ""
echo "New shortcuts:"
echo "  ⌘ + Enter         - Maximize"
echo "  ⌘ + 1/2/3/4       - Width ratios: Left 1/2, Left 3/4, Right 1/2, Right 1/4"
echo "  ⌘ + Shift + Left/Right - Multi-monitor movement"
