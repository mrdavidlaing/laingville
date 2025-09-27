#!/usr/bin/env bash

# WSL-specific functions for setup-user script
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume shared, security and logging functions are already sourced by calling script

# Setup WSL2 Arch environment - uses existing arch packages
setup_wsl2_arch() {
  local dry_run="$1" packages_file="$2"

  # Check if WSL2 is available
  if ! command -v wsl > /dev/null 2>&1; then
    if [[ "${dry_run}" = true ]]; then
      log_dry_run "WSL2 not available - would skip WSL2 setup"
    else
      log_info "WSL2 not available - skipping WSL2 setup"
    fi
    return
  fi

  # Check if Arch Linux is installed in WSL2 (handle spaced output from WSL)
  local wsl_check
  wsl_check=$(wsl --list --quiet 2> /dev/null | tr -d ' \0' | grep -i arch || true)
  if [[ -z "${wsl_check}" ]]; then
    if [[ "${dry_run}" = true ]]; then
      log_dry_run "WSL2 Arch not installed - would run Arch setup if available"
      log_dry_run "To install WSL2 Arch:"
      log_dry_run "  1. wsl --install archlinux"
      log_dry_run "  2. wsl -d archlinux -- pacman -Sy sudo git base-devel"
      log_dry_run "  3. wsl -d archlinux -- useradd -m -G wheel -s /bin/bash mrdavidlaing"
      log_dry_run "  4. wsl -d archlinux -- passwd mrdavidlaing"
      log_dry_run "  5. wsl -d archlinux -- sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"
      log_dry_run "  6. wsl --manage archlinux --set-default-user mrdavidlaing"
    else
      log_warning "WSL2 Arch not installed - skipping WSL2 setup"
      log_info ""
      log_info "To install WSL2 Arch with mrdavidlaing user:"
      log_info "  1. Install: wsl --install archlinux"
      log_info "  2. Install essentials: wsl -d archlinux -- pacman -Sy sudo git base-devel"
      log_info "  3. Create user: wsl -d archlinux -- useradd -m -G wheel -s /bin/bash mrdavidlaing"
      log_info "  4. Set password: wsl -d archlinux -- passwd mrdavidlaing"
      log_info "  5. Enable sudo: wsl -d archlinux -- sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"
      log_info "  6. Set default: wsl --manage archlinux --set-default-user mrdavidlaing"
      log_info "  7. Re-run setup: ./setup.sh user"
      log_info ""
    fi
    return
  fi

  # Check if Arch Linux is running and start it if needed
  local arch_status
  arch_status=$(wsl --list --verbose 2> /dev/null | tr -d ' \0' | grep -i arch | awk '{print $3}' || echo "Stopped" || true)
  if [[ "${arch_status}" != *"Running"* ]]; then
    if [[ "${dry_run}" = true ]]; then
      log_dry_run "WSL2 Arch not running - would start it automatically"
    else
      log_info "Starting WSL2 Arch Linux distribution..."
      # Start the distribution by running a simple command
      if wsl -d archlinux -- echo "WSL2 Arch started" > /dev/null 2>&1; then
        log_info "WSL2 Arch Linux started successfully"
      else
        log_error "Failed to start WSL2 Arch Linux"
        return 1
      fi
    fi
  fi

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "WSL2 Arch found - would run Arch setup inside WSL2"
  else
    log_info "Setting up WSL2 Arch environment..."

    # Convert Windows path to WSL2 format for the project root
    local wsl_project_path
    # shellcheck disable=SC2154  # PROJECT_ROOT is set by calling script
    if cd "${PROJECT_ROOT}"; then
      wsl_project_path=$(wsl -d archlinux -- wslpath "$(pwd -W)")
    else
      wsl_project_path=$(wsl -d archlinux -- wslpath "$(pwd -W 2> /dev/null || pwd)")
    fi

    # Run setup-user inside WSL2 Arch - it will use the arch: packages section

    if wsl -d archlinux -- bash -c "
            # Set up environment - WSL2 Arch uses same dotfiles via /mnt/c
            export PROJECT_ROOT='${wsl_project_path}'
            export DOTFILES_DIR='${wsl_project_path}/dotfiles/mrdavidlaing'
            
            # Run the normal Arch setup (will process arch: packages section)
            ./setup.sh user
        "; then
      log_success "WSL2 Arch setup completed successfully"
    else
      log_warning "WSL2 Arch setup encountered some issues"
    fi
  fi
}

# WSL-specific package handling
# Args: platform dry_run packages_file context
handle_wsl_packages() {
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

  # Install yay first for unified package management
  install_yay "${dry_run}"

  # Extract and install packages using new manager-specific functions
  # WSL uses its own YAML section to ensure correct terminal-only packages
  local pacman_packages yay_packages
  pacman_packages=$(extract_packages_from_yaml "${platform}" "pacman" "${packages_file}")
  yay_packages=$(extract_packages_from_yaml "${platform}" "yay" "${packages_file}")

  # Use WSL-specific pacman (without sudo - usually not needed in WSL)
  if [[ -n "${pacman_packages}" ]]; then
    local valid_packages
    valid_packages=$(validate_and_filter_packages "${pacman_packages}")
    if [[ -n "${valid_packages}" ]]; then
      local pkg_array=()
      populate_package_array "${valid_packages}" pkg_array

      if [[ "${dry_run}" = true ]]; then
        log_dry_run_package_list "pacman" "${pkg_array[@]}"
      elif [[ ${#pkg_array[@]} -gt 0 ]]; then
        log_info "Updating package databases..."
        if ! sudo pacman -Syu --noconfirm; then
          log_warning "Failed to update package databases"
          return 1
        fi

        log_info "Installing pacman packages: ${pkg_array[*]}"
        local quoted_packages=()
        for pkg in "${pkg_array[@]}"; do
          local quoted_pkg
          printf -v quoted_pkg '%q' "${pkg}"
          quoted_packages+=("${quoted_pkg}")
        done

        if ! eval "sudo pacman -S --needed --noconfirm ${quoted_packages[*]}"; then
          log_warning "Failed to install some pacman packages: ${pkg_array[*]}"
        fi
      fi
    fi
  fi

  install_yay_packages "${yay_packages}" "${dry_run}"

}
