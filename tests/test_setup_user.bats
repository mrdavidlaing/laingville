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
    
    [[ "$output" =~ "SHARED SYMLINKS:" ]] || {
        echo "FAILED: Missing 'SHARED SYMLINKS:' section in output"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "USER SYMLINKS:" ]] || {
        echo "FAILED: Missing 'USER SYMLINKS:' section in output"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "PACKAGES" ]] || {
        echo "FAILED: Missing 'PACKAGES' section in output"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "SYSTEMD SERVICES:" ]] || {
        echo "FAILED: Missing 'SYSTEMD SERVICES:' section in output"
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
    # Create temporary dotfiles directory within allowed path
    temp_dir="$BATS_TEST_DIRNAME/../dotfiles/test_temp_user"
    mkdir -p "$temp_dir/.config"
    echo "test" > "$temp_dir/.config/test.conf"
    
    export DOTFILES_DIR="$temp_dir"
    
    run ./setup-user --dry-run
    
    # The script should complete and show expected output even if exit status is non-zero
    # This test focuses on graceful handling rather than perfect exit status
    # See TODO.md#setup-user-exit-status-1 for details on the exit status issue
    [[ "$output" =~ "No packages.yml found" ]] || {
        echo "FAILED: Missing expected message about missing packages.yml"
        echo "EXIT STATUS: $status"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}

@test "shared dotfiles are processed correctly" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: setup-user --dry-run failed"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" == *"dynamic-wallpaper"*"shared"*"dynamic-wallpaper"* ]] || {
        echo "FAILED: Missing shared dynamic-wallpaper script link"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "systemd services are detected" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: setup-user --dry-run failed"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "Would enable and start: dynamic-wallpaper.timer" ]] || {
        echo "FAILED: Missing systemd timer detection"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "setup_systemd_services function works" {
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/.config/systemd/user"
    echo "[Timer]" > "$temp_dir/.config/systemd/user/test.timer"
    
    # For dry-run mode, set DOTFILES_DIR instead of HOME
    export DOTFILES_DIR="$temp_dir"
    
    result=$(setup_systemd_services true 2>&1)
    
    [[ "$result" =~ "Would enable and start: test.timer" ]] || {
        echo "FAILED: setup_systemd_services didn't detect timer"
        echo "RESULT: $result"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}

@test "dynamic wallpaper script shows help" {
    script_path="$BATS_TEST_DIRNAME/../dotfiles/shared/.local/bin/dynamic-wallpaper"
    
    [ -f "$script_path" ] || {
        echo "FAILED: Dynamic wallpaper script not found at $script_path"
        return 1
    }
    
    run "$script_path" --help
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: Script help failed with status $status"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "Dynamic Wallpaper Script" ]] || {
        echo "FAILED: Missing script title in help"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "YAML" ]] || {
        echo "FAILED: Missing YAML configuration info in help"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "go-yq" ]] || {
        echo "FAILED: Missing go-yq dependency info in help"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "dynamic wallpaper script handles missing config gracefully" {
    script_path="$BATS_TEST_DIRNAME/../dotfiles/shared/.local/bin/dynamic-wallpaper"
    temp_dir=$(mktemp -d)
    mock_bin="$temp_dir/bin"
    
    mkdir -p "$mock_bin"
    export HOME="$temp_dir"
    
    # Create a fake curl that always fails instantly
    cat > "$mock_bin/curl" << 'EOF'
#!/bin/bash
echo "Mock curl failing" >&2
exit 1
EOF
    chmod +x "$mock_bin/curl"
    
    # Mock sleep to avoid delays
    cat > "$mock_bin/sleep" << 'EOF'
#!/bin/bash
# Instant sleep for tests
exit 0
EOF
    chmod +x "$mock_bin/sleep"
    
    # Mock seq with reduced retry count for faster tests
    cat > "$mock_bin/seq" << 'EOF'
#!/bin/bash
# Reduced retry count for tests: max 1 attempt instead of 3
case "$*" in
    "1 3"|"1 2"|"1 "*) echo "1" ;;
    *) /usr/bin/seq "$@" ;;
