#!/usr/bin/env bash

# macOS-specific functions for setup-user script
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume shared, security and logging functions are already sourced by calling script

# Install and update Homebrew
install_homebrew() {
  local dry_run="$1"

  if [[ "${dry_run}" = true ]]; then
    echo "HOMEBREW SETUP:"
    if ! command -v brew > /dev/null 2>&1; then
      log_dry_run "install Homebrew via official installer"
    else
      log_dry_run "update Homebrew"
    fi
    return
  fi

  if ! command -v brew > /dev/null 2>&1; then
    log_info "Installing Homebrew..."
    # NOTE: The following command trusts the Homebrew installation script from GitHub.
    local installer_script
    installer_script=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
    /bin/bash -c "${installer_script}"
    log_success "Homebrew installation complete"
  else
    log_info "Updating Homebrew..."
    brew update || true
    log_success "Homebrew update complete"
  fi
}

# Configure macOS system defaults
configure_macos_system() {
  local dry_run="$1"

  if [[ "${dry_run}" = true ]]; then
    echo "MACOS SYSTEM CONFIG:"
    log_dry_run "set keyboard repeat rate (KeyRepeat=1, InitialKeyRepeat=15)"
    log_dry_run "enable font smoothing (AppleFontSmoothing=1)"
    log_dry_run "show hidden files and folders in Finder"
    log_dry_run "set WezTerm as default terminal for shell executables"
    log_dry_run "disable press-and-hold for VSCode and Cursor"
    log_dry_run "set system locale to en_IE.UTF-8"
    log_dry_run "enable separate spaces for each display"
    return
  fi

  log_info "Configuring macOS system settings..."

  # Keyboard settings for blazingly fast repeat rate
  log_info "Setting keyboard repeat rate (KeyRepeat=1, InitialKeyRepeat=15)"
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Enable font smoothing for better terminal font rendering
  log_info "Enabling font smoothing (AppleFontSmoothing=1)"
  defaults write NSGlobalDomain AppleFontSmoothing -int 1

  # Show hidden files and folders in Finder and file dialogs
  log_info "Showing hidden files and folders in Finder and file dialogs"
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain AppleShowAllFiles -bool true

  # Set WezTerm as default terminal for shell executables
  log_info "Setting WezTerm as default terminal for shell executables"
  defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType="public.unix-executable";LSHandlerRoleShell="com.github.wez.wezterm";}'

  # Disable press-and-hold for keys for VSCode and Cursor
  log_info "Disabling press-and-hold for VSCode and Cursor"
  defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
  defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false

  # Set system locale to en_IE.UTF-8
  log_info "Setting system locale to en_IE.UTF-8"
  defaults write NSGlobalDomain AppleLocale -string "en_IE"
  defaults write NSGlobalDomain AppleLanguages -array "en-IE" "en"

  # Enable separate spaces for each display (for multiple monitors)
  log_info "Enabling separate spaces for each display"
  defaults write com.apple.spaces "spans-displays" -bool false

  log_success "macOS system configuration complete"
}

