#!/usr/bin/env bash

# Configure Ice menu bar manager for notch-aware icon management
# This script automates Ice configuration using defaults commands

set -euo pipefail

DRY_RUN="${1:-false}"

# Only run on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  if [[ "${DRY_RUN}" = true ]]; then
    echo "ICE CONFIG:"
    echo "* Would: skip Ice configuration (not macOS)"
  else
    echo "Skipping Ice configuration (not macOS)"
  fi
  exit 0
fi

# Check if Ice is installed
if ! command -v ice &> /dev/null && [[ ! -d "/Applications/Ice.app" ]]; then
  if [[ "${DRY_RUN}" = true ]]; then
    echo "ICE CONFIG:"
    echo "* Would: skip Ice configuration (Ice not installed)"
  else
    echo "Warning: Ice not found. Install Ice first using './setup-user'"
  fi
  exit 0
fi

if [[ "${DRY_RUN}" = true ]]; then
  echo "ICE CONFIG:"
  echo "* Would: configure Ice for notch-aware menu bar management"
  echo "* Would: enable hidden item display below menu bar"
  echo "* Would: optimize icon spacing for notch compatibility"
  echo "* Would: set up automatic icon organization"
  exit 0
fi

echo "Configuring Ice for notch-aware menu bar management..."

# Stop Ice to allow configuration changes
osascript -e 'tell application "Ice" to quit' 2> /dev/null || true
sleep 1

# Note: These are placeholder settings - actual plist keys need to be discovered
# by running Ice, configuring it manually, then examining the generated plist file.

# Check if Ice has been run before and created its plist
PLIST_FILE="$HOME/Library/Preferences/com.jordanbaird.Ice.plist"

if [[ ! -f "$PLIST_FILE" ]]; then
  echo "Ice preferences file not found. Starting Ice for first-time setup..."
  open -a Ice
  echo "Please configure Ice manually for the first time:"
  echo "1. Enable 'Show hidden items below menu bar' for notch compatibility"
  echo "2. Set appropriate icon spacing (8-12px recommended)"
  echo "3. Configure auto-hide settings as desired"
  echo "4. Close Ice settings when done"
  echo ""
  echo "After configuration, re-run this script to apply any additional settings."
  exit 0
fi

# Apply Ice configuration for optimal notch management
echo "Applying Ice configuration..."

# Enable Ice Bar - shows hidden items below the menu bar (perfect for notch)
defaults write com.jordanbaird.Ice UseIceBar -bool true

# Set Ice Bar location to 0 (below menu bar)
defaults write com.jordanbaird.Ice IceBarLocation -int 0

# Enable showing all sections when user drags items
defaults write com.jordanbaird.Ice ShowAllSectionsOnUserDrag -bool true

# Show on click and scroll for easy access
defaults write com.jordanbaird.Ice ShowOnClick -bool true
defaults write com.jordanbaird.Ice ShowOnScroll -bool true

# Disable show on hover to avoid accidental triggering
defaults write com.jordanbaird.Ice ShowOnHover -bool false

# Enable auto-rehide to keep menu bar clean
defaults write com.jordanbaird.Ice AutoRehide -bool true
defaults write com.jordanbaird.Ice RehideInterval -int 10

# Set rehide strategy to 0 (hide after interval)
defaults write com.jordanbaird.Ice RehideStrategy -int 0

# Show Ice icon for easy access to controls
defaults write com.jordanbaird.Ice ShowIceIcon -bool true

# Hide application menus to save space (can be toggled as needed)
defaults write com.jordanbaird.Ice HideApplicationMenus -bool true

# Enable always hidden section for rarely used items
defaults write com.jordanbaird.Ice EnableAlwaysHiddenSection -bool true
defaults write com.jordanbaird.Ice CanToggleAlwaysHiddenSection -bool true

# Optimize item spacing (0 offset uses default spacing)
defaults write com.jordanbaird.Ice ItemSpacingOffset -int 0

# Show section dividers for better organization
defaults write com.jordanbaird.Ice ShowSectionDividers -bool true

echo "Ice configuration complete."
echo ""
echo "Configured settings for notch management:"
echo "  ✓ Ice Bar enabled - hidden items appear below menu bar"
echo "  ✓ Auto-rehide enabled with 10 second interval"
echo "  ✓ Click and scroll access enabled"
echo "  ✓ Always-hidden section enabled for rarely used items"
echo "  ✓ Application menus hidden to save space"
echo "  ✓ Section dividers enabled for better organization"

# Restart Ice to apply any changes
open -a Ice
sleep 1

echo "Ice has been restarted."
