#!/usr/bin/env bats

# Unit tests for YAML parsing functions using real dotfiles

setup() {
    cd "$BATS_TEST_DIRNAME/../.."
    
    # Source just the functions file
    source ./setup-user.functions.bash
}

@test "get_packages extracts mrdavidlaing pacman packages correctly" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    result=$(get_packages "arch" "pacman")
    
    [[ "$result" =~ "hyprland" ]]
    [[ "$result" =~ "waybar" ]]
    [[ "$result" =~ "rofi" ]]
    [[ "$result" =~ "thunar" ]]
    [[ "$result" =~ "bats" ]]
}

@test "get_packages extracts mrdavidlaing AUR packages correctly" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    result=$(get_packages "arch" "aur")
    
    [[ "$result" =~ "vivaldi" ]]
}

@test "get_packages extracts timmmmmmer packages correctly" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/timmmmmmer"
    
    result=$(get_packages "arch" "pacman")
    
    [[ "$result" =~ "hyprland" ]]
    [[ "$result" =~ "gimp" ]]  # timmmmmmer has gimp, mrdavidlaing doesn't
    [[ "$result" =~ "bats" ]]
}

@test "get_packages handles missing platform gracefully" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    result=$(get_packages "nonexistent" "pacman")
    
    [ -z "$result" ]  # Should return empty for unknown platform
}

@test "get_packages handles missing manager gracefully" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    result=$(get_packages "arch" "nonexistent")
    
    [ -z "$result" ]  # Should return empty for unknown manager
}

# Note: Missing file handling is tested in integration tests

@test "detect_platform returns arch on this system" {
    result=$(detect_platform)
    
    [ "$result" = "arch" ]  # Should detect arch on Arch Linux
}