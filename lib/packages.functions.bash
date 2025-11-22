#!/usr/bin/env bash

# Package installation functions
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume security, logging, and platform functions are already sourced by calling script

# Helper function to convert package list to array (outputs to stdout)
convert_packages_to_array() {
  local packages="$1"

  while IFS= read -r pkg; do
    [[ -n "${pkg}" ]] && printf '%s\n' "${pkg}"
  done <<< "${packages}"
}

# Helper function to quote packages for shell safety (outputs to stdout)
quote_packages() {
  local pkg
  for pkg in "$@"; do
    printf '%q ' "${pkg}"
  done
}

# Helper function to format package list for dry run display (outputs to stdout)
format_package_list() {
  local pkg_list
  pkg_list=$(printf '%s, ' "$@")
  echo "${pkg_list%, }"
}

# Helper function to populate an array variable with packages (newline-delimited input)
populate_package_array() {
  local packages="$1" array_name="$2"

  eval "${array_name}=()"

  while IFS= read -r pkg; do
    [[ -n "${pkg}" ]] || continue
    eval "${array_name}+=(\"\${pkg}\")"
  done < <(convert_packages_to_array "${packages}")
}

# Helper function to log package actions consistently in dry-run mode
log_dry_run_package_list() {
  local manager="$1"
  shift

  [[ $# -eq 0 ]] && return

  log_dry_run "install via ${manager}: $(format_package_list "$@")"
}

# Extract packages from YAML config file with secure parsing
# Uses awk state machine for efficient single-pass parsing
extract_packages_from_yaml() {
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

  # Single-pass awk parser with state machine
  # Handles: list format, inline arrays, comments, quotes, flexible indentation
  local result
  result=$(head -n 1000 "${packages_file}" | awk -v platform="${platform}" -v manager="${manager}" '
    BEGIN {
      state = "searching"  # States: searching -> in_platform -> in_manager
      count = 0
      max_packages = 100
    }

    # Skip empty lines and comment-only lines
    /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }

    # Top-level platform key (no leading whitespace)
    /^[a-z]/ {
      if (state == "in_manager") exit  # Left manager section
      if (state == "in_platform") state = "searching"  # Left platform section

      # Extract platform name (remove trailing colon)
      key = $1
      sub(/:$/, "", key)

      if (key == platform) {
        state = "in_platform"
        # Detect platform indentation (for next level)
        platform_indent = match($0, /[a-z]/) - 1
      }
      next
    }

    # In platform section: look for manager key
    state == "in_platform" && /^[[:space:]]+[a-z]/ {
      # Calculate indent level
      indent = match($0, /[a-z]/) - 1

      # If back to platform level, we left the section
      if (indent <= platform_indent) {
        state = "searching"
        next
      }

      # Extract manager name (remove leading whitespace and trailing colon)
      key = $0
      sub(/^[[:space:]]+/, "", key)

      # Check for inline array format: "manager: [item1, item2]"
      if (key ~ /:.*\[.*\]/) {
        mgr_name = key
        sub(/:.*$/, "", mgr_name)

        if (mgr_name == manager) {
          # Extract array content between brackets
          array_content = key
          sub(/^[^[]*\[/, "", array_content)
          sub(/\][^]]*$/, "", array_content)

          # Split by comma and process each item
          n = split(array_content, items, /,/)
          for (i = 1; i <= n && count < max_packages; i++) {
            item = items[i]
            # Strip leading/trailing whitespace
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
            # Strip quotes
            gsub(/^["'\'']|["'\'']$/, "", item)
            # Strip comments
            sub(/[[:space:]]*#.*$/, "", item)

            if (item != "") {
              print item
              count++
            }
          }
          exit
        }
      } else {
        # Regular list format
        sub(/:.*$/, "", key)

        if (key == manager) {
          state = "in_manager"
          manager_indent = indent
        }
      }
      next
    }

    # In manager section: extract list items
    state == "in_manager" {
      # Calculate indent level
      indent = match($0, /[^[:space:]]/) - 1

      # If indent decreased to manager level or less, we left the section
      if (indent <= manager_indent) {
        exit
      }

      # List item format: "  - package"
      if ($0 ~ /^[[:space:]]+-[[:space:]]/) {
        if (count >= max_packages) exit

        line = $0
        # Strip list marker and leading whitespace
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        # Strip comments
        sub(/[[:space:]]*#.*$/, "", line)
        # Strip trailing whitespace
        sub(/[[:space:]]*$/, "", line)
        # Strip quotes (both single and double)
        gsub(/^["'\'']|["'\'']$/, "", line)

        if (line != "") {
          print line
          count++
        }
      }
    }
  ' || true)

  echo "${result}"
}

# Extract cleanup packages from YAML config file
# Same as extract_packages_from_yaml but looks for <manager>_cleanup keys
extract_cleanup_packages_from_yaml() {
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

  # Look for <manager>_cleanup instead of <manager>
  local cleanup_manager="${manager}_cleanup"

  # Reuse the same awk parser, just with different manager name
  local result
  result=$(head -n 1000 "${packages_file}" | awk -v platform="${platform}" -v manager="${cleanup_manager}" '
    BEGIN {
      state = "searching"
      count = 0
      max_packages = 100
    }

    /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }

    /^[a-z]/ {
      if (state == "in_manager") exit
      if (state == "in_platform") state = "searching"

      key = $1
      sub(/:$/, "", key)

      if (key == platform) {
        state = "in_platform"
        platform_indent = match($0, /[a-z]/) - 1
      }
      next
    }

    state == "in_platform" && /^[[:space:]]+[a-z]/ {
      indent = match($0, /[a-z]/) - 1

      if (indent <= platform_indent) {
        state = "searching"
        next
      }

      key = $0
      sub(/^[[:space:]]+/, "", key)

      if (key ~ /:.*\[.*\]/) {
        mgr_name = key
        sub(/:.*$/, "", mgr_name)

        if (mgr_name == manager) {
          array_content = key
          sub(/^[^[]*\[/, "", array_content)
          sub(/\][^]]*$/, "", array_content)

          n = split(array_content, items, /,/)
          for (i = 1; i <= n && count < max_packages; i++) {
            item = items[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
            gsub(/^["'\'']|["'\'']$/, "", item)
            sub(/[[:space:]]*#.*$/, "", item)

            if (item != "") {
              print item
              count++
            }
          }
          exit
        }
      } else {
        sub(/:.*$/, "", key)

        if (key == manager) {
          state = "in_manager"
          manager_indent = indent
        }
      }
      next
    }

    state == "in_manager" {
      indent = match($0, /[^[:space:]]/) - 1

      if (indent <= manager_indent) {
        exit
      }

      if ($0 ~ /^[[:space:]]+-[[:space:]]/) {
        if (count >= max_packages) exit

        line = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        sub(/[[:space:]]*#.*$/, "", line)
        sub(/[[:space:]]*$/, "", line)
        gsub(/^["'\'']|["'\'']$/, "", line)

        if (line != "") {
          print line
          count++
        }
      }
    }
  ' || true)

  echo "${result}"
}

# Common package validation - returns array of validated packages
validate_and_filter_packages() {
  local packages="$1"
  local valid_packages=()

  while IFS= read -r pkg; do
    [[ -z "${pkg}" ]] && continue
    if validate_package_name "${pkg}"; then
      valid_packages+=("${pkg}")
    else
      log_security_event "INVALID_PACKAGE" "Rejected invalid package name: ${pkg}"
      log_warning "Skipping invalid package name: ${pkg}" >&2
    fi
  done <<< "${packages}"

  printf '%s\n' "${valid_packages[@]}"
}

# Refresh Arch Linux mirror list using reflector
refresh_arch_mirrors() {
  local dry_run="$1"
  local mirrorlist="/etc/pacman.d/mirrorlist"
  local max_age=3600 # 1 hour in seconds

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "refresh Arch mirrors using reflector (if older than 1 hour)"
    return 0
  fi

  # Skip if mirrorlist was updated less than 1 hour ago
  if [[ -f "${mirrorlist}" ]]; then
    local file_age
    file_age=$(($(date +%s) - $(stat -c %Y "${mirrorlist}" 2> /dev/null || echo 0)))
    if [[ ${file_age} -lt ${max_age} ]]; then
      log_info "Mirror list is recent ($((file_age / 60)) min old), skipping refresh"
      return 0
    fi
  fi

  log_info "Refreshing Arch Linux mirror list..."

  # Install reflector if not available
  if ! command -v reflector > /dev/null 2>&1; then
    log_info "Installing reflector..."
    if ! sudo pacman -S --needed --noconfirm reflector; then
      log_warning "Failed to install reflector, skipping mirror refresh"
      return 0
    fi
  fi

  # Backup current mirrorlist
  if [[ -f /etc/pacman.d/mirrorlist ]]; then
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  fi

  # Refresh mirrors: latest 10 European mirrors, sorted by rate, HTTPS only, 1s timeout
  if ! sudo reflector --country France,Germany,Netherlands,UK,Sweden --latest 10 --protocol https --sort rate --download-timeout 1 --save /etc/pacman.d/mirrorlist; then
    log_warning "Failed to refresh mirrors, continuing with existing mirrorlist"
    # Restore backup if refresh failed
    if [[ -f /etc/pacman.d/mirrorlist.backup ]]; then
      sudo cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    fi
  else
    log_success "Mirror list refreshed successfully"
  fi
}

# Install pacman packages (batch mode)
install_pacman_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Validate packages first (for security, even if pacman is not available)
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Check if pacman is available (should always be on Arch)
  if ! command -v pacman > /dev/null 2>&1; then
    log_warning "pacman not found, skipping pacman packages"
    return
  fi

  # Convert to array for processing (Bash 3.2 compatible)
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run_package_list "pacman" "${pkg_array[@]}"
  else
    log_info "Installing pacman packages: ${pkg_array[*]}"

    # Perform full system upgrade first (Arch Linux best practice)
    log_info "Performing full system upgrade..."
    if ! sudo pacman -Syu --noconfirm; then
      log_warning "Full system upgrade failed, continuing with package installation..."
    fi

    # Batch installation with proper quoting
    local quoted_packages
    quoted_packages=$(quote_packages "${pkg_array[@]}")

    if ! eval "sudo pacman -S --needed --noconfirm ${quoted_packages}"; then
      log_warning "Failed to install some pacman packages: ${pkg_array[*]}"
    fi
  fi
}

# Install yay packages (batch mode with --batchinstall)
install_yay_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Validate packages first (for security, even if yay is not available)
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Check if yay is available
  if ! command -v yay > /dev/null 2>&1; then
    log_warning "yay not found, skipping AUR packages"
    return
  fi

  # Convert to array for processing (Bash 3.2 compatible)
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run_package_list "yay" "${pkg_array[@]}"
  else
    log_info "Installing yay packages: ${pkg_array[*]}"

    # Refresh package databases first to avoid 404 errors
    log_info "Refreshing package databases..."
    if ! yay -Syy; then
      log_warning "Failed to refresh package databases, continuing anyway..."
    fi

    # Batch installation with --batchinstall and proper quoting
    local quoted_packages
    quoted_packages=$(quote_packages "${pkg_array[@]}")

    if ! eval "yay -S --needed --noconfirm --batchinstall ${quoted_packages}"; then
      log_warning "Failed to install some yay packages: ${pkg_array[*]}"
      log_info "Tip: If you see connection errors, the AUR servers may be temporarily unavailable. Try again later."
    fi
  fi
}

# Remove pacman packages (batch mode)
remove_pacman_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Validate packages first
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Check if pacman is available
  if ! command -v pacman > /dev/null 2>&1; then
    log_warning "pacman not found, skipping pacman package removal"
    return
  fi

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "remove via pacman: $(format_package_list "${pkg_array[@]}")"
  else
    log_info "Removing pacman packages: ${pkg_array[*]}"

    # Remove packages one at a time to avoid batch failure
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      # Check if package is installed
      if pacman -Q "${pkg}" > /dev/null 2>&1; then
        if ! sudo pacman -R --noconfirm "${pkg}"; then
          failed_packages+=("${pkg}")
        fi
      fi
    done

    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to remove some pacman packages: ${failed_packages[*]}"
    fi
  fi
}

# Remove yay packages (batch mode)
remove_yay_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Validate packages first
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Check if yay is available
  if ! command -v yay > /dev/null 2>&1; then
    log_warning "yay not found, skipping AUR package removal"
    return
  fi

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "remove via yay: $(format_package_list "${pkg_array[@]}")"
  else
    log_info "Removing yay packages: ${pkg_array[*]}"

    # Batch removal with proper quoting
    local quoted_packages
    quoted_packages=$(quote_packages "${pkg_array[@]}")

    if ! eval "yay -R --noconfirm ${quoted_packages}"; then
      log_warning "Failed to remove some yay packages: ${pkg_array[*]}"
    fi
  fi
}

# Install nix packages (individual mode with GitHub refs)
install_nix_packages() {
  local packages="$1" nix_version="$2" dry_run="$3"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Check if nix is available
  if ! command -v nix > /dev/null 2>&1; then
    log_warning "nix not found, skipping nix packages"
    return
  fi

  # Validate packages
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run_package_list "nixpkgs-${nix_version}" "${pkg_array[@]}"
  else
    log_info "Installing nixpkgs-${nix_version} packages: ${pkg_array[*]}"

    # Individual installation (nix requirement) with GitHub refs
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      # Convert version format for GitHub reference (25.05 -> nixos-25.05)
      local github_ref="github:NixOS/nixpkgs/nixos-${nix_version}"
      if ! eval "nix profile install ${github_ref}#${quoted_pkg}"; then
        failed_packages+=("${pkg}")
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to install nix packages: ${failed_packages[*]}"
    fi
  fi
}

# Install homebrew packages (uses existing Brewfile approach)
install_homebrew_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Check if brew is available
  if ! command -v brew > /dev/null 2>&1; then
    log_warning "homebrew not found, skipping homebrew packages"
    return
  fi

  # Validate packages
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run_package_list "homebrew" "${pkg_array[@]}"
  else
    log_info "Installing homebrew packages: ${pkg_array[*]}"

    # Individual installation for compatibility
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      if ! eval "brew install ${quoted_pkg}" 2>&1; then
        failed_packages+=("${pkg}")
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to install homebrew packages: ${failed_packages[*]}"
    fi
  fi
}

# Install cask packages (uses existing Brewfile approach)
install_cask_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Check if brew is available
  if ! command -v brew > /dev/null 2>&1; then
    log_warning "homebrew not found, skipping cask packages"
    return
  fi

  # Validate packages
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run_package_list "cask" "${pkg_array[@]}"
  else
    log_info "Installing cask packages: ${pkg_array[*]}"

    # Individual installation for compatibility
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      if ! eval "brew install --cask ${quoted_pkg}" 2>&1; then
        failed_packages+=("${pkg}")
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to install cask packages: ${failed_packages[*]}"
    fi
  fi
}

# Remove homebrew packages
remove_homebrew_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Check if brew is available
  if ! command -v brew > /dev/null 2>&1; then
    log_warning "homebrew not found, skipping homebrew package removal"
    return
  fi

  # Validate packages
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "remove via homebrew: $(format_package_list "${pkg_array[@]}")"
  else
    log_info "Removing homebrew packages: ${pkg_array[*]}"

    # Individual removal
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      if ! eval "brew uninstall ${quoted_pkg}" 2>&1; then
        failed_packages+=("${pkg}")
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to remove homebrew packages: ${failed_packages[*]}"
    fi
  fi
}

