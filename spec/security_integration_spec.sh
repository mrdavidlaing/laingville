Describe "security integration tests"

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"

    Describe "setup scripts reject malicious package configurations"
      It "rejects malicious packages in setup-user"
# Create temporary directory within project dotfiles for security validation
        malicious_dir="${SHELLSPEC_PROJECT_ROOT}/dotfiles/temp_malicious_test_$$"
        mkdir -p "${malicious_dir}"

# Create malicious packages.yaml with command injection
cat > "${malicious_dir}/packages.yaml" << 'EOF'
arch:
  yay:
    - "htop; rm -rf /tmp/test_malicious"
    - "curl && evil-command"
    - "vim"
windows:
  winget:
    - "Git.Git"
EOF

# Create fake pacman to make platform detection return "arch"
        fake_bin=$(mktemp -d)
        fake_bin="${fake_bin}/fake_bin"
        mkdir -p "${fake_bin}"
cat > "${fake_bin}/pacman" << 'EOF'
#!/bin/bash
echo "fake pacman for testing"
EOF
        chmod +x "${fake_bin}/pacman"

cat > "${fake_bin}/yay" << 'EOF'
#!/bin/bash
echo "fake yay for testing"
EOF
        chmod +x "${fake_bin}/yay"

# Test setup-user rejects malicious packages
        export DOTFILES_DIR="${malicious_dir}"
        export PATH="${fake_bin}:${PATH}"
        export PLATFORM="arch"

        When call ./bin/setup-user --dry-run

# Should complete but warn about invalid packages
        The status should be success
        The output should include "install via yay: vim"
        The stderr should include "Warning: Skipping invalid package"

# Should log security events to stderr
        The stderr should include "SECURITY"
        The stderr should include "INVALID_PACKAGE"

        rm -rf "${malicious_dir}" "${fake_bin}"
      End
    End

    Describe "setup scripts validate directory boundaries"
      It "rejects invalid DOTFILES_DIR"
        export DOTFILES_DIR="/etc"

        When call ./bin/setup-user --dry-run

        The status should be failure
        The stderr should include "Invalid DOTFILES_DIR"

# Ignore startup output in stdout
        The output should include "Starting setup-user"
      End

      It "rejects invalid SERVER_DIR"
        export SERVER_DIR="/etc"

        When call ./bin/setup-server --dry-run

        The status should be failure
        The stderr should include "Invalid SERVER_DIR"

# Ignore startup output in stdout
        The output should include "Starting setup-server"
      End
    End

    Describe "package validation prevents shell injection in real workflow"
      It "filters out malicious packages in mixed configuration"
# Create test directory within project dotfiles for security validation
        test_dir="${SHELLSPEC_PROJECT_ROOT}/dotfiles/temp_injection_test_$$"
        mkdir -p "${test_dir}"

# Create packages.yaml with mixed valid and invalid packages
cat > "${test_dir}/packages.yaml" << 'EOF'
arch:
  yay:
    - vim
    - curl
    - evil;rm -rf /
    - htop
    - test`malware`
    - yay
    - bad&&command
EOF

# Create fake pacman to make platform detection return "arch"
        fake_bin=$(mktemp -d)
        fake_bin="${fake_bin}/fake_bin"
        mkdir -p "${fake_bin}"
cat > "${fake_bin}/pacman" << 'EOF'
#!/bin/bash
echo "fake pacman for testing"
EOF
        chmod +x "${fake_bin}/pacman"

cat > "${fake_bin}/yay" << 'EOF'
#!/bin/bash
echo "fake yay for testing"
EOF
        chmod +x "${fake_bin}/yay"

        export DOTFILES_DIR="${test_dir}"
        export PATH="${fake_bin}:${PATH}"
        export PLATFORM="arch"

        When call ./bin/setup-user --dry-run

        The status should be success

# Should show valid packages in install list (with warnings inline)
        The output should include "install via yay:"
        The output should include "vim, curl, htop, yay"

# Should warn about invalid packages
        The stderr should include "Warning: Skipping invalid package"

# Should show security events for rejected packages
        The stderr should include "SECURITY"
        The stderr should include "INVALID_PACKAGE"

        rm -rf "${test_dir}" "${fake_bin}"
      End
    End

    Describe "hostname validation prevents directory traversal in servers"
      It "rejects malicious hostname"
        temp_dir=$(mktemp -d)

# Mock hostname command to return malicious value
cat > "${temp_dir}/hostname" << 'EOF'
#!/bin/bash
echo "../../../etc"
EOF
        chmod +x "${temp_dir}/hostname"

# Put fake hostname first in PATH and clear any cached values
        export PATH="${temp_dir}:${PATH}"

        When call ./bin/setup-server --dry-run

        The status should be failure
        The stderr should include "Invalid hostname"

