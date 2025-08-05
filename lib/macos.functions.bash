#!/usr/bin/env bash

# macOS-specific functions for setup-user script
# Note: Do not set -e here as functions need to handle their own error cases

# Functions assume shared, security and logging functions are already sourced by calling script

# Install and update Homebrew
install_homebrew() {
    local dry_run="$1"
    
    if [ "$dry_run" = true ]; then
        echo "HOMEBREW SETUP:"
        if ! command -v brew >/dev/null 2>&1; then
            log_dry_run "install Homebrew via official installer"
        else
            log_dry_run "update Homebrew"
        fi
        return
    fi
    
    if ! command -v brew >/dev/null 2>&1; then
        log_info "Installing Homebrew..."
        # NOTE: The following command trusts the Homebrew installation script from GitHub.
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
    
    if [ "$dry_run" = true ]; then
        echo "MACOS SYSTEM CONFIG:"
        log_dry_run "set keyboard repeat rate (KeyRepeat=1, InitialKeyRepeat=15)"
        log_dry_run "enable font smoothing (AppleFontSmoothing=1)"
        log_dry_run "set Alacritty as default terminal for shell executables"
        log_dry_run "disable press-and-hold for VSCode and Cursor"
        log_dry_run "set system locale to en_IE.UTF-8"
        return
    fi
    
    log_info "Configuring macOS system settings..."
    
    # Keyboard settings for blazingly fast repeat rate
    defaults write NSGlobalDomain KeyRepeat -int 1
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    
    # Enable font smoothing for better terminal font rendering
    defaults write NSGlobalDomain AppleFontSmoothing -int 1
    
    # Set Alacritty as default terminal for shell executables
    defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType="public.unix-executable";LSHandlerRoleShell="com.alacritty.alacritty";}'
    
    # Disable press-and-hold for keys for VSCode and Cursor
    defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
    defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false
    
    # Set system locale to en_IE.UTF-8
    defaults write NSGlobalDomain AppleLocale -string "en_IE"
    defaults write NSGlobalDomain AppleLanguages -array "en-IE" "en"
    
    log_success "macOS system configuration complete"
}