# Generate a Brewfile from packages.yaml data for batch installation
# Args: packages_file platform dry_run
# Returns: path to generated Brewfile (or empty if dry_run)
generate_brewfile() {
  local packages_file="$1" platform="$2" dry_run="$3"

  # Validate inputs
  validate_yaml_file "${packages_file}" || {
    log_security_event "INVALID_YAML" "YAML validation failed for: ${packages_file}"
    return 1
  }

  validate_yaml_key "${platform}" || {
    log_security_event "INVALID_PLATFORM" "Invalid platform key: ${platform}"
    return 1
  }

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "generate Brewfile from packages.yaml"
    return 0
  fi

  # Create temporary Brewfile
  local brewfile
  brewfile=$(mktemp -t "laingville_brewfile.XXXXXX") || {
    log_error "Failed to create temporary Brewfile"
    return 1
  }

  # Get homebrew packages (formulae)
  local homebrew_packages
  homebrew_packages=$(get_packages_from_file "${platform}" "homebrew" "${packages_file}")

  # Get cask packages
  local cask_packages
  cask_packages=$(get_packages_from_file "${platform}" "cask" "${packages_file}")

  # Generate Brewfile content
  {
    echo "# Generated Brewfile for ${platform} packages"
    echo "# Created: $(date)"
    echo ""

    # Add homebrew packages as brew entries
    if [[ -n "${homebrew_packages}" ]]; then
      echo "# Homebrew formulae"
      while IFS= read -r pkg; do
        [[ -z "${pkg}" ]] && continue
        if validate_package_name "${pkg}"; then
          printf 'brew "%s"\n' "${pkg}"
        else
          log_security_event "INVALID_PACKAGE" "Rejected invalid package name: ${pkg}"
          log_warning "Skipping invalid package: ${pkg}"
        fi
      done <<< "${homebrew_packages}"
      echo ""
    fi

    # Add cask packages as cask entries
    if [[ -n "${cask_packages}" ]]; then
      echo "# Homebrew casks"
      while IFS= read -r pkg; do
        [[ -z "${pkg}" ]] && continue
        if validate_package_name "${pkg}"; then
          printf 'cask "%s"\n' "${pkg}"
        else
          log_security_event "INVALID_PACKAGE" "Rejected invalid package name: ${pkg}"
          log_warning "Skipping invalid package: ${pkg}"
        fi
      done <<< "${cask_packages}"
    fi
  } > "${brewfile}"

  # Output the file path to stdout (logging goes to stderr)
  echo "${brewfile}"
}

# Install packages using Brewfile for batch processing
# Args: packages_file platform dry_run
install_packages_with_brewfile() {
  local packages_file="$1" platform="$2" dry_run="$3"
  local brewfile

  # Generate Brewfile
  brewfile=$(generate_brewfile "${packages_file}" "${platform}" "${dry_run}")
  [[ $? -ne 0 ]] && return 1

  # In dry-run mode, just show what would be installed
  if [[ "${dry_run}" = true ]]; then
    local homebrew_packages cask_packages
    homebrew_packages=$(get_packages_from_file "${platform}" "homebrew" "${packages_file}")
    cask_packages=$(get_packages_from_file "${platform}" "cask" "${packages_file}")

    if [[ -n "${homebrew_packages}" ]]; then
      local valid_homebrew=()
      while IFS= read -r pkg; do
        [[ -z "${pkg}" ]] && continue
        if validate_package_name "${pkg}"; then
          valid_homebrew+=("${pkg}")
        else
          log_security_event "INVALID_PACKAGE" "Rejected invalid package name: ${pkg}"
          log_warning "Skipping invalid package: ${pkg}"
        fi
      done <<< "${homebrew_packages}"

      if [[ ${#valid_homebrew[@]} -gt 0 ]]; then
        local pkg_list
        pkg_list=$(printf '%s, ' "${valid_homebrew[@]}")
        pkg_list=${pkg_list%, }
        log_dry_run "install via homebrew: ${pkg_list}"
      fi
    fi

    if [[ -n "${cask_packages}" ]]; then
      local valid_casks=()
      while IFS= read -r pkg; do
        [[ -z "${pkg}" ]] && continue
        if validate_package_name "${pkg}"; then
          valid_casks+=("${pkg}")
        else
          log_security_event "INVALID_PACKAGE" "Rejected invalid package name: ${pkg}"
          log_warning "Skipping invalid package: ${pkg}"
        fi
      done <<< "${cask_packages}"

      if [[ ${#valid_casks[@]} -gt 0 ]]; then
        local pkg_list
        pkg_list=$(printf '%s, ' "${valid_casks[@]}")
        pkg_list=${pkg_list%, }
        log_dry_run "install via cask: ${pkg_list}"
      fi
    fi

    return 0
  fi

  # Check if Brewfile has any packages
  if [[ ! -s "${brewfile}" ]] || ! grep -q "^brew\|^cask" "${brewfile}"; then
    log_info "No packages to install"
    rm -f "${brewfile}"
    return 0
  fi

  log_info "Installing packages using Brewfile batch mode..."

  # Run brew bundle install (disable lock file creation for temporary Brewfiles)
  if HOMEBREW_BUNDLE_NO_LOCK=1 brew bundle install --file="${brewfile}"; then
    log_success "Package installation completed successfully"
  else
    log_warning "Some packages may have failed to install"
  fi

  # Clean up temporary Brewfile
  rm -f "${brewfile}"
}
