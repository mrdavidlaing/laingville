#!/usr/bin/env bash

# Simplified setup-user functions using declarative symlinks from packages.yml

# Source required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared.functions.bash"
source "${SCRIPT_DIR}/logging.functions.bash"
source "${SCRIPT_DIR}/symlinks.functions.bash"
source "${SCRIPT_DIR}/security.functions.bash"

# Setup dotfiles using symlinks configuration from packages.yml
setup_user_dotfiles_v2() {
  local dry_run="${1:-false}"
  local user="${2:-$(whoami)}"
  local platform="${3:-$(detect_platform)}"

  # Determine dotfiles directory for user
  local user_dotfiles_dir
  case "${user}" in
    timmy) user_dotfiles_dir="dotfiles/timmmmmmer" ;;
    david) user_dotfiles_dir="dotfiles/mrdavidlaing" ;;
    *) user_dotfiles_dir="dotfiles/shared" ;;
  esac

  # Get absolute path to dotfiles
  local dotfiles_path="${DOTFILES_BASE_DIR}/${user_dotfiles_dir}"
  if [[ ! -d "${dotfiles_path}" ]]; then
    log_error "Dotfiles directory not found: ${dotfiles_path}"
    return 1
  fi

  local packages_yml="${dotfiles_path}/packages.yml"

  # Setup shared dotfiles first (if not using shared as primary)
  if [[ "${user_dotfiles_dir}" != "dotfiles/shared" ]]; then
    local shared_packages="${DOTFILES_BASE_DIR}/dotfiles/shared/packages.yml"
    if [[ -f "${shared_packages}" ]]; then
      log_section "Shared Dotfiles"
      setup_dotfiles_from_config "${shared_packages}" "${DOTFILES_BASE_DIR}/dotfiles/shared" "${HOME}" "${platform}" "${dry_run}"
    fi
  fi

  # Setup user-specific dotfiles
  if [[ -f "${packages_yml}" ]]; then
    log_section "User-Specific Dotfiles"
    setup_dotfiles_from_config "${packages_yml}" "${dotfiles_path}" "${HOME}" "${platform}" "${dry_run}"
  else
    log_warning "No packages.yml found for user dotfiles"
  fi

  return 0
}

# Setup dotfiles based on symlinks configuration in packages.yml
setup_dotfiles_from_config() {
  local packages_yml="${1}"
  local src_dir="${2}"
  local dest_dir="${3}"
  local platform="${4}"
  local dry_run="${5:-false}"

  # Get symlinks configuration for current platform
  local symlinks
  symlinks=$(parse_symlinks_from_yaml "${packages_yml}" "${platform}")

  if [[ -z "${symlinks}" ]]; then
    log_info "No symlinks configured for platform: ${platform}"
    return 0
  fi

  # Process each symlink
  while IFS= read -r symlink_entry; do
    [[ -z "${symlink_entry}" ]] && continue

    # Split source and target
    local source="${symlink_entry%%|*}"
    local custom_target="${symlink_entry#*|}"

    # Build full source path
    local full_source="${src_dir}/${source}"

    # Skip if source doesn't exist
    if [[ ! -e "${full_source}" ]]; then
      if [[ "${dry_run}" = "true" ]]; then
        log_dry_run "skip (not found): ${source}"
      else
        log_warning "Source not found: ${source}"
      fi
      continue
    fi

    # Determine target path
    local target
    if [[ -n "${custom_target}" ]]; then
      # Expand environment variables in custom target
      target=$(eval echo "${custom_target}")
    else
      # Use default target location
      target="${dest_dir}/${source}"
    fi

    # Create symlink
    if [[ "${dry_run}" = "true" ]]; then
      # Check if link exists and would be updated
      if [[ -L "${target}" ]]; then
        log_dry_run "update: ${target} -> ${full_source}"
      elif [[ -e "${target}" ]]; then
        log_dry_run "replace: ${target} -> ${full_source}"
      else
        log_dry_run "create: ${target} -> ${full_source}"
      fi
    else
      # Create parent directory if needed
      local target_dir
      target_dir=$(dirname "${target}")
      mkdir -p "${target_dir}" 2> /dev/null

      # Create the symlink
      if ln -sf "${full_source}" "${target}" 2> /dev/null; then
        log_success "Linked: ${target} -> ${full_source}"
      else
        log_error "Failed to link: ${target}"
      fi
    fi
  done <<< "${symlinks}"
}

