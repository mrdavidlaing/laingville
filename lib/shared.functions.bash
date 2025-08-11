#!/usr/bin/env bash

# Shared functions for both setup-user, setup-secrets, and setup-server scripts
# Note: Do not set -e here as functions need to handle their own error cases

# Security functions are sourced independently by calling scripts

# Detect the current operating system
# Returns: "macos", "linux", "windows", or "unknown"
detect_os() {
    case "$(uname -s)" in
        "Darwin") echo "macos" ;;
        "Linux") echo "linux" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Platform detection (builds on detect_os for sub-platform identification)
detect_platform() {
    local base_os=$(detect_os)
    
    case "$base_os" in
        "macos"|"windows")
            # For macOS/Windows, platform equals OS
            echo "$base_os"
            ;;
        "linux")
            # For Linux, detect the specific distribution/environment
            if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
                echo "wsl"
            elif command -v pacman >/dev/null 2>&1; then
                echo "arch"
            else
                echo "linux"  # Generic Linux
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect username mapping from system username to dotfiles directory
detect_username() {
    local system_user=$(whoami)
    case "$system_user" in
        "david"|"mrdavidlaing"|*"DavidLaing"*)
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
        yq e ".${platform}.${manager}[]" "$packages_file" 2>/dev/null | grep -v '^null$' | \
        sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//' || true
    else
        # Safer sed parsing with limits
        head -n 1000 "$packages_file" | \
        sed -n "/^${platform}:/,/^[a-z]/p" | \
        sed -n "/^  ${manager}:/,/^  [a-z]/p" | \
        grep "^    - " | sed 's/^    - //' | \
        sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//' | \
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
        "yay") packages=$(get_packages_from_file "$platform" "yay" "$packages_file") ;;
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

# Install yay AUR helper from ArchLinuxCN repository
install_yay() {
    local dry_run="$1"
    
    if [ "$dry_run" = true ]; then
        log_dry_run "Would install yay AUR helper from ArchLinuxCN repository"
        return 0
    fi
    
    # Check if yay is already installed
    if command -v yay >/dev/null 2>&1; then
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
        echo '[archlinuxcn]' | sudo tee -a /etc/pacman.conf >/dev/null
        echo 'Server = https://repo.archlinuxcn.org/$arch' | sudo tee -a /etc/pacman.conf >/dev/null
        
        # Refresh package databases
        sudo pacman -Sy
        
        # Install keyring with proper error handling
        log_info "Installing ArchLinuxCN keyring..."
        if ! sudo pacman -S --needed --noconfirm archlinuxcn-keyring; then
            log_warning "Failed to install archlinuxcn-keyring directly, trying manual key import..."
            
            # Manual key import as fallback
            sudo pacman-key --recv-keys 7931B6D628C8D93F 2>/dev/null || true
            sudo pacman-key --lsign-key 7931B6D628C8D93F 2>/dev/null || true
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
        "arch"|"wsl")
            # Install yay first for unified package management
            install_yay "$dry_run"
            
            # Use yay for all packages (official + AUR combined)
            process_packages "yay" "yay -S --needed --noconfirm" "$platform" "$dry_run" "$packages_file"
            ;;
        "windows")
            process_packages "winget" "winget install --id=" "$platform" "$dry_run" "$packages_file"
            # Handle WSL2 Arch setup if WSL2 is available
            setup_wsl2_arch "$dry_run" "$packages_file"
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

# Setup WSL2 Arch environment - uses existing arch packages
setup_wsl2_arch() {
    local dry_run="$1" packages_file="$2"
    
    # Check if WSL2 is available
    if ! command -v wsl >/dev/null 2>&1; then
        if [ "$dry_run" = true ]; then
            log_dry_run "WSL2 not available - would skip WSL2 setup"
        else
            log_info "WSL2 not available - skipping WSL2 setup"
        fi
        return
    fi
    
    # Check if Arch Linux is installed in WSL2 (handle spaced output from WSL)
    if ! wsl --list --quiet 2>/dev/null | tr -d ' \0' | grep -i arch >/dev/null 2>&1; then
        if [ "$dry_run" = true ]; then
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
    local arch_status=$(wsl --list --verbose 2>/dev/null | tr -d ' \0' | grep -i arch | awk '{print $3}' || echo "Stopped")
    if [[ "$arch_status" != *"Running"* ]]; then
        if [ "$dry_run" = true ]; then
            log_dry_run "WSL2 Arch not running - would start it automatically"
        else
            log_info "Starting WSL2 Arch Linux distribution..."
            # Start the distribution by running a simple command
            if wsl -d archlinux -- echo "WSL2 Arch started" >/dev/null 2>&1; then
                log_info "WSL2 Arch Linux started successfully"
            else
                log_error "Failed to start WSL2 Arch Linux"
                return 1
            fi
        fi
    fi
    
    if [ "$dry_run" = true ]; then
        log_dry_run "WSL2 Arch found - would run Arch setup inside WSL2"
    else
        log_info "Setting up WSL2 Arch environment..."
        
        # Convert Windows path to WSL2 format for the project root
        local wsl_project_path
        wsl_project_path=$(wsl -d archlinux -- wslpath "$(cd "$PROJECT_ROOT" && pwd -W)")
        
        # Run setup-user inside WSL2 Arch - it will use the arch: packages section
        wsl -d archlinux -- bash -c "
            # Set up environment - WSL2 Arch uses same dotfiles via /mnt/c
            export PROJECT_ROOT='$wsl_project_path'
            export DOTFILES_DIR='$wsl_project_path/dotfiles/mrdavidlaing'
            
            # Run the normal Arch setup (will process arch: packages section)
            ./setup.sh user
        "
        
        if [ $? -eq 0 ]; then
            log_success "WSL2 Arch setup completed successfully"
        else
            log_warning "WSL2 Arch setup encountered some issues"
        fi
    fi
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