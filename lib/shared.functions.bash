#!/usr/bin/env bash

# Shared functions for both setup-user, setup-secrets, and setup-server scripts
# Note: Do not set -e here as functions need to handle their own error cases

# Security functions are sourced independently by calling scripts

# Detect the current operating system
# Returns: "macos", "linux", or "unknown"
detect_os() {
  # Use full path to uname for reliability in restricted environments
  local uname_cmd
  if command -v uname > /dev/null 2>&1; then
    uname_cmd="uname"
  elif [[ -x "/usr/bin/uname" ]]; then
    uname_cmd="/usr/bin/uname"
  elif [[ -x "/bin/uname" ]]; then
    uname_cmd="/bin/uname"
  else
    echo "unknown"
    return
  fi

  case "$(${uname_cmd} -s)" in
    "Darwin") echo "macos" ;;
    "Linux") echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

# Platform detection (builds on detect_os for sub-platform identification)
detect_platform() {
  local base_os
  base_os=$(detect_os)

  case "${base_os}" in
    "macos")
      # For macOS, platform equals OS
      echo "${base_os}"
      ;;
    "linux")
      # For Linux, detect the specific distribution/environment
      if grep -qi "microsoft\|wsl" /proc/version 2> /dev/null; then
        echo "wsl"
      elif command -v nix > /dev/null 2>&1; then
        echo "nix"
      elif command -v pacman > /dev/null 2>&1; then
        echo "arch"
      else
        echo "linux" # Generic Linux
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Detect username mapping from system username to dotfiles directory
detect_username() {
  local system_user
  system_user=$(whoami)
  case "${system_user}" in
    "david" | "mrdavidlaing" | "coder" | *"DavidLaing"*)
      echo "mrdavidlaing"
      ;;
    "timmy")
      echo "timmmmmmer"
      ;;
    *)
      echo "shared"
      ;;
  esac
}

# Secure YAML parsing - works for both user and server configs
get_packages_from_file() {
  local platform="$1" manager="$2" packages_file="$3"

  # Validate inputs
  validate_yaml_key "${platform}" || {
    log_security_event "INVALID_PLATFORM" "Invalid platform key: ${platform}"
    return 1
  }

  validate_yaml_key "${manager}" || {
    log_security_event "INVALID_MANAGER" "Invalid manager key: ${manager}"
    return 1
  }

  validate_yaml_file "${packages_file}" || {
    log_security_event "INVALID_YAML" "YAML validation failed for: ${packages_file}"
    return 1
  }

  # Use sed for reliable YAML parsing (no external dependencies)
  # Updated for flattened structure (no nested packages: key)
  local result
  result=$(head -n 1000 "${packages_file}" \
    | sed -n "/^${platform}:/,/^[a-z]/p" \
    | sed -n "/^  ${manager}:/,/^  [a-z]/p" \
    | grep "^    - " | sed 's/^    - //' \
    | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//' \
    | head -n 100 || true) # Limit number of packages
  echo "${result}"
}

