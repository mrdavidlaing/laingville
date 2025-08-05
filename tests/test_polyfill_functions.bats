#!/usr/bin/env bats

# Test file for polyfill.functions.bash
# These tests ensure cross-platform compatibility functions work correctly

setup() {
    # Source the polyfill functions
    load '../lib/polyfill.functions.bash'
    
    # Create a temporary directory for test files
    TEST_DIR=$(mktemp -d)
    TEST_FILE="$TEST_DIR/test_file.txt"
    TEST_SYMLINK="$TEST_DIR/test_symlink"
    
    # Create test files
    echo "test content" > "$TEST_FILE"
    ln -s "$TEST_FILE" "$TEST_SYMLINK" 2>/dev/null || true
}

teardown() {
    # Clean up test files
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

@test "detect_os returns valid OS type" {
    run detect_os
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(macos|linux|unknown)$ ]]
}

@test "detect_os returns macos on Darwin" {
    # Mock uname command for this test
    function uname() { echo "Darwin"; }
    export -f uname
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "macos" ]
    
    unset -f uname
}

@test "detect_os returns linux on Linux" {
    # Mock uname command for this test
    function uname() { echo "Linux"; }
    export -f uname
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "linux" ]
    
    unset -f uname
}

@test "detect_os returns unknown on unsupported OS" {
    # Mock uname command for this test
    function uname() { echo "FreeBSD"; }
    export -f uname
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "unknown" ]
    
    unset -f uname
}

@test "canonicalize_path fails with empty input" {
    run canonicalize_path ""
    [ "$status" -eq 1 ]
}

@test "canonicalize_path works with existing file" {
    run canonicalize_path "$TEST_FILE"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return an absolute path
    [[ "$output" =~ ^/ ]]
}

@test "canonicalize_path works with existing directory" {
    run canonicalize_path "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return an absolute path
    [[ "$output" =~ ^/ ]]
}

@test "canonicalize_path works with non-existing file" {
    local non_existing="$TEST_DIR/non_existing_file.txt"
    run canonicalize_path "$non_existing"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return an absolute path
    [[ "$output" =~ ^/ ]]
}

@test "get_file_size fails with empty input" {
    run get_file_size ""
    [ "$status" -eq 1 ]
    [ "$output" = "0" ]
}

@test "get_file_size fails with non-existing file" {
    run get_file_size "/non/existing/file"
    [ "$status" -eq 1 ]
    [ "$output" = "0" ]
}

@test "get_file_size returns correct size for existing file" {
    run get_file_size "$TEST_FILE"
    [ "$status" -eq 0 ]
    # The test file contains "test content\n" which should be 13 bytes
    [ "$output" -gt 0 ]
    [ "$output" -lt 100 ]  # Reasonable upper bound
}

@test "read_symlink fails with empty input" {
    run read_symlink ""
    [ "$status" -eq 1 ]
}

@test "read_symlink fails with non-symlink file" {
    run read_symlink "$TEST_FILE"
    [ "$status" -eq 1 ]
}

@test "read_symlink works with symlink" {
    if [ -L "$TEST_SYMLINK" ]; then
        run read_symlink "$TEST_SYMLINK"
        [ "$status" -eq 0 ]
        [ -n "$output" ]
    else
        skip "Symlink creation failed"
    fi
}

@test "command_supports_flag fails with empty input" {
    run command_supports_flag "" ""
    [ "$status" -eq 1 ]
    
    run command_supports_flag "ls" ""
    [ "$status" -eq 1 ]
    
    run command_supports_flag "" "-l"
    [ "$status" -eq 1 ]
}

@test "command_supports_flag works with common commands" {
    # Test with ls command and -l flag (should exist on all Unix systems)
    run command_supports_flag "ls" "-l"
    # This might return 0 or 1 depending on platform, but shouldn't crash
    [[ "$status" =~ ^[01]$ ]]
}

@test "resolve_path fails with empty input" {
    run resolve_path ""
    [ "$status" -eq 1 ]
}

@test "resolve_path works with existing file" {
    run resolve_path "$TEST_FILE"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return an absolute path
    [[ "$output" =~ ^/ ]]
}

@test "resolve_path works with relative path" {
    # Change to test directory and use relative path
    cd "$TEST_DIR"
    local relative_file="$(basename "$TEST_FILE")"
    
    run resolve_path "$relative_file"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return an absolute path
    [[ "$output" =~ ^/ ]]
}

@test "resolve_path handles path with dots" {
    local dotted_path="$TEST_DIR/../$(basename "$TEST_DIR")/$(basename "$TEST_FILE")"
    
    run resolve_path "$dotted_path"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return an absolute path
    [[ "$output" =~ ^/ ]]
}

@test "polyfill functions work on current platform" {
    # Integration test - ensure all functions work together on the current platform
    local os_type
    os_type=$(detect_os)
    
    # Test that we can detect the OS
    [ -n "$os_type" ]
    
    # Test file operations work
    local file_size
    file_size=$(get_file_size "$TEST_FILE")
    [ "$file_size" -gt 0 ]
    
    # Test path resolution works
    local resolved_path
    resolved_path=$(resolve_path "$TEST_FILE")
    [ -n "$resolved_path" ]
    [[ "$resolved_path" =~ ^/ ]]
    
    # Test canonicalization works
    local canonical_path
    canonical_path=$(canonicalize_path "$TEST_FILE")
    [ -n "$canonical_path" ]
    [[ "$canonical_path" =~ ^/ ]]
}