#!/usr/bin/env bats

# Integration tests for setup-user script using real dotfiles

setup() {
    # Change to project root directory for all tests
    cd "$BATS_TEST_DIRNAME/../.."
}

@test "dry-run works for mrdavidlaing user" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    # Debug output on failure
    if [ "$status" -ne 0 ]; then
        echo "Exit status: $status"
        echo "Output: $output"
    fi
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY RUN MODE - No changes will be made" ]]
    [[ "$output" =~ "SYMLINKS:" ]]
    [[ "$output" =~ "Would update: ~/.config/hypr/hyprland.conf" ]]
    [[ "$output" =~ "PACKAGES (arch):" ]]
    [[ "$output" =~ "Would install via pacman:" ]]
    [[ "$output" =~ "hyprland" ]]
    [[ "$output" =~ "waybar" ]]
    [[ "$output" =~ "Would install via yay:" ]]
    [[ "$output" =~ "vivaldi" ]]
}

@test "dry-run works for timmmmmmer user" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/timmmmmmer"
    
    run ./setup-user --dry-run
    
    # Debug output on failure
    if [ "$status" -ne 0 ]; then
        echo "Exit status: $status"
        echo "Output: $output"
    fi
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY RUN MODE - No changes will be made" ]]
    [[ "$output" =~ "SYMLINKS:" ]]
    [[ "$output" =~ "PACKAGES (arch):" ]]
    [[ "$output" =~ "Would install via pacman:" ]]
    [[ "$output" =~ "hyprland" ]]
    [[ "$output" =~ "gimp" ]]  # timmmmmmer has gimp, mrdavidlaing doesn't
}

@test "argument parsing handles unknown options correctly" {
    run ./setup-user --invalid
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option: --invalid" ]]
    [[ "$output" =~ "Usage: ./setup-user [--dry-run]" ]]
}

@test "script runs without arguments (normal mode would work)" {
    # We'll use a non-existent dotfiles dir to avoid side effects
    export DOTFILES_DIR="/tmp/nonexistent"
    
    run ./setup-user
    
    [ "$status" -eq 1 ]  # Should fail due to missing directory
    [[ "$output" =~ "Error: Dotfiles directory /tmp/nonexistent does not exist" ]]
}