#!/bin/bash

# Functions for setup-user script
# Note: Do not set -e here as functions need to handle their own error cases

# Source shared functions (which includes security functions)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.functions.bash"

# Get user packages using shared function but with user-specific path
get_packages() {
    local platform="$1" manager="$2" 
    local packages_file="$DOTFILES_DIR/packages.yml"
    get_packages_from_file "$platform" "$manager" "$packages_file"
}

# Get custom scripts from YAML
get_custom_scripts() {
    local platform="$1" file="$DOTFILES_DIR/packages.yml"
    [ -f "$file" ] || return 0
    
    # Use secure YAML parsing
    if ! validate_yaml_file "$file"; then
        log_security_event "INVALID_YAML" "YAML validation failed for: $file"
        return 1
    fi
    
    # Extract platform section, then custom section, then script list
    sed -n "/${platform}:/,/^[a-z]/p" "$file" | \
    sed -n "/custom:/,/^  [a-z]/p" | \
    grep "^    - " | sed 's/^    - //'
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

# Process custom scripts with security validation
process_custom_scripts() {
    local platform="$1" dry_run="$2"
    local scripts_dir="$SCRIPT_DIR/dotfiles/shared/scripts"
    local scripts
    
    scripts=$(get_custom_scripts "$platform")
    [ -z "$scripts" ] && return 0  # Explicitly return success when no scripts
    
    # Validate scripts directory (allow symlinks for this validation)
    if ! validate_path_traversal "$scripts_dir" "$SCRIPT_DIR" "true"; then
        log_security_event "INVALID_SCRIPTS_DIR" "Scripts directory outside allowed path: $scripts_dir"
        echo "Error: Scripts directory outside allowed path" >&2
        return 1
    fi
    
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
            
            # Additional security validation for script path
            if ! validate_path_traversal "$script_path" "$SCRIPT_DIR"; then
                log_security_event "INVALID_SCRIPT_PATH" "Script path outside allowed area: $script_path"
                echo "Warning: Script path outside allowed area: $script" >&2
                continue
            fi
            
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

# Handle user package management with custom scripts  
handle_packages() {
    local platform="$1" dry_run="$2"
    local packages_file="$DOTFILES_DIR/packages.yml"
    
    # Use secure package handling from shared functions
    handle_packages_from_file "$platform" "$dry_run" "$packages_file" "USER"
    
    # Also process custom scripts for this platform
    process_custom_scripts "$platform" "$dry_run"
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

# Securely create symlinks with path validation
create_symlinks() {
    local src_dir="$1" dest_dir="$2" relative_path="$3"
    
    # Validate source and destination directories
    if ! validate_path_traversal "$src_dir" "$SCRIPT_DIR/dotfiles"; then
        log_security_event "INVALID_SRC_DIR" "Source directory outside allowed path: $src_dir"
        echo "Error: Source directory outside allowed dotfiles path" >&2
        return 1
    fi
    
    if ! validate_path_traversal "$dest_dir" "$HOME" "true"; then
        log_security_event "INVALID_DEST_DIR" "Destination directory outside home: $dest_dir"
        echo "Error: Destination directory outside home directory" >&2
        return 1
    fi
    
    shopt -s dotglob nullglob
    for item in "$src_dir"/*; do
        if [ -f "$item" ]; then
            local filename=$(basename "$item")
            [ "$filename" = "packages.yml" ] && continue
            
            # Sanitize filename for security
            local safe_filename
            safe_filename=$(sanitize_filename "$filename")
            if [ $? -ne 0 ] || [ -z "$safe_filename" ]; then
                log_security_event "UNSAFE_FILENAME" "Skipping unsafe filename: $filename"
                echo "Warning: Skipping unsafe filename: $filename" >&2
                continue
            fi
            
            # Use original filename for the actual link (after validation)
            local target="$dest_dir/$filename"
            
            # Additional validation - ensure target is within home directory
            if ! validate_path_traversal "$target" "$HOME" "true"; then
                log_security_event "INVALID_TARGET" "Target outside home directory: $target"
                echo "Warning: Skipping link outside home directory: $target" >&2
                continue
            fi
            
            # Remove existing file/symlink safely
            if [ -e "$target" ] || [ -L "$target" ]; then
                rm -f "$target"
            fi
            
            # Create symlink
            if ln -s "$item" "$target" 2>/dev/null; then
                if [ -n "$relative_path" ]; then
                    echo "Linked: $relative_path$filename"
                else
                    echo "Linked: $filename"
                fi
            else
                echo "Warning: Failed to create symlink: $target" >&2
            fi
        elif [ -d "$item" ]; then
            local dirname=$(basename "$item")
            
            # Validate directory name
            local safe_dirname
            safe_dirname=$(sanitize_filename "$dirname")
            if [ $? -ne 0 ] || [ -z "$safe_dirname" ]; then
                log_security_event "UNSAFE_DIRNAME" "Skipping unsafe directory name: $dirname"
                echo "Warning: Skipping unsafe directory name: $dirname" >&2
                continue
            fi
            
            local target_dir="$dest_dir/$dirname"
            
            # Validate target directory
            if ! validate_path_traversal "$target_dir" "$HOME" "true"; then
                log_security_event "INVALID_TARGET_DIR" "Target directory outside home: $target_dir"
                echo "Warning: Skipping directory outside home: $target_dir" >&2
                continue
            fi
            
            mkdir -p "$target_dir"
            create_symlinks "$item" "$target_dir" "${relative_path}${dirname}/"
        fi
    done
    shopt -u dotglob nullglob
}

# Securely setup systemd user services with validation
setup_systemd_services() {
    local dry_run="$1"
    
    # In dry-run mode, check dotfiles directory; in normal mode, check HOME
    local systemd_dir
    if [ "$dry_run" = true ]; then
        systemd_dir="$DOTFILES_DIR/.config/systemd/user"
    else
        systemd_dir="$HOME/.config/systemd/user"
    fi
    
    if [ ! -d "$systemd_dir" ]; then
        return
    fi
    
    # Validate systemd directory
    local expected_base
    if [ "$dry_run" = true ]; then
        expected_base="$DOTFILES_DIR"
    else
        expected_base="$HOME"
        # Also validate directory is within home in normal mode
        if ! validate_path_traversal "$systemd_dir" "$HOME" "true"; then
            log_security_event "INVALID_SYSTEMD_DIR" "Systemd directory outside home: $systemd_dir"
            echo "Error: Systemd directory outside home directory" >&2
            return 1
        fi
    fi
    
    # Safely find and validate timer files
    local timers=()
    while IFS= read -r -d '' timer_path; do
        local timer_name=$(basename "$timer_path")
        
        # Validate systemd unit name format
        if validate_systemd_unit_name "$timer_name"; then
            timers+=("$timer_name")
        else
            log_security_event "INVALID_UNIT_NAME" "Skipping invalid systemd unit: $timer_name"
            echo "Warning: Skipping invalid systemd unit name: $timer_name" >&2
        fi
    done < <(find "$systemd_dir" -maxdepth 1 -name "*.timer" -type f -print0 2>/dev/null)
    
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
            # Use quoted unit name for safety
            if ! systemctl --user enable --now "$timer"; then
                echo "Warning: Failed to enable $timer" >&2
            fi
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