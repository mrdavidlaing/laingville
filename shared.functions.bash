#!/bin/bash

# Shared functions for both setup-user and setup-server scripts
# Note: Do not set -e here as functions need to handle their own error cases

# Source security functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/security.functions.bash"

# Platform detection
detect_platform() {
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ -n "$WINDIR" ]]; then
        echo "windows"
    elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
    else
        echo "unknown"
    fi
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
            echo "Warning: Skipping invalid package name: $pkg" >&2
        fi
    done <<< "$packages"
    
    [ ${#valid_packages[@]} -eq 0 ] && return
    
    if [ "$dry_run" = true ]; then
        local pkg_list=$(printf '%s, ' "${valid_packages[@]}")
        pkg_list=${pkg_list%, }  # Remove trailing comma
        echo "Would install via $manager: $pkg_list"
    else
        echo "Installing $manager packages: ${valid_packages[*]}"
        
        # Check manager availability
        if [ "$manager" = "yay" ] && ! command -v yay >/dev/null 2>&1; then
            echo "Warning: yay not found, skipping AUR packages"
            return
        fi
        
        # Validate sudo requirements for system package managers
        if [[ "$cmd" =~ sudo ]]; then
            validate_sudo_requirements "package installation" || {
                echo "Error: Cannot install packages without proper sudo access" >&2
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
            echo "Warning: Failed to install packages: ${failed_packages[*]}" >&2
        fi
    fi
}

# Handle all package management - takes packages file as parameter
handle_packages_from_file() {
    local platform="$1" dry_run="$2" packages_file="$3" context="$4"
    
    if [ ! -f "$packages_file" ]; then
        if [ "$dry_run" = true ]; then
            echo "No packages.yml found - no packages would be installed"
        else
            echo "No packages.yml found - skipping package installation"
        fi
        return
    fi
    
    if [ "$dry_run" = true ]; then
        echo "${context} PACKAGES ($platform):"
    else
        echo "Installing ${context,,} packages for $platform..."
    fi
    
    case "$platform" in
        "arch")
            process_packages "pacman" "sudo pacman -S --needed --noconfirm" "$platform" "$dry_run" "$packages_file"
            process_packages "yay" "yay -S --needed --noconfirm" "$platform" "$dry_run" "$packages_file"
            ;;
        "windows")
            process_packages "winget" "winget install --id=" "$platform" "$dry_run" "$packages_file"
            ;;
        *)
            echo "Unknown platform: $platform - skipping package installation"
            ;;
    esac
}