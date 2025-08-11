Describe "macos.functions.bash"
Before "cd '$SHELLSPEC_PROJECT_ROOT'"
Before "source ./lib/polyfill.functions.bash"
Before "source ./lib/logging.functions.bash"
Before "source ./lib/security.functions.bash"
Before "source ./lib/shared.functions.bash"
Before "source ./lib/setup-user.functions.bash"
Before "source ./lib/macos.functions.bash"

Describe "install_homebrew function"
It "shows correct dry-run output when brew not installed"
# Mock command -v to return failure for brew
command() {
  if [ "$1" = "-v" ] && [ "$2" = "brew" ]; then
    return 1
  fi
  # Fall back to real command for other calls
  /usr/bin/command "$@"
}

When call install_homebrew true

The status should be success
The output should include "HOMEBREW SETUP:"
The output should include "install Homebrew via official installer"
End

It "shows correct dry-run output when brew already installed"
# Mock command -v to return success for brew
command() {
  if [ "$1" = "-v" ] && [ "$2" = "brew" ]; then
    return 0
  fi
  # Fall back to real command for other calls
  /usr/bin/command "$@"
}

When call install_homebrew true

The status should be success
The output should include "HOMEBREW SETUP:"
The output should include "update Homebrew"
End
End

Describe "configure_macos_system function"
It "shows correct dry-run output"
When call configure_macos_system true

The status should be success
The output should include "MACOS SYSTEM CONFIG:"
The output should include "set keyboard repeat rate"
The output should include "enable font smoothing"
The output should include "set Alacritty as default terminal"
The output should include "disable press-and-hold for VSCode and Cursor"
The output should include "set system locale to en_IE.UTF-8"
End
End

Describe "macOS functions handle non-dry-run mode gracefully"
It "handles non-dry-run mode without actual system changes"
# Mock command -v to simulate brew not being available
command() {
  if [ "$1" = "-v" ] && [ "$2" = "brew" ]; then
    return 1
  fi
  # Fall back to real command for other calls
  /usr/bin/command "$@"
}

# Mock curl to prevent actual Homebrew installation
curl() {
  echo "# Mock Homebrew installer script"
  echo "echo 'Mock Homebrew installation'"
}

# Mock defaults to prevent actual system changes
defaults() {
  echo "Mock defaults command: $*"
}

# Mock osascript to prevent actual login item changes
osascript() {
  echo "exists"
}

# Test install_homebrew
When call install_homebrew false

The status should be success
The output should include "Installing Homebrew"
End

It "configure_macos_system handles non-dry-run mode"
# Mock defaults to prevent actual system changes
defaults() {
  echo "Mock defaults command: $*"
}

# Mock osascript to prevent actual login item changes
osascript() {
  echo "exists"
}

When call configure_macos_system false

The status should be success
The output should include "Configuring macOS system settings"
End
End

Describe "macOS functions are properly exported and callable"
It "install_homebrew function exists"
When run type install_homebrew

The status should be success
The output should include "is a function"
End

It "configure_macos_system function exists"
When run type configure_macos_system

The status should be success
The output should include "is a function"
End
End

Describe "setup_systemd_services skips systemd on macOS"
It "skips systemd on macOS in dry-run mode"
# Mock detect_platform to return macos
detect_platform() {
  echo "macos"
}

When call setup_systemd_services true

The status should be success
The output should include "SYSTEM SERVICES:"
The output should include "skip systemd services (not supported on macos)"
End

It "skips systemd on macOS in normal mode"
# Mock detect_platform to return macos
detect_platform() {
  echo "macos"
}

When call setup_systemd_services false

The status should be success
The output should include "Skipping systemd services (not supported on macos)"
End
End
End
