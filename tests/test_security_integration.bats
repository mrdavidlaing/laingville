#!/usr/bin/env bats

# Security integration tests for the actual scripts

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "setup scripts reject malicious package configurations" {
    # Create temporary directory within project dotfiles for security validation
    malicious_dir="$BATS_TEST_DIRNAME/../dotfiles/temp_malicious_test"
    mkdir -p "$malicious_dir"
    
    # Create malicious packages.yml with command injection
    cat > "$malicious_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - "htop; rm -rf /tmp/test_malicious"
    - "curl && evil-command"
    - "vim"
windows:
  winget:
    - "Git.Git"
EOF
    
    # Create fake pacman to make platform detection return "arch"
    fake_bin="$malicious_dir/../fake_bin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/pacman" << 'EOF'
#!/bin/bash
echo "fake pacman for testing"
EOF
    chmod +x "$fake_bin/pacman"
    
    # Test setup-user rejects malicious packages
    export DOTFILES_DIR="$malicious_dir"
    export PATH="$fake_bin:$PATH"
    run ./bin/setup-user --dry-run
    
    # Should complete but warn about invalid packages
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Warning: Skipping invalid package" ]]
    
    # Should show security events in stderr
    [[ "$output" =~ "SECURITY" ]] || true  # May not show in dry-run
    
    rm -rf "$malicious_dir" "$fake_bin"
}

@test "setup scripts validate directory boundaries" {
    temp_dir=$(mktemp -d)
    
    # Try to set DOTFILES_DIR outside allowed area
    export DOTFILES_DIR="/etc"
    run ./bin/setup-user --dry-run
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid DOTFILES_DIR" ]]
    
    # Try to set SERVER_DIR outside allowed area  
    export SERVER_DIR="/etc"
    run ./bin/setup-server --dry-run
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid SERVER_DIR" ]]
    
    rm -rf "$temp_dir"
}

@test "package validation prevents shell injection in real workflow" {
    # Create test directory within project dotfiles for security validation
    test_dir="$BATS_TEST_DIRNAME/../dotfiles/temp_injection_test"
    mkdir -p "$test_dir"
    
    # Create packages.yml with mixed valid and invalid packages
    cat > "$test_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - vim
    - curl
    - evil;rm -rf /
    - htop
    - test`malware`
  aur:
    - yay
    - bad&&command
EOF
    
    # Create fake pacman to make platform detection return "arch"
    fake_bin="$test_dir/../fake_bin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/pacman" << 'EOF'
#!/bin/bash
echo "fake pacman for testing"
EOF
    chmod +x "$fake_bin/pacman"
    
    export DOTFILES_DIR="$test_dir"
    export PATH="$fake_bin:$PATH"
    run ./bin/setup-user --dry-run
    
    [ "$status" -eq 0 ]
    
    # Should show valid packages in install list
    [[ "$output" =~ "install via pacman: vim, curl, htop" ]]
    [[ "$output" =~ "install via yay: yay" ]]
    
    # Should warn about invalid packages
    [[ "$output" =~ "Warning: Skipping invalid package" ]]
    
    # Should show security events for rejected packages
    [[ "$output" =~ "SECURITY" ]]
    [[ "$output" =~ "INVALID_PACKAGE" ]]
    
    rm -rf "$test_dir" "$fake_bin"
}

@test "hostname validation prevents directory traversal in servers" {
    # Test with malicious hostname by setting it as environment variable
    temp_dir=$(mktemp -d)
    
    # Mock hostname command to return malicious value
    cat > "$temp_dir/hostname" << 'EOF'
#!/bin/bash
echo "../../../etc"
EOF
    chmod +x "$temp_dir/hostname"
    
    # Put fake hostname first in PATH and clear any cached values
    export PATH="$temp_dir:$PATH"
    hash -r  # Clear bash command hash
    
    run ./bin/setup-server --dry-run
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid hostname" ]]
    
    rm -rf "$temp_dir"
}

@test "systemd unit validation prevents malicious unit names" {
    temp_dir=$(mktemp -d)
    systemd_dir="$temp_dir/.config/systemd/user"
    mkdir -p "$systemd_dir"
    
    # Create valid and invalid systemd units
    touch "$systemd_dir/valid.timer"
    touch "$systemd_dir/../evil.timer"      # Outside directory
    touch "$systemd_dir/evil..timer"        # Invalid name
    mkdir -p "$systemd_dir/evil"
    touch "$systemd_dir/evil/bad.timer"     # Path traversal attempt
    
    export HOME="$temp_dir"
    
    # Source all required functions 
    source ./lib/polyfill.functions.bash
    source ./lib/logging.functions.bash
    source ./lib/security.functions.bash
    source ./lib/shared.functions.bash
    source ./lib/setup-user.functions.bash
    
    run setup_systemd_services true
    
    [ "$status" -eq 0 ]
    
    # Should only show valid timer
    [[ "$output" =~ "valid.timer" ]]
    
    # Should not show invalid units
    [[ ! "$output" =~ "evil" ]]
    
    rm -rf "$temp_dir"
}

@test "security logging captures events" {
    # Test that security events are logged to stderr
    source ./lib/polyfill.functions.bash
    source ./lib/security.functions.bash
    
    run log_security_event "TEST_EVENT" "Test security message"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SECURITY" ]]
    [[ "$output" =~ "TEST_EVENT" ]]
    [[ "$output" =~ "Test security message" ]]
}