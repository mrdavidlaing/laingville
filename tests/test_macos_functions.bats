#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  source ./lib/polyfill.functions.bash
  source ./lib/logging.functions.bash
  source ./lib/security.functions.bash
  source ./lib/shared.functions.bash
  source ./lib/setup-user.functions.bash
  source ./lib/macos.functions.bash
}

@test "install_homebrew shows correct dry-run output when brew not installed" {
  # Mock command -v to return failure for brew
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "brew" ]; then
      return 1
    fi
    # Fall back to real command for other calls
    /usr/bin/command "$@"
  }
  export -f command
  
  run install_homebrew true
  [ "$status" -eq 0 ]
  [[ "$output" =~ "HOMEBREW SETUP:" ]]
  [[ "$output" =~ "install Homebrew via official installer" ]]
}

@test "install_homebrew shows correct dry-run output when brew already installed" {
  # Mock command -v to return success for brew
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "brew" ]; then
      return 0
    fi
    # Fall back to real command for other calls
    /usr/bin/command "$@"
  }
  export -f command
  
  run install_homebrew true
  [ "$status" -eq 0 ]
  [[ "$output" =~ "HOMEBREW SETUP:" ]]
  [[ "$output" =~ "update Homebrew" ]]
}

@test "configure_macos_system shows correct dry-run output" {
  run configure_macos_system true
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MACOS SYSTEM CONFIG:" ]]
  [[ "$output" =~ "set keyboard repeat rate" ]]
  [[ "$output" =~ "enable font smoothing" ]]
  [[ "$output" =~ "set Alacritty as default terminal" ]]
  [[ "$output" =~ "disable press-and-hold for VSCode and Cursor" ]]
  [[ "$output" =~ "set system locale to en_IE.UTF-8" ]]
}


@test "macOS functions handle non-dry-run mode gracefully without actual system changes" {
  # Test that functions don't crash in non-dry-run mode, but we won't make actual system changes
  
  # Mock command -v to simulate brew not being available
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "brew" ]; then
      return 1
    fi
    # Fall back to real command for other calls
    /usr/bin/command "$@"
  }
  export -f command
  
  # Mock curl to prevent actual Homebrew installation
  curl() {
    echo "# Mock Homebrew installer script"
    echo "echo 'Mock Homebrew installation'"
  }
  export -f curl
  
  # Mock defaults to prevent actual system changes
  defaults() {
    echo "Mock defaults command: $*"
  }
  export -f defaults
  
  # Mock osascript to prevent actual login item changes
  osascript() {
    echo "exists"
  }
  export -f osascript
  
  # Test install_homebrew
  run install_homebrew false
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Installing Homebrew" ]]
  
  # Test configure_macos_system
  run configure_macos_system false
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Configuring macOS system settings" ]]
  
}

@test "macOS functions are properly exported and callable" {
  # Test that all macOS functions exist and are callable
  run type install_homebrew
  [ "$status" -eq 0 ]
  [[ "$output" =~ "is a function" ]]
  
  run type configure_macos_system
  [ "$status" -eq 0 ]
  [[ "$output" =~ "is a function" ]]
}

@test "setup_systemd_services skips systemd on macOS" {
  # Mock detect_platform to return macos
  detect_platform() {
    echo "macos"
  }
  export -f detect_platform
  
  # Test dry-run mode
  run setup_systemd_services true
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SYSTEM SERVICES:" ]]
  [[ "$output" =~ "skip systemd services (not supported on macos)" ]]
  
  # Test normal mode
  run setup_systemd_services false
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Skipping systemd services (not supported on macos)" ]]
}