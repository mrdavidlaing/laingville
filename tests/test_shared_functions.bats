#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  source ./lib/polyfill.functions.bash
  source ./lib/security.functions.bash
  source ./lib/shared.functions.bash
}

@test "detect_platform returns macos on Darwin" {
  # Mock OSTYPE for macOS
  export OSTYPE="darwin21.6.0"
  result=$(detect_platform)
  [ "$result" = "macos" ]
}

@test "detect_platform prioritizes darwin over pacman" {
  # Even if pacman exists, should return macos on Darwin
  export OSTYPE="darwin21.6.0"
  # Create fake pacman in PATH
  temp_dir=$(mktemp -d)
  echo '#!/bin/bash' > "$temp_dir/pacman"
  chmod +x "$temp_dir/pacman"
  export PATH="$temp_dir:$PATH"
  
  result=$(detect_platform)
  [ "$result" = "macos" ]
  
  rm -rf "$temp_dir"
}

@test "get_packages extracts packages from real config" {
  export DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing" && pwd)"
  result=$(get_packages_from_file "arch" "pacman" "$DOTFILES_DIR/packages.yml")
  [ -n "$result" ]
  [[ "$result" =~ "hyprland" ]]
}

@test "get_packages extracts macOS packages from real config" {
  export DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/../dotfiles/mrdavidlaing" && pwd)"
  
  # Test homebrew packages
  result=$(get_packages_from_file "macos" "homebrew" "$DOTFILES_DIR/packages.yml")
  [ -n "$result" ]
  [[ "$result" =~ "git" ]]
  [[ "$result" =~ "starship" ]]
  [[ "$result" =~ "ripgrep" ]]
  
  # Test cask packages
  result=$(get_packages_from_file "macos" "cask" "$DOTFILES_DIR/packages.yml")
  [ -n "$result" ]
  [[ "$result" =~ "alacritty" ]]
  [[ "$result" =~ "claude" ]]
  [[ "$result" =~ "font-jetbrains-mono-nerd-font" ]]
}

@test "server packages.yml parsing extracts packages correctly" {
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
  result=$(get_packages_from_file "arch" "pacman" "$server_dir/packages.yml")
  [[ "$result" =~ "k3s" ]]
  [[ "$result" =~ "htop" ]]
  rm -rf "$temp_dir"
}

@test "validate_script_name accepts valid names" {
  run validate_script_name valid_name
  [ "$status" -eq 0 ]
}

@test "validate_script_name rejects invalid characters" {
  run validate_script_name "bad_name!"
  [ "$status" -ne 0 ]
}

@test "validate_script_name rejects path traversal" {
  run validate_script_name "../evil"
  [ "$status" -ne 0 ]
}

@test "validate_script_name rejects too long" {
  longname=$(printf 'a%.0s' {1..60})
  run validate_script_name "$longname"
  [ "$status" -ne 0 ]
}
