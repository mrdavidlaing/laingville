#!/usr/bin/env bash

# Git-related functions for Laingville repository
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume shared, security, and logging functions are already sourced by calling script

# Setup git hooks configuration
setup_git_hooks() {
  local dry_run="$1"
  local hooks_dir="${PROJECT_ROOT}/.hooks"

  # Check if we're in a git repository
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    if [[ "${dry_run}" = true ]]; then
      log_dry_run "skip git hooks setup (not in a git repository)"
    else
      log_info "Skipping git hooks setup (not in a git repository)"
    fi
    return
  fi

  # Check if .hooks directory exists
  if [[ ! -d "${hooks_dir}" ]]; then
    if [[ "${dry_run}" = true ]]; then
      log_dry_run "skip git hooks setup (no .hooks directory found)"
    else
      log_info "No .hooks directory found, skipping git hooks setup"
    fi
    return
  fi

  # Validate hooks directory path
  if ! validate_path_traversal "${hooks_dir}" "${PROJECT_ROOT}"; then
    log_security_event "INVALID_HOOKS_DIR" "Hooks directory outside project: ${hooks_dir}"
    log_warning "Hooks directory outside project root, skipping setup"
    return 1
  fi

  if [[ "${dry_run}" = true ]]; then
    echo "GIT HOOKS:"
    log_dry_run "configure git core.hooksPath to .hooks"
    # Check for available hooks
    # shellcheck disable=SC2243  # Prefer current pattern for directory content check
    if [[ -d "${hooks_dir}" ]] && [[ "$(ls -A "${hooks_dir}" 2> /dev/null)" ]]; then
      for hook in "${hooks_dir}"/*; do
        if [[ -f "${hook}" ]]; then
          local hook_name
          hook_name=$(basename "${hook}")
          if [[ -x "${hook}" ]]; then
            log_dry_run "enable hook: ${hook_name}"
          else
            log_dry_run "enable hook: ${hook_name} (would make executable)"
          fi
        fi
      done
    fi
  else
    log_info "Setting up git hooks..."

    # Configure git to use .hooks directory
    if git config core.hooksPath .hooks; then
      log_success "Git configured to use .hooks directory"
    else
      log_warning "Failed to configure git hooks path"
      return 1
    fi

    # Make all hooks executable
    local hook_count=0
    # shellcheck disable=SC2243  # Prefer current pattern for directory content check
    if [[ -d "${hooks_dir}" ]] && [[ "$(ls -A "${hooks_dir}" 2> /dev/null)" ]]; then
      for hook in "${hooks_dir}"/*; do
        if [[ -f "${hook}" ]]; then
          local hook_name
          hook_name=$(basename "${hook}")

          # Validate hook name for security
          local safe_hook_name
          if ! safe_hook_name=$(sanitize_filename "${hook_name}") || [[ -z "${safe_hook_name}" ]]; then
            log_security_event "INVALID_HOOK_NAME" "Skipping hook with invalid name: ${hook_name}"
            log_warning "Skipping hook with invalid name: ${hook_name}"
            continue
          fi

          if [[ ! -x "${hook}" ]]; then
            if chmod +x "${hook}"; then
              log_info "Made hook executable: ${hook_name}"
            else
              log_warning "Failed to make hook executable: ${hook_name}"
              continue
            fi
          fi

          hook_count=$((hook_count + 1))
        fi
      done

      if [[ ${hook_count} -gt 0 ]]; then
        log_success "Git hooks setup complete (${hook_count} hooks configured)"
      else
        log_info "No valid hooks found in .hooks directory"
      fi
    else
      log_info "No hooks found in .hooks directory"
    fi
  fi
}
