#!/usr/bin/env bash

# Shared functions for both setup-user, setup-secrets, and setup-server scripts
# Note: Do not set -e here as functions need to handle their own error cases

# Security functions are sourced independently by calling scripts

# Platform detection
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ -n "${WINDIR:-}" ]]; then
        echo "windows"
    elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Detect username mapping from system username to dotfiles directory
detect_username() {
    local system_user=$(whoami)
    case "$system_user" in
        "david"|"mrdavidlaing")
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
    validate_yaml_key "$platform" || {
        log_security_event "INVALID_PLATFORM" "Invalid platform key: $platform"
        return 1
    }
    
    validate_yaml_key "$manager" || {
        log_security_event "INVALID_MANAGER" "Invalid manager key: $manager"
        return 1
    }
    
    validate_yaml_file "$packages_file" || {
        log_security_event "INVALID_YAML" "YAML validation failed for: $packages_file"
        return 1
    }
    
    # Use yq if available for safer parsing, fallback to sed
    if command -v yq >/dev/null 2>&1; then
        yq e ".${platform}.${manager}[]" "$packages_file" 2>/dev/null | grep -v '^null$' || true
    else
        # Safer sed parsing with limits
        head -n 1000 "$packages_file" | \
        sed -n "/^${platform}:/,/^[a-z]/p" | \
        sed -n "/^  ${manager}:/,/^  [a-z]/p" | \
        grep "^    - " | sed 's/^    - //' | \
        head -n 100  # Limit number of packages
    fi
}

# Secure package processing with validation
process_packages() {
    local manager="$1" cmd="$2" platform="$3" dry_run="$4" packages_file="$5"
    local packages
    
    # Validate manager name
    validate_yaml_key "$manager" || {
        log_security_event "INVALID_MANAGER" "Invalid package manager: $manager"
        return 1
    }
    
    case "$manager" in
        "pacman") packages=$(get_packages_from_file "$platform" "pacman" "$packages_file") ;;
        "yay") packages=$(get_packages_from_file "$platform" "aur" "$packages_file") ;;
        "winget") packages=$(get_packages_from_file "$platform" "winget" "$packages_file") ;;
        "homebrew") packages=$(get_packages_from_file "$platform" "homebrew" "$packages_file") ;;
        "cask") packages=$(get_packages_from_file "$platform" "cask" "$packages_file") ;;
        *) 
            log_security_event "UNKNOWN_MANAGER" "Unknown package manager: $manager"
            return 1
            ;;
    esac
    
    [ -z "$packages" ] && return
    
    # Validate each package name to prevent command injection
    local valid_packages=()
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if validate_package_name "$pkg"; then
            valid_packages+=("$pkg")
        else
            log_security_event "INVALID_PACKAGE" "Rejected invalid package name: $pkg"
            log_warning "Skipping invalid package name: $pkg"
        fi
    done <<< "$packages"
    
    [ ${#valid_packages[@]} -eq 0 ] && return
    
    if [ "$dry_run" = true ]; then
        local pkg_list=$(printf '%s, ' "${valid_packages[@]}")
        pkg_list=${pkg_list%, }  # Remove trailing comma
        log_dry_run "install via $manager: $pkg_list"
    else
        log_info "Installing $manager packages: ${valid_packages[*]}"
        
        # Check manager availability
        if [ "$manager" = "yay" ] && ! command -v yay >/dev/null 2>&1; then
            log_warning "yay not found, skipping AUR packages"
            return
        fi
        
        if [[ "$manager" =~ ^(homebrew|cask)$ ]] && ! command -v brew >/dev/null 2>&1; then
            log_warning "homebrew not found, skipping $manager packages"
            return
        fi
        
        # Validate sudo requirements for system package managers
        if [[ "$cmd" =~ sudo ]]; then
            validate_sudo_requirements "package installation" || {
                return 1
            }
        fi
        
        # Install packages securely - one by one to prevent injection
        local failed_packages=()
        for pkg in "${valid_packages[@]}"; do
            # Use printf %q to properly quote package names
            local quoted_pkg
            printf -v quoted_pkg '%q' "$pkg"
            
            if [ "$manager" = "winget" ]; then
                # Winget has different syntax
                if ! eval "$cmd$quoted_pkg --silent --accept-package-agreements --accept-source-agreements"; then
                    failed_packages+=("$pkg")
                fi
            else
                # Standard package managers
                if ! eval "$cmd $quoted_pkg"; then
                    failed_packages+=("$pkg")
                fi
            fi
        done
        
        # Report any failures
        if [ ${#failed_packages[@]} -gt 0 ]; then
            log_warning "Failed to install packages: ${failed_packages[*]}"
        fi
    fi
}

# Handle all package management - takes packages file as parameter
handle_packages_from_file() {
    local platform="$1" dry_run="$2" packages_file="$3" context="$4"
    
    if [ ! -f "$packages_file" ]; then
        if [ "$dry_run" = true ]; then
            log_info "No packages.yml found - no packages would be installed"
        else
            log_info "No packages.yml found - skipping package installation"
        fi
        return
    fi
    
    if [ "$dry_run" = true ]; then
        echo "${context} PACKAGES ($platform):"
    else
        log_info "Installing ${context,,} packages for $platform..."
    fi
    
    case "$platform" in
        "arch")
            process_packages "pacman" "sudo pacman -S --needed --noconfirm" "$platform" "$dry_run" "$packages_file"
            process_packages "yay" "yay -S --needed --noconfirm" "$platform" "$dry_run" "$packages_file"
            ;;
        "windows")
            process_packages "winget" "winget install --id=" "$platform" "$dry_run" "$packages_file"
            ;;
        "macos")
            process_packages "homebrew" "brew install" "$platform" "$dry_run" "$packages_file"
            process_packages "cask" "brew install --cask" "$platform" "$dry_run" "$packages_file"
            ;;
        *)
            log_warning "Unknown platform: $platform - skipping package installation"
            ;;
    esac
}

# Validate script name for security (shared)
validate_script_name() {
    local script="$1"
    if [[ ! "$script" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid script name contains illegal characters: $script"
        return 1
    fi
    if [[ "$script" == *".."* ]] || [[ "$script" == *"/"* ]]; then
        log_error "Script name contains path traversal characters: $script"
        return 1
    fi
    if [ ${#script} -gt 50 ]; then
        log_error "Script name too long: $script"
        return 1
    fi
    return 0
}