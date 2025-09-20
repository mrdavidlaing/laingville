#!/usr/bin/env bash

# Functions specific to setup-server script
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume all required lib functions are already sourced by calling script

# Map hostname to server directory
map_hostname_to_server_dir() {
  local hostname="$1"
  echo "servers/${hostname}"
}

# Get server packages using shared function but with server-specific path
get_server_packages() {
  local platform="$1" manager="$2"
  # shellcheck disable=SC2154  # SERVER_DIR is set by calling script
  local packages_file="${SERVER_DIR}/packages.yaml"
  extract_packages_from_yaml "${platform}" "${manager}" "${packages_file}"
}

# Handle shared server packages
handle_shared_server_packages() {
  local platform="$1" dry_run="$2"
  # shellcheck disable=SC2154  # SERVERS_ROOT is set by calling script
  local shared_packages_file="${SERVERS_ROOT}/shared/packages.yaml"

  if [ -f "$shared_packages_file" ]; then
    if ! validate_yaml_file "$shared_packages_file"; then
      log_error "Shared server packages.yaml failed validation"
      return 1
    fi
    handle_packages_from_file "${platform}" "${dry_run}" "${shared_packages_file}" "SHARED_SERVER"
    return 0
  fi
  return 1
}

# Handle server package management
handle_server_packages() {
  local platform="$1" dry_run="$2"
  # shellcheck disable=SC2154  # SERVER_DIR is set by calling script
  local packages_file="${SERVER_DIR}/packages.yaml"
  handle_packages_from_file "${platform}" "${dry_run}" "${packages_file}" "SERVER"

  process_server_custom_scripts "${platform}" "${dry_run}"
}

# Get server custom scripts
get_server_custom_scripts() {
  local platform="$1"
  # shellcheck disable=SC2154  # SERVER_DIR is set by calling script
  local file="${SERVER_DIR}/packages.yaml"
  [[ -f "${file}" ]] || return 0
  if ! validate_yaml_file "${file}"; then
    log_security_event "INVALID_YAML" "YAML validation failed for: ${file}"
    return 1
  fi
  sed -n "/${platform}:/,/^[a-z]/p" "${file}" \
    | sed -n "/custom:/,/^  [a-z]/p" \
    | grep "^    - " | sed 's/^    - //' || true
}

# Process server custom scripts
process_server_custom_scripts() {
  local platform="$1" dry_run="$2"
  # shellcheck disable=SC2154  # PROJECT_ROOT and SERVER_DIR are set by calling script
  local scripts_dir="${PROJECT_ROOT}/servers/shared/scripts"
  local host_scripts_dir="${SERVER_DIR}/scripts"
  local scripts

  scripts=$(get_server_custom_scripts "${platform}")
  [[ -z "${scripts}" ]] && return 0

  # Validate script directories
  if ! validate_path_traversal "${scripts_dir}" "${PROJECT_ROOT}" "true"; then
    log_security_event "INVALID_SCRIPTS_DIR" "Scripts directory outside allowed path: ${scripts_dir}"
    log_error "Scripts directory outside allowed path"
    return 1
  fi
  if ! validate_path_traversal "${host_scripts_dir}" "${PROJECT_ROOT}" "true"; then
    log_security_event "INVALID_SCRIPTS_DIR" "Host scripts directory outside allowed path: ${host_scripts_dir}"
    log_error "Host scripts directory outside allowed path"
    return 1
  fi

  if [[ "${dry_run}" = true ]]; then
    echo "Would run custom server scripts:"
    # Process each script using oldIFS technique to avoid subshells
    local oldIFS="${IFS}"
    IFS='
' # Set IFS to newline only
    for script in ${scripts}; do
      [[ -z "${script}" ]] && continue
      if ! validate_script_name "${script}"; then
        continue
      fi
      if [[ -f "${host_scripts_dir}/${script}.bash" ]]; then
        log_dry_run "run host script: ${script}"
      elif [[ -f "${scripts_dir}/${script}.bash" ]]; then
        log_dry_run "run shared server script: ${script}"
      else
        log_warning "Server script not found: ${script}"
      fi
    done
    IFS="${oldIFS}"
  else
    log_info "Running custom server scripts..."
    # Process each script using oldIFS technique to avoid subshells
    local oldIFS="${IFS}"
    IFS='
' # Set IFS to newline only
    for script in ${scripts}; do
      [[ -z "${script}" ]] && continue
      if ! validate_script_name "${script}"; then
        continue
      fi
      local script_path
      if [[ -f "${host_scripts_dir}/${script}.bash" ]]; then
        script_path="${host_scripts_dir}/${script}.bash"
      else
        script_path="${scripts_dir}/${script}.bash"
      fi
      if [[ -f "${script_path}" ]] && [[ -x "${script_path}" ]]; then
        log_info "Running server script: ${script}"
        if "${script_path}" "${dry_run}"; then
          log_success "Server script ${script} completed successfully"
        else
          log_warning "Server script ${script} failed"
        fi
      else
        log_warning "Server script not found or not executable: ${script}"
      fi
    done
    IFS="${oldIFS}"
  fi
}
