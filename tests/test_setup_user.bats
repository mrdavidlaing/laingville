#!/usr/bin/env bats

# Essential tests for setup-user script

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    source ./setup-user.functions.bash
}

@test "dry-run shows expected output format" {
    # Set DOTFILES_DIR to a known good directory for CI compatibility
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: Exit status was $status, expected 0"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "DRY RUN MODE" ]] || {
        echo "FAILED: Missing 'DRY RUN MODE' in output"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "SYMLINKS:" ]] || {
        echo "FAILED: Missing 'SYMLINKS:' section in output"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "PACKAGES" ]] || {
        echo "FAILED: Missing 'PACKAGES' section in output"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "invalid arguments show proper error" {
    run ./setup-user --invalid
    
    [ "$status" -eq 1 ] || {
        echo "FAILED: Exit status was $status, expected 1"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "Unknown option" ]] || {
        echo "FAILED: Missing error message for unknown option"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "get_packages extracts packages from real config" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing"
    
    result=$(get_packages "arch" "pacman")
    
    [ -n "$result" ] || {
        echo "FAILED: No packages extracted from real config"
        echo "Expected packages from: $DOTFILES_DIR/packages.yml"
        return 1
    }
    
    [[ "$result" =~ "hyprland" ]] || {
        echo "FAILED: Missing expected package 'hyprland'"
        echo "EXTRACTED: $result"
        return 1
    }
}

@test "missing packages.yml handled gracefully" {
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/.config"
    echo "test" > "$temp_dir/.config/test.conf"
    
    export DOTFILES_DIR="$temp_dir"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: Should handle missing packages.yml gracefully"
        echo "EXIT STATUS: $status"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$output" =~ "No packages.yml found" ]] || {
        echo "FAILED: Missing expected message about missing packages.yml"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}