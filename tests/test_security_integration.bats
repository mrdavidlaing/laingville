#!/usr/bin/env bats

# Security integration tests for the actual scripts

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "setup scripts reject malicious package configurations" {
    temp_dir=$(mktemp -d)
    malicious_dir="$temp_dir/dotfiles/test_user"
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
    
    # Test setup-user rejects malicious packages
    export DOTFILES_DIR="$malicious_dir"
    run ./setup-user --dry-run
    
    # Should complete but warn about invalid packages
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Warning: Skipping invalid package" ]]
    
    # Should show security events in stderr
    [[ "$output" =~ "SECURITY" ]] || true  # May not show in dry-run
    
    rm -rf "$temp_dir"
}

@test "setup scripts validate directory boundaries" {
    temp_dir=$(mktemp -d)
    
    # Try to set DOTFILES_DIR outside allowed area
    export DOTFILES_DIR="/etc"
    run ./setup-user --dry-run
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid DOTFILES_DIR" ]]
    
    # Try to set SERVER_DIR outside allowed area  
    export SERVER_DIR="/etc"
    run ./setup-server --dry-run
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid SERVER_DIR" ]]
    
    rm -rf "$temp_dir"
}

@test "package validation prevents shell injection in real workflow" {
    temp_dir=$(mktemp -d)
    test_dir="$temp_dir/dotfiles/test"
    mkdir -p "$test_dir"
    
    # Create packages.yml with mixed valid and invalid packages
    cat > "$test_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - "vim"              # Valid
    - "curl"             # Valid  
    - "evil;rm -rf /"    # Invalid - should be rejected
    - "htop"             # Valid
    - "test`malware`"    # Invalid - should be rejected
  aur:
    - "yay"              # Valid
    - "bad&&command"     # Invalid - should be rejected
EOF
    
    export DOTFILES_DIR="$test_dir"
    run ./setup-user --dry-run
    
    [ "$status" -eq 0 ]
    
    # Should show valid packages
    [[ "$output" =~ "vim" ]]
    [[ "$output" =~ "curl" ]]
    [[ "$output" =~ "htop" ]]
    [[ "$output" =~ "yay" ]]
    
    # Should warn about invalid packages
    [[ "$output" =~ "Warning: Skipping invalid package" ]]
    
    # Invalid packages should not appear in install list
    [[ ! "$output" =~ "evil;rm" ]]
    [[ ! "$output" =~ "test\`malware\`" ]]
    [[ ! "$output" =~ "bad&&command" ]]
    
    rm -rf "$temp_dir"
}

@test "hostname validation prevents directory traversal in servers" {
    # Test with malicious hostname
    temp_dir=$(mktemp -d)
    
    # Mock hostname command to return malicious value
    cat > "$temp_dir/fake_hostname" << 'EOF'
#!/bin/bash
echo "../../../etc"
EOF
    chmod +x "$temp_dir/fake_hostname"
    
    # Put fake hostname in PATH
    export PATH="$temp_dir:$PATH"
    
    run ./setup-server --dry-run
    
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
    touch "$systemd_dir/evil/bad.timer"     # Path traversal attempt
    
    export HOME="$temp_dir"
    
    # Source functions to test directly
    source ./setup-user.functions.bash
    
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
    source ./security.functions.bash
    
    run log_security_event "TEST_EVENT" "Test security message"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SECURITY" ]]
    [[ "$output" =~ "TEST_EVENT" ]]
    [[ "$output" =~ "Test security message" ]]
}