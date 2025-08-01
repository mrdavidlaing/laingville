#!/usr/bin/env bats

# Integration tests for different user scenarios

setup() {
    cd "$BATS_TEST_DIRNAME/../.."
}

@test "platform detection works correctly on this system" {
    # Test platform detection by checking the output of dry-run
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ]
    # On Arch Linux, should show arch platform
    [[ "$output" =~ "PACKAGES (arch):" ]]
}

@test "script handles missing packages.yml gracefully" {
    # Create a temporary directory with dotfiles but no packages.yml
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/.config"
    echo "test config" > "$temp_dir/.config/test.conf"
    
    export DOTFILES_DIR="$temp_dir"
    
    run ./setup-user --dry-run
    
    # Debug output on failure
    if [ "$status" -ne 0 ]; then
        echo "Exit status: $status"
        echo "Output: $output"
    fi
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SYMLINKS:" ]]
    [[ "$output" =~ "Would create: ~/.config/test.conf" ]]
    [[ "$output" =~ "No packages.yml found - no packages would be installed" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}

@test "script correctly excludes packages.yml from symlinks" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ]
    # Should not try to symlink packages.yml to home directory
    [[ ! "$output" =~ "packages.yml" ]] || [[ ! "$output" =~ "Would create: ~/packages.yml" ]]
}