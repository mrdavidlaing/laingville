#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  source ./lib/setup-user.functions.bash
}

@test "user symlinks only include dot-prefixed files and dirs" {
  export DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing" && pwd)"
  run ./bin/setup-user --dry-run
  [ "$status" -eq 0 ]

  # Extract all symlink lines and check each target starts with a dot
  local non_dotfile_symlinks=()
  while IFS= read -r line; do
    if [[ "$line" =~ Would\ (create|update):\ ~/([^\ ]+) ]]; then
      local target="${BASH_REMATCH[2]}"
      local first_component="${target%%/*}"  # Get first part before any /
      
      if [[ ! "$first_component" =~ ^\. ]]; then
        non_dotfile_symlinks+=("$line")
      fi
    fi
  done <<< "$output"
  
  # Report any non-dotfile symlinks found
  if [ ${#non_dotfile_symlinks[@]} -gt 0 ]; then
    echo "FAILED: Found symlinks to non-dotfiles (files/dirs not starting with '.'):"
    for symlink in "${non_dotfile_symlinks[@]}"; do
      echo "  $symlink"
    done
    return 1
  fi
}
