Describe "setup-user dotfile filtering"
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
Before "source ./lib/setup-user.functions.bash"

Describe "user symlinks filtering"
It "only includes dot-prefixed files and dirs"
export DOTFILES_DIR
DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"

When call ./bin/setup-user --dry-run

The status should be success

# Custom validation function to check all symlinks start with dots
check_dotfile_symlinks() {
  local output="${1}"
  local non_dotfile_symlinks=()

  while IFS= read -r line; do
    if [[ "${line}" =~ Would\ (create|update):\ ~/([^\ ]+) ]]; then
      local target="${BASH_REMATCH[2]}"
      local first_component="${target%%/*}" # Get first part before any /

      if [[ ! "${first_component}" =~ ^\. ]]; then
        non_dotfile_symlinks+=("${line}")
      fi
    fi
  done <<< "${output}"

  # Return failure if any non-dotfile symlinks found
  if [[ ${#non_dotfile_symlinks[@]} -gt 0 ]]; then
    echo "FAILED: Found symlinks to non-dotfiles (files/dirs not starting with '.'):"
    for symlink in "${non_dotfile_symlinks[@]}"; do
      echo "  ${symlink}"
    done
    return 1
  fi

  return 0
}

The output should satisfy "check_dotfile_symlinks"
End
End
End