# Process custom scripts from packages.yml
process_custom_scripts_v2() {
  local packages_yml="${1}"
  local platform="${2}"
  local dry_run="${3:-false}"

  # Extract custom scripts for platform
  local scripts
  scripts=$(get_custom_scripts_from_yaml "${packages_yml}" "${platform}")

  if [[ -z "${scripts}" ]]; then
    return 0
  fi

  log_section "Custom Scripts"

  while IFS= read -r script; do
    [[ -z "${script}" ]] && continue

    # Validate script name
    if ! validate_script_name "${script}"; then
      log_error "Invalid script name: ${script}"
      continue
    fi

    local script_path="${DOTFILES_BASE_DIR}/dotfiles/shared/scripts/${script}.bash"

    if [[ "${dry_run}" = "true" ]]; then
      log_dry_run "run custom script: ${script}"
    else
      if [[ -f "${script_path}" ]] && [[ -x "${script_path}" ]]; then
        log_info "Running custom script: ${script}"
        if "${script_path}"; then
          log_success "Script completed: ${script}"
        else
          log_error "Script failed: ${script}"
        fi
      else
        log_warning "Script not found or not executable: ${script_path}"
      fi
    fi
  done <<< "${scripts}"
}

# Extract custom scripts from packages.yml for a platform
get_custom_scripts_from_yaml() {
  local yaml_file="${1}"
  local platform="${2}"

  [[ ! -f "${yaml_file}" ]] && return 1

  # Extract custom scripts section
  local in_platform=0
  local in_custom=0

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    # Check if we're entering the platform section
    if [[ "${line}" =~ ^${platform}: ]]; then
      in_platform=1
      continue
    fi

    # If we're in the platform section
    if [[ "${in_platform}" -eq 1 ]]; then
      # If we hit a top-level key, we're done
      if [[ "${line}" =~ ^[^[:space:]] ]]; then
        break
      fi

      # Check for packages.custom section (backward compatibility)
      if [[ "${line}" =~ ^[[:space:]]+custom: ]]; then
        in_custom=1
        continue
      fi

      # Process custom script entries
      if [[ "${in_custom}" -eq 1 ]]; then
        if [[ "${line}" =~ ^[[:space:]]+-[[:space:]](.+) ]]; then
          echo "${BASH_REMATCH[1]}"
        elif [[ ! "${line}" =~ ^[[:space:]]+-[[:space:]] ]]; then
          # End of custom section
          in_custom=0
        fi
      fi
    fi
  done < "${yaml_file}"
}

# Main setup function using new approach
setup_user_v2() {
  local dry_run="${1:-false}"
  local user="${2:-$(whoami)}"
  local platform="${3:-$(detect_platform)}"

  # Set base directory
  DOTFILES_BASE_DIR="${DOTFILES_BASE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

  log_section "User Setup for ${user}"
  log_info "Platform: ${platform}"

  # Setup dotfiles with symlinks from packages.yml
  setup_user_dotfiles_v2 "${dry_run}" "${user}" "${platform}"

  # Determine packages.yml location
  local user_dotfiles_dir
  case "${user}" in
    timmy) user_dotfiles_dir="dotfiles/timmmmmmer" ;;
    david) user_dotfiles_dir="dotfiles/mrdavidlaing" ;;
    *) user_dotfiles_dir="dotfiles/shared" ;;
  esac

  local packages_yml="${DOTFILES_BASE_DIR}/${user_dotfiles_dir}/packages.yml"

  # Process custom scripts
  if [[ -f "${packages_yml}" ]]; then
    process_custom_scripts_v2 "${packages_yml}" "${platform}" "${dry_run}"
  fi

  # Install packages (using existing function)
  if [[ -f "${packages_yml}" ]]; then
    log_section "Package Management"
    local packages
    packages=$(get_packages_from_file "${packages_yml}" "${platform}")

    if [[ -n "${packages}" ]]; then
      if [[ "${dry_run}" = "true" ]]; then
        log_dry_run "install packages: ${packages}"
      else
        install_packages "${packages}" "${platform}"
      fi
    fi
  fi

  log_success "Setup complete!"
}

# Export functions
export -f setup_user_dotfiles_v2
export -f setup_dotfiles_from_config
export -f process_custom_scripts_v2
export -f get_custom_scripts_from_yaml
export -f setup_user_v2
