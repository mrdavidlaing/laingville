#!/bin/bash

# Functions for setup-user script
# Note: Do not set -e here as functions need to handle their own error cases

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

# Simple YAML parsing using sed
get_packages() {
    local platform="$1" manager="$2" file="$DOTFILES_DIR/packages.yml"
    [ -f "$file" ] || return
    
    # Extract platform section, then manager section, then package list
    sed -n "/${platform}:/,/^[a-z]/p" "$file" | \
    sed -n "/${manager}:/,/^  [a-z]/p" | \
    grep "^    - " | sed 's/^    - //'
}

# Get custom scripts from YAML
get_custom_scripts() {
    local platform="$1" file="$DOTFILES_DIR/packages.yml"
    [ -f "$file" ] || return
    
    # Extract platform section, then custom section, then script list
    sed -n "/${platform}:/,/^[a-z]/p" "$file" | \
    sed -n "/custom:/,/^  [a-z]/p" | \
    grep "^    - " | sed 's/^    - //'
}

# Process packages for a manager
process_packages() {
    local manager="$1" cmd="$2" platform="$3" dry_run="$4"
    local packages
    
    case "$manager" in
        "pacman") packages=$(get_packages "$platform" "pacman") ;;
        "yay") packages=$(get_packages "$platform" "aur") ;;
        "winget") packages=$(get_packages "$platform" "winget") ;;
    esac
    
    [ -z "$packages" ] && return
    
    if [ "$dry_run" = true ]; then
        local pkg_list=$(echo $packages | tr '\n' ' ' | sed 's/ *$//')
        echo "Would install via $manager: ${pkg_list// /, }"
    else
        echo "Installing $manager packages: $(echo $packages | tr '\n' ' ')"
        if [ "$manager" = "yay" ] && ! command -v yay >/dev/null 2>&1; then
            echo "Warning: yay not found, skipping AUR packages"
            return
        fi
        
        if [ "$manager" = "winget" ]; then
            for pkg in $packages; do
                $cmd"$pkg" --silent --accept-package-agreements --accept-source-agreements || echo "Warning: Failed to install $pkg"
            done
        else
            echo $packages | xargs $cmd || echo "Warning: Some $manager packages failed to install"
        fi
    fi
}

