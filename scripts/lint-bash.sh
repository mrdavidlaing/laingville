#!/bin/bash
# Lint all bash scripts using shellcheck (batched for performance)
#
# This script finds and lints:
# - Standard shell scripts (*.sh, *.bash) in the project
# - Claude automation scripts and executables
# - Core setup scripts
#
# Excludes: .git directories, hidden dotfiles

set -euo pipefail

# Check if shellcheck is available
check_shellcheck() {
  if ! command -v shellcheck > /dev/null 2>&1; then
    echo "⚠️  shellcheck not found. Please install shellcheck to run linting."
    echo "    macOS: brew install shellcheck"
    echo "    Ubuntu/Debian: apt install shellcheck"
    exit 1
  fi
}

# Find standard shell scripts, excluding version control and hidden dotfiles
find_standard_scripts() {
  find . -type f \( -name "*.sh" -o -name "*.bash" \) \
    -not -path "./.git/*" \
    -not -path "./dotfiles/*/.*" \
    2> /dev/null || true
}

# Find Claude automation scripts (bash files and executable scripts)
find_claude_scripts() {
  # Auto-detect current user's Claude directory
  local claude_dir
  if [[ -d "./dotfiles/$USER/.claude" ]]; then
    claude_dir="./dotfiles/$USER/.claude"
  elif [[ -d "./dotfiles/mrdavidlaing/.claude" ]]; then
    claude_dir="./dotfiles/mrdavidlaing/.claude"
  else
    return 0 # No Claude directory found
  fi

  # Find bash files
  find "$claude_dir" -name "*.bash" -type f 2> /dev/null || true

  # Find executable shell scripts (check for shebang)
  find "$claude_dir" -type f -executable \
    -not -name "*.md" -not -name "*.json" \
    -exec grep -l '^#!/.*sh' {} \; 2> /dev/null || true
}

# Get core setup scripts that should always be linted
get_setup_scripts() {
  local scripts=("setup.sh")
  for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
      echo "$script"
    fi
  done
}

# Main linting function
main() {
  check_shellcheck

  echo "Discovering shell scripts to lint..."

  # Collect all scripts into an array
  local scripts=()

  # Add standard scripts
  while IFS= read -r -d '' script; do
    scripts+=("$script")
  done < <(find_standard_scripts | sort -u | tr '\n' '\0')

  # Add Claude scripts
  while IFS= read -r -d '' script; do
    scripts+=("$script")
  done < <(find_claude_scripts | sort -u | tr '\n' '\0')

  # Add setup scripts
  while IFS= read -r -d '' script; do
    scripts+=("$script")
  done < <(get_setup_scripts | sort -u | tr '\n' '\0')

  if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "⚠️  No shell scripts found to lint"
    exit 0
  fi

  echo "Found ${#scripts[@]} script(s) to lint"

  # Remove duplicates and lint all scripts
  printf '%s\n' "${scripts[@]}" | sort -u | tr '\n' '\0' \
    | xargs -0 -t shellcheck

  echo "✅ Linting complete"
}

# Run main function
main "$@"
