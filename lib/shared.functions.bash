#!/usr/bin/env bash

# Shared utility functions for setup scripts
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume security, logging, and platform functions are already sourced by calling script

# Validate script name for security (shared)
validate_script_name() {
  local script="$1"
  if [[ ! "${script}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid script name contains illegal characters: ${script}"
    return 1
  fi
  if [[ "${script}" == *".."* ]] || [[ "${script}" == *"/"* ]]; then
    log_error "Script name contains path traversal characters: ${script}"
    return 1
  fi
  if [[ ${#script} -gt 50 ]]; then
    log_error "Script name too long: ${script}"
    return 1
  fi
  return 0
}

# Cross-platform symlink creation that prevents cyclic links
# Args: source_path target_path
# Uses -h on BSD/macOS, -n on GNU/Linux to avoid following existing symlinks
create_symlink_force() {
  local source="$1"
  local target="$2"

  if [[ -z "${source}" || -z "${target}" ]]; then
    log_error "create_symlink_force requires source and target arguments"
    return 1
  fi

  # Detect OS to use appropriate ln flags
  local os
  os=$(detect_os)

  case "${os}" in
    "macos")
      # BSD ln uses -h to not follow symlinks when replacing
      ln -sfh "${source}" "${target}"
      ;;
    "linux")
      # GNU ln uses -n to treat symlink targets as normal files
      ln -sfn "${source}" "${target}"
      ;;
    *)
      # Fallback: remove existing target first for unknown systems
      [[ -e "${target}" || -L "${target}" ]] && rm -f "${target}"
      ln -s "${source}" "${target}"
      ;;
  esac
}
