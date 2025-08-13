#!/usr/bin/env bash

# Functions for setup-user script
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume shared and security functions are already sourced by calling script

# Get user packages using shared function but with user-specific path
get_packages() {
  local platform="$1" manager="$2"
  # shellcheck disable=SC2154  # DOTFILES_DIR is set by calling script
  local packages_file="${DOTFILES_DIR}/packages.yaml"
  get_packages_from_file "${platform}" "${manager}" "${packages_file}"
}

# Get custom scripts from YAML
get_custom_scripts() {
  local platform="$1"
  # shellcheck disable=SC2154  # DOTFILES_DIR is set by calling script
  local file="${DOTFILES_DIR}/packages.yaml"
  [[ -f "${file}" ]] || return 0

  # Use secure YAML parsing
  if ! validate_yaml_file "${file}"; then
    log_security_event "INVALID_YAML" "YAML validation failed for: ${file}"
    return 1
  fi

  # Extract platform section, then custom section, then script list
  # Updated for flattened structure (no nested packages: key)
  sed -n "/${platform}:/,/^[a-z]/p" "${file}" \
    | sed -n "/custom:/,/^  [a-z]/p" \
    | grep "^    - " | sed 's/^    - //' \
    | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//' || true
}

# Process custom scripts with security validation
process_custom_scripts() {
  local platform="$1" dry_run="$2"
  # shellcheck disable=SC2154  # PROJECT_ROOT is set by calling script
  local scripts_dir="${PROJECT_ROOT}/dotfiles/shared/scripts"
  local scripts

  scripts=$(get_custom_scripts "${platform}")
  [[ -z "${scripts}" ]] && return 0 # Explicitly return success when no scripts

  # Validate scripts directory (allow symlinks for this validation)
  if ! validate_path_traversal "${scripts_dir}" "${PROJECT_ROOT}" "true"; then
    log_security_event "INVALID_SCRIPTS_DIR" "Scripts directory outside allowed path: ${scripts_dir}"
    echo "Error: Scripts directory outside allowed path" >&2
    return 1
  fi

  if [[ "${dry_run}" = true ]]; then
    echo "Would run custom scripts:"
    for script in ${scripts}; do
      if ! validate_script_name "${script}"; then
        continue
      fi
      if [[ -f "${scripts_dir}/${script}.bash" ]]; then
        log_dry_run "run custom script: ${script}"
      else
        log_warning "Script not found: ${script}"
      fi
    done
  else
    log_info "Running custom scripts..."
    for script in ${scripts}; do
      if ! validate_script_name "${script}"; then
        continue
      fi
      local script_path="${scripts_dir}/${script}.bash"

      # Additional security validation for script path
      if ! validate_path_traversal "${script_path}" "${PROJECT_ROOT}"; then
        log_security_event "INVALID_SCRIPT_PATH" "Script path outside allowed area: ${script_path}"
        log_warning "Script path outside allowed area: ${script}"
        continue
      fi

      if [[ -f "${script_path}" ]] && [[ -x "${script_path}" ]]; then
        log_info "Running custom script: ${script}"
        if "${script_path}" "${dry_run}"; then
          log_success "Custom script ${script} completed successfully"
        else
          log_warning "Custom script ${script} failed"
        fi
      else
        log_warning "Script not found or not executable: ${script}"
      fi
    done
  fi
}

# Handle user package management with custom scripts
handle_packages() {
  local platform="$1" dry_run="$2"
  # shellcheck disable=SC2154  # DOTFILES_DIR is set by calling script
  local packages_file="${DOTFILES_DIR}/packages.yaml"

  # Use secure package handling from shared functions
  handle_packages_from_file "${platform}" "${dry_run}" "${packages_file}" "USER"

  # Also process custom scripts for this platform
  process_custom_scripts "${platform}" "${dry_run}"
}

# Check if a config should NOT be linked on the current platform
config_should_not_be_linked() {
  local config_path="$1"
  local platform="${2:-$(detect_platform)}"

  # Skip Linux-only configs on non-Linux platforms (but WSL can run terminal tools)
  if [[ "${platform}" == "windows" || "${platform}" == "macos" ]]; then
    local config_name
    config_name=$(basename "${config_path}")

    case "${config_name}" in
      hypr | hyprland)
        # Hyprland is a Wayland compositor - Linux only
        return 0
        ;;
      waybar)
        # Waybar is a Wayland bar - Linux only
        return 0
        ;;
      systemd)
        # systemd is Linux only
        return 0
        ;;
      dynamic-wallpaper.yml)
        # Dynamic wallpaper script is for Linux desktop environments
        return 0
        ;;
      dconf)
        # dconf is GNOME/GTK configuration - Linux only
        return 0
        ;;
      tmux)
        # tmux is a terminal multiplexer - not needed on Windows
        return 0
        ;;
      navi)
        # navi is a terminal cheatsheet tool - not needed on Windows
        return 0
        ;;
      *)
        # Config is cross-platform, should be included on Windows
        return 1
        ;;
    esac
  fi

  # By default, link the config
  return 1
}