# Remove cask packages
remove_cask_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Check if brew is available
  if ! command -v brew > /dev/null 2>&1; then
    log_warning "homebrew not found, skipping cask package removal"
    return
  fi

  # Validate packages
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "remove via cask: $(format_package_list "${pkg_array[@]}")"
  else
    log_info "Removing cask packages: ${pkg_array[*]}"

    # Individual removal
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      if ! eval "brew uninstall --cask ${quoted_pkg}" 2>&1; then
        failed_packages+=("${pkg}")
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to remove cask packages: ${failed_packages[*]}"
    fi
  fi
}

# Install opkg packages (Entware package manager on routers)
install_opkg_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Validate packages first (for security)
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Check if opkg is available
  if ! command -v opkg > /dev/null 2>&1; then
    log_error "opkg not found, skipping opkg packages"
    return
  fi

  # Convert to array for processing (Bash 3.2 compatible)
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "update opkg package list"
    log_dry_run_package_list "opkg" "${pkg_array[@]}"
  else
    log_info "Updating opkg package list..."
    if ! opkg update; then
      log_warning "Failed to update opkg package list, continuing anyway..."
    fi

    log_info "Installing opkg packages: ${pkg_array[*]}"

    # Try installing all packages at once first
    local quoted_packages
    quoted_packages=$(quote_packages "${pkg_array[@]}")

    if ! eval "opkg install ${quoted_packages}" 2>&1; then
      # If batch installation fails, try individual installation for better error handling
      local failed_packages=()
      local individual_quoted
      for pkg in "${pkg_array[@]}"; do
        printf -v individual_quoted '%q' "${pkg}"
        if ! eval "opkg install ${individual_quoted}" 2>&1; then
          failed_packages+=("${pkg}")
        fi
      done

      # Report any failures
      if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_error "Failed to install opkg packages: ${failed_packages[*]}"
      fi
    fi
  fi
}