# Secure package processing with validation
process_packages() {
  local manager="$1" cmd="$2" platform="$3" dry_run="$4" packages_file="$5"
  local packages

  # Validate manager name
  validate_yaml_key "${manager}" || {
    log_security_event "INVALID_MANAGER" "Invalid package manager: ${manager}"
    return 1
  }

  case "${manager}" in
    "pacman") packages=$(get_packages_from_file "${platform}" "pacman" "${packages_file}") ;;
    "yay") packages=$(get_packages_from_file "${platform}" "yay" "${packages_file}") ;;
    "homebrew") packages=$(get_packages_from_file "${platform}" "homebrew" "${packages_file}") ;;
    "cask") packages=$(get_packages_from_file "${platform}" "cask" "${packages_file}") ;;
    "nixpkgs-"*) packages=$(get_packages_from_file "${platform}" "${manager}" "${packages_file}") ;;
    *)
      log_security_event "UNKNOWN_MANAGER" "Unknown package manager: ${manager}"
      return 1
      ;;
  esac

  [[ -z "${packages}" ]] && return

  # Validate each package name to prevent command injection
  local valid_packages=()
  while IFS= read -r pkg; do
    [[ -z "${pkg}" ]] && continue
    if validate_package_name "${pkg}"; then
      valid_packages+=("${pkg}")
    else
      log_security_event "INVALID_PACKAGE" "Rejected invalid package name: ${pkg}"
      log_warning "Skipping invalid package name: ${pkg}"
    fi
  done <<< "${packages}"

  [[ ${#valid_packages[@]} -eq 0 ]] && return

  if [[ "${dry_run}" = true ]]; then
    local pkg_list
    pkg_list=$(printf '%s, ' "${valid_packages[@]}")
    pkg_list=${pkg_list%, } # Remove trailing comma
    log_dry_run "install via ${manager}: ${pkg_list}"
  else
    log_info "Installing ${manager} packages: ${valid_packages[*]}"

    # Check manager availability
    if [[ "${manager}" = "yay" ]] && ! command -v yay > /dev/null 2>&1; then
      log_warning "yay not found, skipping AUR packages"
      return
    fi

    if [[ "${manager}" =~ ^(homebrew|cask)$ ]] && ! command -v brew > /dev/null 2>&1; then
      log_warning "homebrew not found, skipping ${manager} packages"
      return
    fi

    if [[ "${manager}" =~ ^nixpkgs- ]] && ! command -v nix > /dev/null 2>&1; then
      log_warning "nix not found, skipping ${manager} packages"
      return
    fi

    # Install packages securely - one by one to prevent injection
    local failed_packages=()
    for pkg in "${valid_packages[@]}"; do
      # Use printf %q to properly quote package names
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      # Handle Nix packages specially - need nixpkgs# prefix with version
      if [[ "${manager}" =~ ^nixpkgs- ]]; then
        local nix_version="${manager#nixpkgs-}"
        # Convert version format for GitHub reference (25.05 -> nixos-25.05)
        local github_ref="github:NixOS/nixpkgs/nixos-${nix_version}"
        if ! eval "${cmd} ${github_ref}#${quoted_pkg}"; then
          failed_packages+=("${pkg}")
        fi
      else
        if ! eval "${cmd} ${quoted_pkg}"; then
          failed_packages+=("${pkg}")
        fi
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to install packages: ${failed_packages[*]}"
    fi
  fi
}

# Install yay AUR helper from ArchLinuxCN repository
install_yay() {
  local dry_run="$1"

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "Would install yay AUR helper from ArchLinuxCN repository"
    return 0
  fi

  # Check if yay is already installed
  if command -v yay > /dev/null 2>&1; then
    log_info "yay is already installed"
    return 0
  fi

  log_info "Installing yay AUR helper from ArchLinuxCN repository..."

  # For fresh installations (especially WSL), ensure system is up to date
  log_info "Updating system packages (required for fresh installs)..."
  if ! sudo pacman -Syu --noconfirm; then
    log_warning "System update failed, but continuing with yay installation..."
  fi

  # Check if ArchLinuxCN repository is configured
  if ! grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    log_info "Adding ArchLinuxCN repository to pacman.conf..."

    # Add ArchLinuxCN repository
    echo '[archlinuxcn]' | sudo tee -a /etc/pacman.conf > /dev/null
    echo "Server = https://repo.archlinuxcn.org/\${arch}" | sudo tee -a /etc/pacman.conf > /dev/null

    # Refresh package databases
    sudo pacman -Sy

    # Install keyring with proper error handling
    log_info "Installing ArchLinuxCN keyring..."
    if ! sudo pacman -S --needed --noconfirm archlinuxcn-keyring; then
      log_warning "Failed to install archlinuxcn-keyring directly, trying manual key import..."

      # Manual key import as fallback
      sudo pacman-key --recv-keys 7931B6D628C8D93F 2> /dev/null || true
      sudo pacman-key --lsign-key 7931B6D628C8D93F 2> /dev/null || true
      sudo pacman -Sy

      # Try keyring again
      if ! sudo pacman -S --needed --noconfirm archlinuxcn-keyring; then
        log_warning "Keyring installation failed, but continuing with yay installation..."
      fi
    fi
  fi

  # Install yay
  if sudo pacman -S --needed --noconfirm yay; then
    log_success "yay installed successfully from ArchLinuxCN"
    return 0
  else
    log_error "Failed to install yay from ArchLinuxCN"
    log_info "You may need to run: sudo pacman -Syu && sudo pacman -S archlinuxcn-keyring"
    return 1
  fi
}

# Handle all package management - takes packages file as parameter
handle_packages_from_file() {
  local platform="$1" dry_run="$2" packages_file="$3" context="$4"

  if [[ ! -f "${packages_file}" ]]; then
    if [[ "${dry_run}" = true ]]; then
      log_info "No packages.yaml found - no packages would be installed"
    else
      log_info "No packages.yaml found - skipping package installation"
    fi
    return
  fi

  if [[ "${dry_run}" = true ]]; then
    echo "${context} PACKAGES (${platform}):"
  else
    log_info "Installing ${context,,} packages for ${platform}..."
  fi

  case "${platform}" in
    "arch")
      # Install yay first for unified package management
      install_yay "${dry_run}"

      # Process official packages with pacman first, then AUR packages with yay
      process_packages "pacman" "pacman -S --needed --noconfirm" "${platform}" "${dry_run}" "${packages_file}"
      process_packages "yay" "yay -S --needed --noconfirm" "${platform}" "${dry_run}" "${packages_file}"
      ;;
    "wsl")
      # Use WSL-specific package handling (requires wsl.functions.bash)
      if declare -f handle_wsl_packages > /dev/null 2>&1; then
        handle_wsl_packages "${platform}" "${dry_run}" "${packages_file}" "${context}"
      else
        log_warning "WSL functions not available - skipping WSL package installation"
      fi
      ;;
    "macos")
      # Use Brewfile for batch installation on macOS
      install_packages_with_brewfile "${packages_file}" "${platform}" "${dry_run}"
      ;;
    "nix")
      # Process versioned nixpkgs (e.g., nixpkgs-25.05)
      # Find all nixpkgs-* managers in the file
      if [[ -f "${packages_file}" ]]; then
        while IFS= read -r manager; do
          [[ -n "${manager}" ]] || continue
          # For modern Nix with flakes, we use nixpkgs# prefix regardless of version
          process_packages "${manager}" "nix profile install" "${platform}" "${dry_run}" "${packages_file}"
        done < <(grep -E "^  nixpkgs-[0-9]+\.[0-9]+:" "${packages_file}" 2> /dev/null | sed 's/:.*//; s/^  //' || true)
      fi
      ;;
    *)
      log_warning "Unknown platform: ${platform} - skipping package installation"
      ;;
  esac
}

# WSL functions are now in wsl.functions.bash

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