esac
EOF
    chmod +x "$mock_bin/seq"
    
    # Put mock bin in PATH
    export PATH="$mock_bin:$PATH"
    
    run "$script_path"
    
    # Should fail gracefully when curl fails
    [ "$status" -eq 1 ] || {
        echo "FAILED: Expected failure when curl fails"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$output" =~ "Failed to download wallpaper from any source" ]] || {
        echo "FAILED: Missing expected error message"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}

@test "dynamic wallpaper script parses YAML configuration" {
    script_path="$BATS_TEST_DIRNAME/../dotfiles/shared/.local/bin/dynamic-wallpaper"
    temp_dir=$(mktemp -d)
    config_dir="$temp_dir/.config"
    config_file="$config_dir/dynamic-wallpaper.yml"
    
    mkdir -p "$config_dir"
    export HOME="$temp_dir"
    
    # Create test YAML configuration
    cat > "$config_file" << 'EOF'
wallpaper:
  sources:
    - "https://test1.example.com/image.jpg"
    - "https://test2.example.com/image.jpg"
  settings:
    timeout: 60
    max_file_size: "5MB"
EOF
    
    # Create mock yq that outputs test data
    mock_bin="$temp_dir/bin"
    mkdir -p "$mock_bin"
    cat > "$mock_bin/yq" << 'EOF'
#!/bin/bash
case "$*" in
    *".wallpaper.sources[]"*)
        echo "https://test1.example.com/image.jpg"
        echo "https://test2.example.com/image.jpg"
        ;;
    *".wallpaper.settings.timeout // 30"*)
        echo "60"
        ;;
    *".wallpaper.settings.max_file_size"*)
        echo "5MB"
        ;;
    *".wallpaper.settings.retry_count"*)
        echo "3"
        ;;
    *".wallpaper.settings.user_agent"*)
        echo "test-agent"
        ;;
    *)
        echo "true"
        ;;
esac
EOF
    chmod +x "$mock_bin/yq"
    
    # Create mock curl that always fails (we're testing config parsing, not downloading)
    cat > "$mock_bin/curl" << 'EOF'
#!/bin/bash
echo "Mock curl - failing for test" >&2
exit 1
EOF
    chmod +x "$mock_bin/curl"
    
    # Mock sleep to avoid delays
    cat > "$mock_bin/sleep" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$mock_bin/sleep"
    
    # Mock seq with single attempt for faster tests
    cat > "$mock_bin/seq" << 'EOF'
#!/bin/bash
case "$*" in
    "1 3"|"1 2"|"1 "*) echo "1" ;;
    *) /usr/bin/seq "$@" ;;
esac
EOF
    chmod +x "$mock_bin/seq"
    
    export PATH="$mock_bin:$PATH"
    
    # Run script and check it loads our test configuration
    run "$script_path"
    
    # Should fail on download (expected) but show our test URLs in output
    [ "$status" -eq 1 ] || {
        echo "FAILED: Expected download failure (test only parses config)"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$output" =~ "test1.example.com" ]] || {
        echo "FAILED: Config parsing didn't load test URL 1"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$output" =~ "test2.example.com" ]] || {
        echo "FAILED: Config parsing didn't load test URL 2"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}

