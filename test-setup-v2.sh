#!/usr/bin/env bash

# Test script for the new declarative symlinks approach

set -e

# Source functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shared.functions.bash"
source "$SCRIPT_DIR/lib/logging.functions.bash"
source "$SCRIPT_DIR/lib/symlinks.functions.bash"

# Test parsing symlinks for different platforms
test_parse_symlinks() {
  local packages_yml="$1"

  echo "=== Testing symlinks parsing for packages-v2.yml ==="
  echo

  for platform in arch wsl windows macos; do
    echo "Platform: $platform"
    echo "-------------------"

    local symlinks
    symlinks=$(parse_symlinks_from_yaml "$packages_yml" "$platform")

    if [ -z "$symlinks" ]; then
      echo "  No symlinks configured"
    else
      echo "$symlinks" | while IFS='|' read -r source target; do
        if [ -n "$target" ]; then
          echo "  $source -> $target (custom)"
        else
          echo "  $source -> (default)"
        fi
      done
    fi
    echo
  done
}

# Test what would be symlinked on current platform
test_current_platform() {
  local packages_yml="$1"
  local platform=$(detect_platform)

  echo "=== Current Platform: $platform ==="
  echo

  local symlinks
  symlinks=$(parse_symlinks_from_yaml "$packages_yml" "$platform")

  if [ -z "$symlinks" ]; then
    echo "No symlinks configured for $platform"
    return
  fi

  echo "Symlinks that would be created:"
  echo "$symlinks" | while IFS='|' read -r source target; do
    local full_source="$SCRIPT_DIR/dotfiles/mrdavidlaing/$source"

    # Check if source exists
    local status=""
    if [ -e "$full_source" ]; then
      status="[EXISTS]"
    else
      status="[MISSING]"
    fi

    if [ -n "$target" ]; then
      # Expand environment variables for display
      local expanded_target=$(eval echo "$target")
      echo "  $status $source -> $expanded_target"
    else
      echo "  $status $source -> \$HOME/$source"
    fi
  done
}

# Main
main() {
  local packages_yml="$SCRIPT_DIR/dotfiles/mrdavidlaing/packages-v2.yml"

  if [ ! -f "$packages_yml" ]; then
    echo "Error: $packages_yml not found"
    exit 1
  fi

  test_parse_symlinks "$packages_yml"
  test_current_platform "$packages_yml"
}

main "$@"