# Generic directory traversal with dotfile filtering
traverse_dotfiles() {
  local file_handler="$1"
  local dir_handler="$2"
  local src_dir="$3"
  local dest_dir="$4"
  local relative_path="$5"
  local filter_dotfiles="${6:-true}"

  shopt -s dotglob nullglob
  for item in "${src_dir}"/*; do
    local basename_item
    basename_item=$(basename "${item}")

    # Only filter for dotfiles at the top level
    if [[ "${filter_dotfiles}" == "true" && ! "${basename_item}" =~ ^\. ]]; then
      continue
    fi

    # Skip configs that shouldn't be linked on this platform
    if [[ -d "${item}" ]] && [[ "${relative_path}" == "" || "${relative_path}" == ".config/" ]]; then
      if config_should_not_be_linked "${basename_item}"; then
        continue
      fi
    fi

    if [[ -f "${item}" ]]; then
      "${file_handler}" "${item}" "${dest_dir}" "${relative_path}"
    elif [[ -d "${item}" ]]; then
      "${dir_handler}" "${item}" "${dest_dir}" "${relative_path}"
    fi
  done
  shopt -u dotglob nullglob
}

# File handler for show mode
show_file_item() {
  local item="$1" dest_dir="$2" relative_path="$3"
  local filename
  filename=$(basename "${item}")

  # Skip files that shouldn't be linked on current platform
  local platform="${PLATFORM:-$(detect_platform)}"
  if [[ "${platform}" = "windows" ]]; then
    case "${filename}" in
      .bashrc | .bashrc_git_learning | .bash_profile | .bash_logout)
        # Bash-specific files not needed on pure Windows
        return 0
        ;;
      *)
        # Default: process all other files
        ;;

    esac
  fi

  # Skip desktop environment configs on WSL (has no GUI)
  if [[ "${platform}" = "wsl" ]]; then
    case "${filename}" in
      dynamic-wallpaper.yml | dynamic-wallpaper)
        # Dynamic wallpaper is for Linux desktop environments
        return 0
        ;;
      *)
        # Default: process all other files
        ;;

    esac
  fi

  # Use platform-aware path for display
  local target
  target=$(get_platform_config_path "${relative_path}" "${filename}")
  local action="create"
  if [[ -e "${target}" ]]; then
    [[ -L "${target}" ]] && action="update" || action="replace"
  fi

  # Source logging functions if not already available
  if ! command -v log_dry_run > /dev/null 2>&1; then
    # shellcheck disable=SC2154  # SCRIPT_DIR is set by calling script
    source "${SCRIPT_DIR}/logging.functions.bash"
  fi

  # Display the actual target path that will be used
  log_dry_run "${action}: ${target} -> ${item}"
}

# Directory handler for show mode
show_directory_item() {
  local item="$1" dest_dir="$2" relative_path="$3"
  local dirname
  dirname=$(basename "${item}")
  show_symlinks "${item}" "${dest_dir}/${dirname}" "${relative_path}${dirname}/" "false"
}

# Show symlinks (dry-run mode)
show_symlinks() {
  local src_dir="$1" dest_dir="$2" relative_path="$3" filter_dotfiles="${4:-true}"

  # Output header for compatibility with tests
  if [[ "${relative_path}" == "" && "${filter_dotfiles}" == "true" ]]; then
    if [[ "${src_dir}" == *"/shared" ]]; then
      echo "SHARED SYMLINKS:"
    else
      echo "USER SYMLINKS:"
    fi
  fi

  traverse_dotfiles "show_file_item" "show_directory_item" "${src_dir}" "${dest_dir}" "${relative_path}" "${filter_dotfiles}"
}

# Get Windows-specific config path for cross-platform compatibility
get_platform_config_path() {
  local relative_path="$1"
  local filename="$2"
  local full_path="${relative_path}${filename}"

  # Only apply Windows-specific mapping when on Windows
  if [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]] || [[ -n "${WINDIR:-}" ]]; then
    case "${full_path}" in
      # Alacritty config mapping
      ".config/alacritty/"*)
        # Extract the subpath after .config/alacritty/
        local subpath="${full_path#.config/alacritty/}"
        # Normalize Windows path separators to forward slashes
        # shellcheck disable=SC2154  # APPDATA is a Windows environment variable
        local appdata_path="${APPDATA//\\//}/alacritty"
        # Create directory structure if it contains subdirectories
        local subdir
        subdir=$(dirname "${subpath}")
        if [[ "${subdir}" != "." ]]; then
          mkdir -p "${appdata_path}/${subdir}" 2> /dev/null
        else
          mkdir -p "${appdata_path}" 2> /dev/null
        fi
        echo "${appdata_path}/${subpath}"
        return 0
        ;;
      # 1Password config mapping (if needed in future)
      ".config/1Password/"*)
        # Normalize Windows path separators to forward slashes
        # shellcheck disable=SC2154  # LOCALAPPDATA is a Windows environment variable
        local localappdata_path="${LOCALAPPDATA//\\//}/1Password"
        mkdir -p "${localappdata_path}" 2> /dev/null
        echo "${localappdata_path}/${filename}"
        return 0
        ;;
      *)
        # Default: use standard Unix path
        ;;
    esac
  fi

  # Default: use HOME directory with standard Unix paths
  echo "${HOME}/${full_path}"
}

# File handler for create mode
create_file_item() {
  local item="$1" dest_dir="$2" relative_path="$3"
  local filename
  filename=$(basename "${item}")

  # Sanitize filename for security
  local safe_filename
  if ! safe_filename=$(sanitize_filename "${filename}") || [[ -z "${safe_filename}" ]]; then
    log_security_event "UNSAFE_FILENAME" "Skipping unsafe filename: ${filename}"
    echo "Warning: Skipping unsafe filename: ${filename}" >&2
    return 1
  fi

  # Skip files that shouldn't be linked on current platform
  local platform="${PLATFORM:-$(detect_platform)}"
  if [[ "${platform}" = "windows" ]]; then
    case "${filename}" in
      .bashrc | .bashrc_git_learning | .bash_profile | .bash_logout)
        # Bash-specific files not needed on pure Windows
        return 0
        ;;
      *)
        # Default: process all other files
        ;;
    esac
  fi

  # Skip desktop environment configs on WSL (has no GUI)
  if [[ "${platform}" = "wsl" ]]; then
    case "${filename}" in
      dynamic-wallpaper.yml | dynamic-wallpaper)
        # Dynamic wallpaper is for Linux desktop environments
        return 0
        ;;
      *)
        # Default: process all other files
        ;;
    esac
  fi

  # Use platform-aware path for the actual link (after validation)
  local target
  target=$(get_platform_config_path "${relative_path}" "${filename}")

  # Additional validation - ensure target is within allowed directories
  # On Windows, allow AppData directories in addition to HOME
  local validation_passed=false

  if validate_path_traversal "${target}" "${HOME}" "true"; then
    validation_passed=true
  elif [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]] || [[ -n "${WINDIR:-}" ]]; then
    # On Windows, also allow AppData directories (normalize paths for comparison)
    local normalized_appdata="${APPDATA//\\//}"
    local normalized_localappdata="${LOCALAPPDATA//\\//}"
    if [[ "${target}" == "${normalized_appdata}"* ]] || [[ "${target}" == "${normalized_localappdata}"* ]]; then
      validation_passed=true
    fi
  fi

  if [[ "${validation_passed}" = false ]]; then
    log_security_event "INVALID_TARGET" "Target outside allowed directories: ${target}"
    log_warning "Skipping link outside allowed directories: ${target}"
    return 1
  fi

  # Remove existing file/symlink safely
  if [[ -e "${target}" ]] || [[ -L "${target}" ]]; then
    rm -f "${target}"
  fi

  # Create symlink
  if ln -s "${item}" "${target}" 2> /dev/null; then
    # Show detailed linking info like in dry-run mode
    log_success "Linked: ${target} -> ${item}"
  else
    log_warning "Failed to create symlink: ${target}"
  fi
}

# Directory handler for create mode
create_directory_item() {
  local item="$1" dest_dir="$2" relative_path="$3"
  local dirname
  dirname=$(basename "${item}")

  # Validate directory name
  local safe_dirname
  if ! safe_dirname=$(sanitize_filename "${dirname}") || [[ -z "${safe_dirname}" ]]; then
    log_security_event "UNSAFE_DIRNAME" "Skipping unsafe directory name: ${dirname}"
    echo "Warning: Skipping unsafe directory name: ${dirname}" >&2
    return 1
  fi

  local target_dir="${dest_dir}/${dirname}"

  # Validate target directory
  if ! validate_path_traversal "${target_dir}" "${HOME}" "true"; then
    log_security_event "INVALID_TARGET_DIR" "Target directory outside home: ${target_dir}"
    echo "Warning: Skipping directory outside home: ${target_dir}" >&2
    return 1
  fi

  mkdir -p "${target_dir}"
  create_symlinks "${item}" "${target_dir}" "${relative_path}${dirname}/" "false"
}

# Securely create symlinks with path validation
create_symlinks() {
  local src_dir="$1" dest_dir="$2" relative_path="$3" filter_dotfiles="${4:-true}"

  # Validate source and destination directories
  if ! validate_path_traversal "${src_dir}" "${PROJECT_ROOT}/dotfiles"; then
    log_security_event "INVALID_SRC_DIR" "Source directory outside allowed path: ${src_dir}"
    echo "Error: Source directory outside allowed dotfiles path" >&2
    return 1
  fi

  if ! validate_path_traversal "${dest_dir}" "${HOME}" "true"; then
    log_security_event "INVALID_DEST_DIR" "Destination directory outside home: ${dest_dir}"
    echo "Error: Destination directory outside home directory" >&2
    return 1
  fi

  traverse_dotfiles "create_file_item" "create_directory_item" "${src_dir}" "${dest_dir}" "${relative_path}" "${filter_dotfiles}"
}

# Securely setup systemd user services with validation
setup_systemd_services() {
  local dry_run="$1"

  # Skip systemd on non-Linux platforms
  local platform="${PLATFORM:-$(detect_platform)}"
  if [[ "${platform}" != "arch" ]]; then
    if [[ "${dry_run}" = true ]]; then
      echo "SYSTEM SERVICES:"
      log_dry_run "skip systemd services (not supported on ${platform})"
    else
      log_info "Skipping systemd services (not supported on ${platform})"
    fi
    return
  fi

  # In dry-run mode, check dotfiles directory; in normal mode, check HOME
  local systemd_dir
  if [[ "${dry_run}" = true ]]; then
    systemd_dir="${DOTFILES_DIR}/.config/systemd/user"
  else
    systemd_dir="${HOME}/.config/systemd/user"
  fi

  if [[ ! -d "${systemd_dir}" ]]; then
    return
  fi

  # Validate systemd directory
  local _expected_base
  if [[ "${dry_run}" = true ]]; then
    _expected_base="${DOTFILES_DIR}" # Unused, kept for documentation
  else
    _expected_base="${HOME}" # Unused, kept for documentation
    # Also validate directory is within home in normal mode
    if ! validate_path_traversal "${systemd_dir}" "${HOME}" "true"; then
      log_security_event "INVALID_SYSTEMD_DIR" "Systemd directory outside home: ${systemd_dir}"
      echo "Error: Systemd directory outside home directory" >&2
      return 1
    fi
  fi

  # Safely find and validate timer files
  local timers=()
  while IFS= read -r -d '' timer_path; do
    local timer_name
    timer_name=$(basename "${timer_path}")

    # Validate systemd unit name format
    if validate_systemd_unit_name "${timer_name}"; then
      timers+=("${timer_name}")
    else
      log_security_event "INVALID_UNIT_NAME" "Skipping invalid systemd unit: ${timer_name}"
      echo "Warning: Skipping invalid systemd unit name: ${timer_name}" >&2
    fi
  done < <(find "${systemd_dir}" -maxdepth 1 -name "*.timer" -type f -print0 2> /dev/null || true)

  if [[ ${#timers[@]} -eq 0 ]]; then
    return
  fi

  if [[ "${dry_run}" = true ]]; then
    echo "SYSTEMD SERVICES:"
    for timer in "${timers[@]}"; do
      log_dry_run "enable and start: ${timer}"
    done
  else
    log_info "Setting up systemd user services..."
    systemctl --user daemon-reload

    for timer in "${timers[@]}"; do
      log_info "Enabling ${timer}..."
      # Use quoted unit name for safety
      if ! systemctl --user enable --now "${timer}"; then
        log_warning "Failed to enable ${timer}"
      fi
    done
  fi
}

# Configure sudo timeout to 12 hours (720 minutes)
configure_sudo_timeout() {
  local dry_run="$1"
  local timeout_minutes=720 # 12 hours
  local sudoers_dir="/etc/sudoers.d"
  # shellcheck disable=SC2154  # CURRENT_USER is set by calling script
  local sudoers_file="99-${CURRENT_USER}-timeout"
  local sudoers_path="${sudoers_dir}/${sudoers_file}"

  # Check if we need sudo access (only on Linux-based systems)
  local platform="${PLATFORM:-$(detect_platform)}"
  if [[ "${platform}" != "arch" ]] && [[ "${platform}" != "wsl" ]]; then
    if [[ "${dry_run}" = true ]]; then
      log_dry_run "skip sudo timeout config (not needed on ${platform})"
    fi
    return
  fi

  # Content for the sudoers file
  local sudoers_content="# Allow ${CURRENT_USER} to use sudo with 12-hour password caching
Defaults:${CURRENT_USER} timestamp_timeout=${timeout_minutes}"

  if [[ "${dry_run}" = true ]]; then
    echo "SUDO CONFIGURATION:"
    if [[ -f "${sudoers_path}" ]]; then
      log_dry_run "update sudo timeout to 12 hours (file exists)"
    else
      log_dry_run "configure sudo timeout to 12 hours"
    fi
    log_dry_run "sudoers file: ${sudoers_path}"
    return
  fi

  # Check if sudoers.d directory exists
  if [[ ! -d "${sudoers_dir}" ]]; then
    log_warning "Directory ${sudoers_dir} does not exist, skipping sudo configuration"
    return
  fi

  # Check if we can write to sudoers.d (need sudo)
  if ! sudo -n true 2> /dev/null; then
    log_info "Configuring sudo timeout (requires password)..."
  else
    log_info "Configuring sudo timeout..."
  fi

  # Create temporary file with proper permissions
  local temp_file
  temp_file=$(mktemp)
  echo "${sudoers_content}" > "${temp_file}"

  # Validate the sudoers file syntax
  if ! sudo visudo -c -f "${temp_file}" > /dev/null 2>&1; then
    log_error "Invalid sudoers syntax, skipping configuration"
    rm -f "${temp_file}"
    return 1
  fi

  # Install the sudoers file with proper permissions
  if sudo install -m 0440 -o root -g root "${temp_file}" "${sudoers_path}"; then
    log_success "Sudo timeout configured to 12 hours"
  else
    log_warning "Failed to configure sudo timeout"
  fi

  # Clean up temp file
  rm -f "${temp_file}"
}

# Setup 1Password config on first run only
setup_1password_config() {
  local dry_run="$1"

  # Check if 1Password settings template exists in dotfiles
  local template_source="${DOTFILES_DIR}/.config/1Password/settings/settings.json"
  local settings_target="${HOME}/.config/1Password/settings/settings.json"

  if [[ ! -f "${template_source}" ]]; then
    return
  fi

  if [[ "${dry_run}" = true ]]; then
    echo "1PASSWORD CONFIG:"
    if [[ -f "${settings_target}" ]]; then
      log_dry_run "skip 1Password config (already exists)"
    else
      log_dry_run "install 1Password settings template (first run only)"
    fi
  else
    if [[ -f "${settings_target}" ]]; then
      log_info "Skipping 1Password config (already exists)"
    else
      log_info "Installing 1Password settings template..."
      mkdir -p "$(dirname "${settings_target}")"
      cp "${template_source}" "${settings_target}"
      log_success "1Password settings template installed"
    fi
  fi
}

# Run per-user setup hook script if present
run_user_setup_hook() {
  local dry_run="$1"
  local hook_path="${DOTFILES_DIR}/setup-user-hook.sh"
  if [[ ! -e "${hook_path}" ]]; then
    return 0
  fi
  if ! validate_path_traversal "${hook_path}" "${PROJECT_ROOT}/dotfiles"; then
    log_security_event "INVALID_SCRIPT_PATH" "User hook outside allowed area: ${hook_path}"
    log_warning "User hook outside allowed area"
    return 1
  fi
  if [[ ! -x "${hook_path}" ]]; then
    if [[ "${dry_run}" = true ]]; then
      echo "USER HOOK:"
      log_dry_run "skip user hook (not executable): ${hook_path}"
      return 0
    fi
    log_warning "User hook not executable: ${hook_path}"
    return 1
  fi
  if [[ "${dry_run}" = true ]]; then
    echo "USER HOOK:"
    log_dry_run "run user setup hook"
    echo "${hook_path} --dry-run"
    return 0
  fi
  log_info "Running user setup hook..."
  if "${hook_path}"; then
    log_success "User setup hook completed successfully"
    return 0
  else
    log_warning "User setup hook failed"
    return 1
  fi
}
