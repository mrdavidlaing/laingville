#!/usr/bin/env bash

# Test script for separated packages.yaml and symlinks.yaml approach

set -e

# Source functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shared.functions.bash"
source "$SCRIPT_DIR/lib/logging.functions.bash"
source "$SCRIPT_DIR/lib/symlinks.functions.bash"

# Test parsing symlinks from separated file
test_separated_symlinks() {
  local symlinks_yml="$1"

  echo "=== Testing separated symlinks.yaml parsing ==="
  echo

  for platform in arch wsl windows macos; do
    echo "Platform: $platform"
    echo "-------------------"

    local symlinks
    symlinks=$(parse_symlinks_from_yaml "$symlinks_yml" "$platform")

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

# Compare packages.yaml files (old vs clean)
test_packages_cleanup() {
  local old_packages="$1"
  local clean_packages="$2"

  echo "=== Packages file comparison ==="
  echo

  # Count lines
  local old_lines=$(wc -l < "$old_packages")
  local clean_lines=$(wc -l < "$clean_packages")

  echo "Old packages.yaml: $old_lines lines"
  echo "Clean packages.yaml: $clean_lines lines"
  echo "Reduction: $((old_lines - clean_lines)) lines"
  echo

  # Check for symlinks sections in clean file
  if grep -q "symlinks:" "$clean_packages" 2> /dev/null; then
    echo "❌ Clean packages.yaml still contains symlinks sections"
  else
    echo "✅ Clean packages.yaml has no symlinks sections"
  fi
  echo
}

# Test current platform symlinks
test_current_symlinks() {
  local symlinks_yml="$1"
  local platform=$(detect_platform)

  echo "=== Current Platform Symlinks: $platform ==="
  echo

  local symlinks
  symlinks=$(parse_symlinks_from_yaml "$symlinks_yml" "$platform")

  if [ -z "$symlinks" ]; then
    echo "No symlinks configured for $platform"
    return
  fi

  echo "Symlinks for $platform:"
  local count=0
  while IFS='|' read -r source target; do
    local full_source="$SCRIPT_DIR/dotfiles/mrdavidlaing/$source"
    local status=""

    if [ -e "$full_source" ]; then
      status="[EXISTS]"
    else
      status="[MISSING]"
    fi

    if [ -n "$target" ]; then
      local expanded_target=$(eval echo "$target")
      echo "  $status $source -> $expanded_target"
    else
      echo "  $status $source -> \$HOME/$source"
    fi
    ((count++))
  done <<< "$symlinks"

  echo
  echo "Total symlinks: $count"
}

# Main
main() {
  local symlinks_yml="$SCRIPT_DIR/dotfiles/mrdavidlaing/symlinks.yaml"
  local old_packages="$SCRIPT_DIR/dotfiles/mrdavidlaing/packages-old.yml"
  local clean_packages="$SCRIPT_DIR/dotfiles/mrdavidlaing/packages.yaml"

  if [ ! -f "$symlinks_yml" ]; then
    echo "Error: $symlinks_yml not found"
    exit 1
  fi

  if [ ! -f "$clean_packages" ]; then
    echo "Error: $clean_packages not found"
    exit 1
  fi

  test_separated_symlinks "$symlinks_yml"
  test_packages_cleanup "$old_packages" "$clean_packages"
  test_current_symlinks "$symlinks_yml"
}

main "$@"