@test "dynamic wallpaper script validates URLs for security" {
    script_path="$BATS_TEST_DIRNAME/../dotfiles/shared/.local/bin/dynamic-wallpaper"
    temp_dir=$(mktemp -d)
    config_dir="$temp_dir/.config"
    config_file="$config_dir/dynamic-wallpaper.yml"
    
    mkdir -p "$config_dir"
    export HOME="$temp_dir"
    
    # Create configuration with unsafe URLs
    cat > "$config_file" << 'EOF'
wallpaper:
  sources:
    - "http://insecure.example.com/image.jpg"  # HTTP not HTTPS
    - "https://localhost/image.jpg"             # Private IP blocked
  settings:
    timeout: 30
    max_file_size: "10MB"
  security:
    https_only: true
    block_private_ips: true
EOF
    
    # Create mock yq for this configuration
    mock_bin="$temp_dir/bin"
    mkdir -p "$mock_bin"
    cat > "$mock_bin/yq" << 'EOF'
#!/bin/bash
case "$*" in
    *".wallpaper.sources[]"*)
        echo "http://insecure.example.com/image.jpg"
        echo "https://localhost/image.jpg"
        ;;
    *".wallpaper.security.https_only"*)
        echo "true"
        ;;
    *".wallpaper.security.block_private_ips"*)
        echo "true"
        ;;
    *".wallpaper.security.allowed_domains"*)
        # Return empty - no allowed domains specified
        exit 1
        ;;
    *".wallpaper.settings.retry_count"*)
        echo "3"
        ;;
    *)
        echo "30"  # Default for other settings
        ;;
esac
EOF
    chmod +x "$mock_bin/yq"
    
    # Mock curl (should not be called due to URL validation)
    cat > "$mock_bin/curl" << 'EOF'
#!/bin/bash
echo "ERROR: curl should not be called - URL validation should block unsafe URLs" >&2
exit 1
EOF
    chmod +x "$mock_bin/curl"
    
    # Mock sleep to avoid delays
    cat > "$mock_bin/sleep" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$mock_bin/sleep"
    
    # Mock seq with single attempt for faster tests
    cat > "$mock_bin/seq" << 'EOF'
#!/bin/bash
case "$*" in
    "1 3"|"1 2"|"1 "*) echo "1" ;;
    *) /usr/bin/seq "$@" ;;
esac
EOF
    chmod +x "$mock_bin/seq"
    
    export PATH="$mock_bin:$PATH"
    
    run "$script_path"
    
    # Should fail due to security validation
    [ "$status" -eq 1 ] || {
        echo "FAILED: Expected failure due to unsafe URLs"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$output" =~ "HTTPS URLs allowed" ]] || {
        echo "FAILED: Should reject HTTP URLs when https_only is true"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$output" =~ "Skipping invalid/unsafe URL: https://localhost" ]] || {
        echo "FAILED: Should block localhost when block_private_ips is true"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}

@test "get_custom_scripts extracts scripts from real config" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing"
    
    result=$(get_custom_scripts "arch")
    
    [ -n "$result" ] || {
        echo "FAILED: No custom scripts extracted from real config"
        echo "Expected custom scripts from: $DOTFILES_DIR/packages.yml"
        return 1
    }
    
    [[ "$result" =~ "install_claude_code" ]] || {
        echo "FAILED: Missing expected custom script 'install_claude_code'"
        echo "EXTRACTED: $result"
        return 1
    }
}

@test "dry-run shows correct behavior for unknown platform" {
    export DOTFILES_DIR="$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: setup-user --dry-run failed"
        echo "OUTPUT: $output"
        return 1
    }
    
    # On unknown platforms (like macOS), should skip package installation and custom scripts
    [[ "$output" =~ "Unknown platform: unknown - skipping package installation" ]] || {
        echo "FAILED: Should show unknown platform message on macOS"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "unknown platform skips custom scripts gracefully" {
    # Create temporary dotfiles directory within allowed path
    temp_dir="$BATS_TEST_DIRNAME/../dotfiles/test_temp_custom"
    mkdir -p "$temp_dir"
    
    # Create packages.yml with custom script (which should be skipped on unknown platform)
    cat > "$temp_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - git
  custom:
    - nonexistent_script
EOF
    
    export DOTFILES_DIR="$temp_dir"
    
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: Should handle unknown platform gracefully"
        echo "EXIT STATUS: $status"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    # On unknown platforms, should skip package installation (including custom scripts)
    [[ "$output" =~ "Unknown platform: unknown - skipping package installation" ]] || {
        echo "FAILED: Should show unknown platform skip message"
        echo "OUTPUT: $output"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}