# Validate script name for security
validate_script_name() {
    local script="$1"
    # Only allow alphanumeric, underscore, hyphen
    if [[ ! "$script" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid script name contains illegal characters: $script"
        return 1
    fi
    # Prevent path traversal
    if [[ "$script" == *".."* ]] || [[ "$script" == *"/"* ]]; then
        echo "Error: Script name contains path traversal characters: $script"
        return 1
    fi
    # Reasonable length limit
    if [ ${#script} -gt 50 ]; then
        echo "Error: Script name too long: $script"
        return 1
    fi
    return 0
}

# Process custom scripts
process_custom_scripts() {
    local platform="$1" dry_run="$2"
    local scripts_dir="$SCRIPT_DIR/dotfiles/shared/scripts"
    local scripts
    
    scripts=$(get_custom_scripts "$platform")
    [ -z "$scripts" ] && return
    
    if [ "$dry_run" = true ]; then
        echo "Would run custom scripts:"
        for script in $scripts; do
            if ! validate_script_name "$script"; then
                continue
            fi
            if [ -f "$scripts_dir/${script}.bash" ]; then
                echo "Would run custom script: $script"
            else
                echo "Warning: Script not found: $script"
            fi
        done
    else
        echo "Running custom scripts..."
        for script in $scripts; do
            if ! validate_script_name "$script"; then
                continue
            fi
            local script_path="$scripts_dir/${script}.bash"
            if [ -f "$script_path" ] && [ -x "$script_path" ]; then
                echo "Running custom script: $script"
                if "$script_path" "$dry_run"; then
                    echo "Custom script $script completed successfully"
                else
                    echo "Warning: Custom script $script failed"
                fi
            else
                echo "Warning: Script not found or not executable: $script"
            fi
        done
    fi
}

# Handle all package management
handle_packages() {
    local platform="$1" dry_run="$2"
    local packages_file="$DOTFILES_DIR/packages.yml"
    
    if [ ! -f "$packages_file" ]; then
        if [ "$dry_run" = true ]; then
            echo "No packages.yml found - no packages would be installed"
        else
            echo "No packages.yml found - skipping package installation"
        fi
        return
    fi
    
    if [ "$dry_run" = true ]; then
        echo "PACKAGES ($platform):"
    else
        echo "Installing packages for $platform..."
    fi
    
    case "$platform" in
        "arch")
            process_packages "pacman" "sudo pacman -S --needed --noconfirm" "$platform" "$dry_run"
            process_packages "yay" "yay -S --needed --noconfirm" "$platform" "$dry_run"
            process_custom_scripts "$platform" "$dry_run"
            ;;
        "windows")
            process_packages "winget" "winget install --id=" "$platform" "$dry_run"
            process_custom_scripts "$platform" "$dry_run"
            ;;
        *)
            echo "Unrecognised platform: $platform. Not attempting to install packages or custom scripts."
            ;;
    esac
}

# Show symlinks (dry-run mode)
show_symlinks() {
    local src_dir="$1" dest_dir="$2" relative_path="$3"
    
    shopt -s dotglob nullglob
    for item in "$src_dir"/*; do
        if [ -f "$item" ]; then
            local filename=$(basename "$item")
            [ "$filename" = "packages.yml" ] && continue
            
            local target="$dest_dir/$filename"
            local action="create"
            if [ -e "$target" ]; then
                [ -L "$target" ] && action="update" || action="replace"
            fi
            
            if [ -n "$relative_path" ]; then
                echo "Would $action: ~/$relative_path$filename -> $item"
            else
                echo "Would $action: ~/$filename -> $item"
            fi
        elif [ -d "$item" ]; then
            local dirname=$(basename "$item")
            show_symlinks "$item" "$dest_dir/$dirname" "${relative_path}${dirname}/"
        fi
    done
    shopt -u dotglob nullglob
}

# Create symlinks (normal mode)
create_symlinks() {
    local src_dir="$1" dest_dir="$2" relative_path="$3"
    
    shopt -s dotglob nullglob
    for item in "$src_dir"/*; do
        if [ -f "$item" ]; then
            local filename=$(basename "$item")
            [ "$filename" = "packages.yml" ] && continue
            
            local target="$dest_dir/$filename"
            [ -e "$target" ] && rm -f "$target"
            ln -s "$item" "$target"
            
            if [ -n "$relative_path" ]; then
                echo "Linked: $relative_path$filename"
            else
                echo "Linked: $filename"
            fi
        elif [ -d "$item" ]; then
            local dirname=$(basename "$item")
            local target_dir="$dest_dir/$dirname"
            mkdir -p "$target_dir"
            create_symlinks "$item" "$target_dir" "${relative_path}${dirname}/"
        fi
    done
    shopt -u dotglob nullglob
}

# Setup systemd user services
setup_systemd_services() {
    local dry_run="$1"
    
    # Check if we have systemd user services to enable
    local systemd_dir="$HOME/.config/systemd/user"
    if [ ! -d "$systemd_dir" ]; then
        return
    fi
    
    # Look for timer files to enable
    local timers=($(find "$systemd_dir" -name "*.timer" -exec basename {} \; 2>/dev/null))
    
    if [ ${#timers[@]} -eq 0 ]; then
        return
    fi
    
    if [ "$dry_run" = true ]; then
        echo "SYSTEMD SERVICES:"
        for timer in "${timers[@]}"; do
            echo "Would enable and start: $timer"
        done
    else
        echo "Setting up systemd user services..."
        systemctl --user daemon-reload
        
        for timer in "${timers[@]}"; do
            echo "Enabling $timer..."
            systemctl --user enable --now "$timer" || echo "Warning: Failed to enable $timer"
        done
    fi
}

# Configure terminal font
configure_terminal_font() {
    local dry_run="$1"
    
    # Check if the font configuration script exists in dotfiles
    local font_script_source="$DOTFILES_DIR/.local/bin/configure-terminal-font"
    local font_script_target="$HOME/.local/bin/configure-terminal-font"
    
    if [ ! -f "$font_script_source" ]; then
        return
    fi
    
    if [ "$dry_run" = true ]; then
        echo "TERMINAL FONT:"
        echo "Would configure terminal to use JetBrains Mono Nerd Font"
    else
        echo "Configuring terminal font..."
        if command -v gsettings >/dev/null 2>&1; then
            "$font_script_target" || echo "Warning: Failed to configure terminal font"
        else
            echo "Warning: gsettings not available, skipping terminal font configuration"
        fi
    fi
}

# Setup 1Password config on first run only
setup_1password_config() {
    local dry_run="$1"
    
    # Check if 1Password settings template exists in dotfiles
    local template_source="$DOTFILES_DIR/.config/1Password/settings/settings.json"
    local settings_target="$HOME/.config/1Password/settings/settings.json"
    
    if [ ! -f "$template_source" ]; then
        return
    fi
    
    if [ "$dry_run" = true ]; then
        echo "1PASSWORD CONFIG:"
        if [ -f "$settings_target" ]; then
            echo "Would skip 1Password config (already exists)"
        else
            echo "Would install 1Password settings template (first run only)"
        fi
    else
        if [ -f "$settings_target" ]; then
            echo "Skipping 1Password config (already exists)"
        else
            echo "Installing 1Password settings template..."
            mkdir -p "$(dirname "$settings_target")"
            cp "$template_source" "$settings_target"
            echo "1Password settings template installed"
        fi
    fi
}