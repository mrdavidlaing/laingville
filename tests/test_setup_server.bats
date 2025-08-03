#!/usr/bin/env bats

# TDD tests for setup-server script

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    # Source functions when they exist (don't fail if they don't)
    if [ -f ./setup-server.functions.bash ]; then
        source ./setup-server.functions.bash
    fi
}

@test "hostname detection works correctly" {
    # Test that we can detect hostname (basic functionality)
    current_hostname=$(hostname)
    
    [ -n "$current_hostname" ] || {
        echo "FAILED: hostname command returned empty result"
        return 1
    }
    
    # Hostname should not contain spaces or special characters that would break our logic
    [[ "$current_hostname" =~ ^[a-zA-Z0-9.-]+$ ]] || {
        echo "FAILED: hostname contains invalid characters: $current_hostname"
        return 1
    }
}

@test "hostname to server directory mapping logic" {
    # Test the planned mapping logic before implementation
    # This test defines the expected behavior
    
    test_hostname="baljeet"
    expected_dir="servers/baljeet"
    
    result=$(map_hostname_to_server_dir "$test_hostname")
    [ "$result" = "$expected_dir" ] || {
        echo "FAILED: Expected '$expected_dir' but got '$result'"
        return 1
    }
}

@test "setup-server script exists and is executable" {
    
    [ -f "./setup-server" ] || {
        echo "FAILED: setup-server script does not exist"
        return 1
    }
    
    [ -x "./setup-server" ] || {
        echo "FAILED: setup-server script is not executable"
        return 1
    }
}

@test "setup-server shows help with invalid arguments" {
    
    run ./setup-server --invalid
    
    [ "$status" -eq 1 ] || {
        echo "FAILED: Expected exit status 1 for invalid arguments"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "Unknown option" ]] || {
        echo "FAILED: Missing error message for unknown option"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "setup-server dry-run mode shows expected sections" {
    
    # Set a test server directory for predictable testing
    export SERVER_DIR="$BATS_TEST_DIRNAME/../servers/baljeet"
    
    run ./setup-server --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: setup-server --dry-run failed with status $status"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "DRY RUN MODE" ]] || {
        echo "FAILED: Missing 'DRY RUN MODE' in output"
        echo "OUTPUT: $output"
        return 1
    }
    
    [[ "$output" =~ "SERVER PACKAGES" ]] || {
        echo "FAILED: Missing 'SERVER PACKAGES' section in output"
        echo "OUTPUT: $output"
        return 1
    }
}

@test "server packages.yml parsing extracts packages correctly" {
    # Create a test server directory with packages.yml
    temp_dir=$(mktemp -d)
    server_dir="$temp_dir/servers/testhost"
    mkdir -p "$server_dir"
    
    cat > "$server_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - k3s
    - htop
    - curl
  aur:
    - some-aur-package

windows:
  winget:
    - SomeApp
EOF
    
    # Set SERVER_DIR to our test directory for the function
    export SERVER_DIR="$server_dir"
    
    result=$(get_server_packages "arch" "pacman")
    [[ "$result" =~ "k3s" ]] || {
        echo "FAILED: k3s package not found in parsed output"
        echo "RESULT: $result"
        rm -rf "$temp_dir"
        return 1
    }
    
    [[ "$result" =~ "htop" ]] || {
        echo "FAILED: htop package not found in parsed output"  
        echo "RESULT: $result"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
}

@test "k3s package specifically detected for baljeet server" {
    # This test ensures k3s is properly configured for baljeet
    
    server_packages_file="$BATS_TEST_DIRNAME/../servers/baljeet/packages.yml"
    
    [ -f "$server_packages_file" ] || {
        echo "FAILED: baljeet packages.yml does not exist at $server_packages_file"
        return 1
    }
    
    # Check that k3s is listed in the packages
    grep -q "k3s" "$server_packages_file" || {
        echo "FAILED: k3s not found in baljeet packages.yml"
        echo "Contents:"
        cat "$server_packages_file"
        return 1
    }
}

@test "missing server packages.yml handled gracefully" {
    # Create temporary server directory within allowed path
    temp_dir="$BATS_TEST_DIRNAME/../servers/test_temp_server"
    mkdir -p "$temp_dir"  # Create directory but not packages.yml
    
    export SERVER_DIR="$temp_dir"
    
    run ./setup-server --dry-run
    
    [ "$status" -eq 0 ] || {
        echo "FAILED: Should handle missing server config gracefully"
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

@test "server directory structure validation" {
    # Test that the expected directory structure is validated
    skip "Directory structure validation not yet implemented"
    
    # Should validate that servers/ directory exists
    # Should handle case where servers/[hostname]/ doesn't exist
    # Should provide helpful error messages
}

@test "shared server configurations processed before host-specific" {
    # Test the planned behavior of processing shared configs first
    skip "Shared server configuration logic not yet implemented"
    
    # Should process servers/shared/ before servers/[hostname]/
    # Similar to how setup-user processes shared dotfiles first
}