# Ignore startup output in stdout
        The output should include "Starting setup-server"

        rm -rf "${temp_dir}"
      End
    End

    Describe "systemd unit validation prevents malicious unit names"
      It "filters out malicious systemd units"
        temp_dir=$(mktemp -d)
        systemd_dir="${temp_dir}/.config/systemd/user"
        mkdir -p "${systemd_dir}"

# Create valid and invalid systemd units
        touch "${systemd_dir}/valid.timer"
        touch "${systemd_dir}/../evil.timer" # Outside directory
        touch "${systemd_dir}/evil..timer"   # Invalid name
        mkdir -p "${systemd_dir}/evil"
        touch "${systemd_dir}/evil/bad.timer" # Path traversal attempt

        export HOME="${temp_dir}"
        export PLATFORM="arch"
        export DOTFILES_DIR="${temp_dir}"

# Source all required functions
        source ./lib/polyfill.functions.bash
        source ./lib/logging.functions.bash
        source ./lib/security.functions.bash
        source ./lib/platform.functions.bash
        source ./lib/shared.functions.bash
        source ./lib/setup-user.functions.bash

        When call setup_systemd_services true

        The status should be success

# Should only show valid timer
        The output should include "valid.timer"

# Should not show invalid units
        The output should not include "evil"

# Should log security events for invalid units
        The stderr should include "SECURITY"
        The stderr should include "INVALID_UNIT_NAME"

        rm -rf "${temp_dir}"
      End
    End

    Describe "macOS package management integration with security validation"
      It "validates macOS packages including taps"
# Create test directory for macOS packages
        test_dir="${SHELLSPEC_PROJECT_ROOT}/dotfiles/temp_macos_test_$$"
        mkdir -p "${test_dir}"

# Create packages.yaml with macOS packages including taps
cat > "${test_dir}/packages.yaml" << 'EOF'
macos:
  homebrew:
    - git
    - node
    - remotemobprogramming/brew/mob
    - evil;rm -rf /tmp
  cask:
    - font-jetbrains-mono-nerd-font
    - malicious&&command
EOF

# Create fake brew command to simulate macOS environment
        fake_bin=$(mktemp -d)
        fake_bin="${fake_bin}/fake_bin_macos"
        mkdir -p "${fake_bin}"
cat > "${fake_bin}/brew" << 'EOF'
#!/bin/bash
echo "fake brew for testing: ${*}"
EOF
        chmod +x "${fake_bin}/brew"

        export DOTFILES_DIR="${test_dir}"
        export PATH="${fake_bin}:${PATH}"
        export PLATFORM="macos"

        When call ./bin/setup-user --dry-run

        The status should be success

# Should show valid packages in install lists
        The output should include "install via homebrew: git, node, remotemobprogramming/brew/mob"
        The output should include "install via cask: font-jetbrains-mono-nerd-font"

# Should warn about invalid packages
        The stderr should include "Warning: Skipping invalid package"

# Should log security events to stderr
        The stderr should include "SECURITY"
        The stderr should include "INVALID_PACKAGE"

# Should show Homebrew setup section
        The output should include "HOMEBREW SETUP:"
        The output should include "update Homebrew"

# Should show macOS system configuration sections
        The output should include "MACOS SYSTEM CONFIG:"

        rm -rf "${test_dir}" "${fake_bin}"
      End
    End

    Describe "macOS platform detection works with package processing"
      It "correctly processes macOS platform"
# Test that macOS platform is correctly detected and processed
        test_dir="${SHELLSPEC_PROJECT_ROOT}/dotfiles/temp_macos_platform_test_$$"
        mkdir -p "${test_dir}"

# Create simple macOS packages config
cat > "${test_dir}/packages.yaml" << 'EOF'
macos:
  homebrew:
    - curl
    - wget
  cask:
    - firefox
EOF

# Create fake brew to simulate macOS
        fake_bin=$(mktemp -d)
        fake_bin="${fake_bin}/fake_bin_platform"
        mkdir -p "${fake_bin}"
cat > "${fake_bin}/brew" << 'EOF'
#!/bin/bash
echo "fake brew: ${*}"
EOF
        chmod +x "${fake_bin}/brew"

        export DOTFILES_DIR="${test_dir}"
        export PATH="${fake_bin}:${PATH}"
        export PLATFORM="macos"

        When call ./bin/setup-user --dry-run

        The status should be success
        The output should include "USER PACKAGES (macos):"
        The output should include "install via homebrew: curl, wget"
        The output should include "install via cask: firefox"

        rm -rf "${test_dir}" "${fake_bin}"
      End
    End

    Describe "security logging captures events"
      It "logs security events to stderr"
# Test that security events are logged to stderr
        source ./lib/polyfill.functions.bash
        source ./lib/logging.functions.bash
        source ./lib/security.functions.bash

        When call log_security_event "TEST_EVENT" "Test security message"

        The status should be success
        The stderr should include "SECURITY"
        The stderr should include "TEST_EVENT"
        The stderr should include "Test security message"
      End
    End
  End