# Remove opkg packages
remove_opkg_packages() {
  local packages="$1" dry_run="$2"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Validate packages first
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Check if opkg is available
  if ! command -v opkg > /dev/null 2>&1; then
    log_warning "opkg not found, skipping opkg package removal"
    return
  fi

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "remove via opkg: $(format_package_list "${pkg_array[@]}")"
  else
    log_info "Removing opkg packages: ${pkg_array[*]}"

    # Batch removal with proper quoting
    local quoted_packages
    quoted_packages=$(quote_packages "${pkg_array[@]}")

    if ! eval "opkg remove ${quoted_packages}"; then
      log_warning "Failed to remove some opkg packages: ${pkg_array[*]}"
    fi
  fi
}

# Remove nix packages (individual mode)
remove_nix_packages() {
  local packages="$1" nix_version="$2" dry_run="$3"

  # Handle empty package lists
  [[ -z "${packages}" ]] && return 0

  # Check if nix is available
  if ! command -v nix > /dev/null 2>&1; then
    log_warning "nix not found, skipping nix package removal"
    return
  fi

  # Validate packages
  local valid_packages
  valid_packages=$(validate_and_filter_packages "${packages}")
  [[ -z "${valid_packages}" ]] && return 0

  # Convert to array for processing
  local pkg_array=()
  populate_package_array "${valid_packages}" pkg_array

  if [[ "${dry_run}" = true ]]; then
    log_dry_run "remove via nixpkgs-${nix_version}: $(format_package_list "${pkg_array[@]}")"
  else
    log_info "Removing nixpkgs-${nix_version} packages: ${pkg_array[*]}"

    # Individual removal (nix requirement)
    local failed_packages=()
    for pkg in "${pkg_array[@]}"; do
      local quoted_pkg
      printf -v quoted_pkg '%q' "${pkg}"

      # Use nix profile remove - package names are stored in the profile
      # List profiles to find the package name
      if ! eval "nix profile remove ${quoted_pkg}" 2> /dev/null; then
        # If direct removal fails, try finding by package name in profile list
        local profile_entries
        profile_entries=$(nix profile list 2> /dev/null | grep -F "${pkg}" | awk '{print $1}' || true)

        if [[ -n "${profile_entries}" ]]; then
          # Remove by profile index
          while IFS= read -r entry_index; do
            if ! nix profile remove "${entry_index}"; then
              failed_packages+=("${pkg}")
              break
            fi
          done <<< "${profile_entries}"
        else
          # Package not found in profile
          log_info "Package not installed or already removed: ${pkg}"
        fi
      fi
    done

    # Report any failures
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      log_warning "Failed to remove nix packages: ${failed_packages[*]}"
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

  # Update system packages first
  log_info "Updating system packages (required for fresh installs)..."
  if ! sudo pacman -Syu --noconfirm; then
    log_warning "System update failed, but continuing with yay installation..."
  fi

  # Install archlinuxcn-keyring first, if it fails, try without it
  if ! sudo pacman -S --needed --noconfirm archlinuxcn-keyring; then
    log_warning "Failed to install archlinuxcn-keyring, retrying..."
    # Force refresh keys and try again
    if sudo pacman-key --refresh-keys; then
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

# Simplified package handling dispatcher
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
    log_info "Installing $(echo "${context}" | tr '[:upper:]' '[:lower:]') packages for ${platform}..."
  fi

  case "${platform}" in
    "arch")
      # Refresh mirrors first for fastest downloads
      refresh_arch_mirrors "${dry_run}"

      # Install yay first for unified package management
      install_yay "${dry_run}"

      # Extract cleanup packages and remove them first
      local pacman_cleanup yay_cleanup
      pacman_cleanup=$(extract_cleanup_packages_from_yaml "${platform}" "pacman" "${packages_file}")
      yay_cleanup=$(extract_cleanup_packages_from_yaml "${platform}" "yay" "${packages_file}")

      remove_pacman_packages "${pacman_cleanup}" "${dry_run}"
      remove_yay_packages "${yay_cleanup}" "${dry_run}"

      # Extract and install packages
      local pacman_packages yay_packages
      pacman_packages=$(extract_packages_from_yaml "${platform}" "pacman" "${packages_file}")
      yay_packages=$(extract_packages_from_yaml "${platform}" "yay" "${packages_file}")

      install_pacman_packages "${pacman_packages}" "${dry_run}"
      install_yay_packages "${yay_packages}" "${dry_run}"
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
      # Extract cleanup packages and remove them first
      local homebrew_cleanup cask_cleanup
      homebrew_cleanup=$(extract_cleanup_packages_from_yaml "${platform}" "homebrew" "${packages_file}")
      cask_cleanup=$(extract_cleanup_packages_from_yaml "${platform}" "cask" "${packages_file}")

      remove_homebrew_packages "${homebrew_cleanup}" "${dry_run}"
      remove_cask_packages "${cask_cleanup}" "${dry_run}"

      # Use Brewfile for batch installation on macOS
      install_packages_with_brewfile "${packages_file}" "${platform}" "${dry_run}"
      ;;
    "nix")
      # Process versioned nixpkgs (e.g., nixpkgs-25.05)
      # Find all nixpkgs-* managers in the file
      if [[ -f "${packages_file}" ]]; then
        # First pass: remove cleanup packages
        while IFS= read -r manager; do
          [[ -n "${manager}" ]] || continue
          local nix_version="${manager#nixpkgs-}"
          local nix_cleanup
          nix_cleanup=$(extract_cleanup_packages_from_yaml "${platform}" "${manager}" "${packages_file}")
          remove_nix_packages "${nix_cleanup}" "${nix_version}" "${dry_run}"
        done < <(grep -E "^  nixpkgs-[0-9]+\.[0-9]+:" "${packages_file}" 2> /dev/null | sed 's/:.*//; s/^  //' || true)

        # Second pass: install packages
        while IFS= read -r manager; do
          [[ -n "${manager}" ]] || continue
          local nix_version="${manager#nixpkgs-}"
          local nix_packages
          nix_packages=$(extract_packages_from_yaml "${platform}" "${manager}" "${packages_file}")
          install_nix_packages "${nix_packages}" "${nix_version}" "${dry_run}"
        done < <(grep -E "^  nixpkgs-[0-9]+\.[0-9]+:" "${packages_file}" 2> /dev/null | sed 's/:.*//; s/^  //' || true)
      fi
      ;;
    "freshtomato")
      # Extract cleanup packages and remove them first
      local opkg_cleanup
      opkg_cleanup=$(extract_cleanup_packages_from_yaml "${platform}" "opkg" "${packages_file}")
      remove_opkg_packages "${opkg_cleanup}" "${dry_run}"

      # Extract and install opkg packages (FreshTomato uses Entware/opkg)
      local opkg_packages
      opkg_packages=$(extract_packages_from_yaml "${platform}" "opkg" "${packages_file}")
      install_opkg_packages "${opkg_packages}" "${dry_run}"
      ;;
    *)
      log_warning "Unknown platform: ${platform} - skipping package installation"
      ;;
  esac
}
