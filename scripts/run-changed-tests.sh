#!/usr/bin/env bash
set -e

# Global variables
RUN_ALL_TESTS=0

# Debug output helper
debug() {
  if [[ "${DEBUG_TESTS:-}" == "1" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Function: get_changed_files
# Args: base_sha, head_sha
# Output: List of changed file paths (one per line)
get_changed_files() {
  local base_sha="$1"
  local head_sha="$2"

  debug "Getting changed files between $base_sha and $head_sha"
  git diff --name-only --diff-filter=ACMR "$base_sha"..."$head_sha" || {
    debug "git diff failed, returning empty list"
    return 0
  }
}

# Function: map_source_to_tests
# Args: source_file_path
# Output: Space-separated list of test files
# Return: 0 if mapped, 1 if unmapped
map_source_to_tests() {
  local source_file="$1"

  case "$source_file" in
    lib/git.functions.bash)
      echo "spec/git_functions_spec.sh"
      return 0
      ;;
    lib/logging.functions.bash)
      echo "spec/logging_functions_spec.sh"
      return 0
      ;;
    lib/macos.functions.bash)
      echo "spec/macos_functions_spec.sh"
      return 0
      ;;
    lib/packages.functions.bash)
      echo "spec/packages_cleanup_spec.sh spec/packages_homebrew_spec.sh spec/packages_nix_spec.sh spec/packages_opkg_spec.sh spec/packages_pacman_spec.sh spec/packages_yay_spec.sh"
      return 0
      ;;
    lib/platform.functions.bash)
      echo "spec/platform_router_spec.sh"
      return 0
      ;;
    lib/polyfill.functions.bash)
      echo "spec/polyfill_functions_spec.sh"
      return 0
      ;;
    lib/security.functions.bash)
      echo "spec/security_spec.sh spec/security_integration_spec.sh"
      return 0
      ;;
    lib/setup-server.functions.bash)
      echo "spec/setup_server_spec.sh spec/setup_server_freshtomato_spec.sh spec/parse_server_inventory_spec.sh"
      return 0
      ;;
    lib/setup-user.functions.bash)
      echo "spec/setup_user_spec.sh spec/setup_user_dotfilter_spec.sh"
      return 0
      ;;
    lib/shared.functions.bash)
      echo "spec/shared_functions_spec.sh"
      return 0
      ;;
    lib/symlinks.functions.bash)
      echo "spec/symlinks_cleanup_spec.sh spec/symlinks_config_spec.sh"
      return 0
      ;;
    bin/setup-user)
      echo "spec/setup_user_spec.sh"
      return 0
      ;;
    bin/setup-server)
      echo "spec/setup_server_spec.sh spec/setup_server_freshtomato_spec.sh spec/parse_server_inventory_spec.sh"
      return 0
      ;;
    bin/security-triage)
      echo "spec/security-triage_spec.sh"
      return 0
      ;;
    bin/sbom-diff)
      echo "spec/sbom-diff_spec.sh"
      return 0
      ;;
    scripts/format-files.sh)
      echo "spec/format_basic_spec.sh spec/format_line_endings_spec.sh spec/format_whitespace_spec.sh"
      return 0
      ;;
    .hooks/pre-commit)
      echo "spec/git_functions_spec.sh"
      return 0
      ;;
    spec/*_spec.sh)
      # Test file itself changed - run it
      echo "$source_file"
      return 0
      ;;
    *)
      # Unmapped file
      return 1
      ;;
  esac
}

# Function: check_test_infrastructure_changed
# Args: changed_files (newline-separated string)
# Return: 0 if infrastructure changed, 1 otherwise
check_test_infrastructure_changed() {
  local changed_files="$1"

  # Check for test infrastructure files
  if echo "$changed_files" | grep -qE '(spec/spec_helper\.sh|\.shellspec|spec/support/|Justfile)'; then
    debug "Test infrastructure changed detected"
    return 0
  fi

  return 1
}

# Function: collect_tests_for_changes
# Args: changed_files (newline-separated string)
# Output: Deduplicated list of test files (one per line)
# Sets: RUN_ALL_TESTS=1 if unmapped files found
collect_tests_for_changes() {
  local changed_files="$1"
  local test_files=""
  local unmapped_found=0

  # Process each changed file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    debug "Processing changed file: $file"

    # shellcheck disable=SC2310
    if map_source_to_tests "$file" > /tmp/mapped_tests.txt 2> /dev/null; then
      local mapped=$(cat /tmp/mapped_tests.txt)
      debug "  Mapped to: $mapped"
      test_files="$test_files $mapped"
    else
      debug "  No mapping found for $file - will run all tests"
      unmapped_found=1
    fi
  done <<< "$changed_files"

  # If unmapped files found, signal to run all tests
  if [[ $unmapped_found -eq 1 ]]; then
    RUN_ALL_TESTS=1
    debug "Set RUN_ALL_TESTS=1 due to unmapped files"
    return 0
  fi

  # Deduplicate test files and write to temp file
  if [[ -n "$test_files" ]]; then
    echo "$test_files" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//' > /tmp/collected_tests.txt
  else
    : > /tmp/collected_tests.txt
  fi
}

# Function: run_tests
# Args: test_files (space-separated string or empty for all)
# Return: Exit code from shellspec
run_tests() {
  local test_files="$1"

  if [[ -z "$test_files" ]]; then
    debug "Running all tests"
    shellspec
  else
    debug "Running specific tests: $test_files"
    # shellspec expects space-separated file arguments
    # shellcheck disable=SC2086
    shellspec $test_files
  fi
}

# Main function
main() {
  local base_sha="${1:-}"
  local head_sha="${2:-HEAD}"

  # Auto-detect base_sha if not provided
  if [[ -z "$base_sha" ]]; then
    # Try to find merge-base with origin/main or origin/master
    if git rev-parse origin/main &> /dev/null; then
      base_sha=$(git merge-base origin/main HEAD)
      debug "Auto-detected base_sha from origin/main: $base_sha"
    elif git rev-parse origin/master &> /dev/null; then
      base_sha=$(git merge-base origin/master HEAD)
      debug "Auto-detected base_sha from origin/master: $base_sha"
    else
      # Fallback: use HEAD~1
      base_sha="HEAD~1"
      debug "Auto-detected base_sha as HEAD~1: $base_sha"
    fi
  fi

  debug "Base SHA: $base_sha"
  debug "Head SHA: $head_sha"

  # Get changed files
  local changed_files
  # shellcheck disable=SC2311
  changed_files=$(get_changed_files "$base_sha" "$head_sha")

  if [[ -z "$changed_files" ]]; then
    echo "No changed files detected between $base_sha and $head_sha"
    echo "Skipping tests"
    exit 0
  fi

  debug "Changed files:"
  # shellcheck disable=SC2001
  echo "$changed_files" | sed 's/^/  /'

  # Check if test infrastructure changed
  # shellcheck disable=SC2310
  if check_test_infrastructure_changed "$changed_files"; then
    echo "Test infrastructure changed - running full test suite"
    RUN_ALL_TESTS=1
  fi

  # Collect tests for changes
  local test_files=""
  if [[ "${RUN_ALL_TESTS:-0}" != "1" ]]; then
    collect_tests_for_changes "$changed_files"
    test_files=$(cat /tmp/collected_tests.txt 2> /dev/null || echo "")
    debug "After collect_tests_for_changes: RUN_ALL_TESTS=$RUN_ALL_TESTS, test_files=$test_files"
  fi

  # Check if we need to run all tests (unmapped files found)
  if [[ "${RUN_ALL_TESTS:-0}" == "1" ]]; then
    echo "Running full test suite (unmapped files or infrastructure changes detected)"
    run_tests ""
  else
    if [[ -z "$test_files" ]]; then
      echo "No tests mapped to changed files"
      echo "Skipping tests"
      exit 0
    fi

    local test_count=$(echo "$test_files" | wc -w)
    local file_count=$(echo "$changed_files" | wc -l)
    echo "Running $test_count test file(s) for $file_count changed file(s)"
    echo "Test files: $test_files"
    run_tests "$test_files"
  fi
}

# Show usage
usage() {
  cat << EOF
Usage: $0 [OPTIONS] [BASE_SHA] [HEAD_SHA]

Run ShellSpec tests for changed files between two git commits.

Arguments:
  BASE_SHA    Base commit SHA (default: auto-detect from origin/main or origin/master)
  HEAD_SHA    Head commit SHA (default: HEAD)

Options:
  -h, --help  Show this help message

Environment Variables:
  DEBUG_TESTS=1    Enable debug output

Examples:
  $0                    # Auto-detect changes
  $0 HEAD~1 HEAD        # Test changes in last commit
  $0 origin/main HEAD   # Test changes since main

Exit Codes:
  0   All tests passed or no tests to run
  1   Tests failed or error occurred
EOF
}

# Entry point
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

main "$@"
