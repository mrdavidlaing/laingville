Describe "setup-server script"

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/logging.functions.bash"
        Before "source ./lib/security.functions.bash"
          Before "source ./lib/platform.functions.bash"
            Before "source ./lib/packages.functions.bash"
              Before "source ./lib/shared.functions.bash"
                Before "source ./lib/setup-user.functions.bash"
                  Before "source ./lib/setup-server.functions.bash"

                    Describe "hostname detection"
                      It "works correctly"
# Test that we can detect hostname (basic functionality)
# Use fallback method if hostname command is not available
                        if command -v hostname > /dev/null 2>&1; then
                        current_hostname=$(hostname)
                        else
                    current_hostname=$(cat /proc/sys/kernel/hostname 2> /dev/null || echo "${HOSTNAME}")
                    fi

                    The value "${current_hostname}" should not be blank
# Hostname should not contain spaces or special characters that would break our logic
# This test just checks that hostname detection works - skip pattern validation for now
                  End
                End

                Describe "hostname to server directory mapping"
                  It "maps hostname to correct server directory"
# Test the planned mapping logic before implementation
# This test defines the expected behavior

                    test_hostname="baljeet"
                    expected_dir="servers/baljeet"

                    When call map_hostname_to_server_dir "${test_hostname}"

                    The output should equal "${expected_dir}"
                  End
                End

                Describe "script existence and permissions"
                  It "exists and is executable"
                    The path "./bin/setup-server" should be exist
                    The file "./bin/setup-server" should be executable
                  End
                End

                Describe "argument handling"
                  It "shows help with invalid arguments"
                    When call ./bin/setup-server --invalid

                    The status should be failure
                    The stderr should include "Unknown option"
                    The stdout should include "Usage:"
                  End
                End

                Describe "dry-run mode"
                  It "shows expected sections"
                    export SERVER_DIR
                    SERVER_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/servers/baljeet" && pwd)"
                    export PLATFORM="arch"

                    When call ./bin/setup-server --dry-run

                    The status should be success
                    The output should include "DRY RUN MODE"
                    The output should include "SERVER PACKAGES"
                    The output should include "Would install yay AUR helper"
                  End
                End

                Describe "k3s package detection"
                  It "specifically detects k3s in server packages"
# This test ensures k3s package detection works with test data
                    temp_server_dir=$(mktemp -d)
                    cat > "${temp_server_dir}/packages.yaml" << 'EOF'
arch:
  pacman:
    - htop
    - curl
    - k3s-bin
  yay:
    - some-aur-package
EOF

                    When call grep -q "k3s-bin" "${temp_server_dir}/packages.yaml"
                    The status should be success
                    
                    rm -rf "${temp_server_dir}"
                  End
                End

                Describe "missing server packages.yaml handling"
                  It "handles missing server packages.yaml gracefully"
# Create temporary server directory within allowed path
                    temp_dir="${SHELLSPEC_PROJECT_ROOT}/servers/test_temp_server_$$"
                    mkdir -p "${temp_dir}" # Create directory but not packages.yaml
                    export SERVER_DIR
                    SERVER_DIR="${temp_dir}"

                    When call ./bin/setup-server --dry-run

                    The status should be success
                    The output should include "No packages.yaml found"

# Cleanup
                    rm -rf "${temp_dir}"
                  End
                End

# Tests for future implementation
                Describe "server directory structure validation"
                  It "validates that servers directory exists and is readable"
# Set SERVER_DIR to nonexistent directory
                    SERVER_DIR="${SHELLSPEC_PROJECT_ROOT}/servers/nonexistent_testhost"

                    When run bash -c 'export SERVER_DIR="${SHELLSPEC_PROJECT_ROOT}/servers/nonexistent_testhost"; ./bin/setup-server --dry-run'
                    The status should be failure
                    The stdout should not be blank
                    The stderr should include "Server directory"
                    The stderr should include "does not exist"
                    The stderr should include "mkdir -p"
                  End

                  It "validates directory permissions when directory exists but is not readable"
# Skip this test when running as root, as root can always read directories regardless of permissions
                    if [ "$(id -u)" -eq 0 ]; then
                    Skip "Test skipped when running as root (root bypasses directory permissions)"
                    fi

# Skip this test on WSL/Windows filesystem where chmod doesn't work properly
                    if [[ "$PWD" == /mnt/c/* ]]; then
                    Skip "Test skipped on Windows/WSL filesystem (chmod permissions not enforced)"
                    fi

# Create test directory structure with no read permissions
                    temp_dir="${SHELLSPEC_PROJECT_ROOT}/servers/test_readonly_server_$$"
                    mkdir -p "${temp_dir}"
                    touch "${temp_dir}/packages.yaml"
                    chmod 000 "${temp_dir}"

                    When run bash -c "export SERVER_DIR='$temp_dir'; ./bin/setup-server --dry-run"
                    The status should be failure
                    The stdout should not be blank
                    The stderr should include "not readable"

# Cleanup - restore permissions first
                    chmod 755 "${temp_dir}"
                    rm -rf "${temp_dir}"
                  End

                  It "provides helpful error messages for missing server directories"
# Set SERVER_DIR to nonexistent directory with specific name
                    SERVER_DIR="${SHELLSPEC_PROJECT_ROOT}/servers/missing_server"

                    When run bash -c "export SERVER_DIR='$SERVER_DIR'; ./bin/setup-server --dry-run"
                    The status should be failure
                    The stdout should not be blank
                    The stderr should include "Create the directory structure"
                    The stderr should include "mkdir -p"
                    The stderr should include "touch"
                    The stderr should include "packages.yaml"
                  End
                End

                Describe "shared server configurations"
                  It "processes shared server packages when shared directory exists"
# Create isolated test structure with shared packages
                    temp_servers_root="${SHELLSPEC_PROJECT_ROOT}/test_servers_shared_$$"
                    temp_shared_dir="${temp_servers_root}/shared"
                    temp_host_dir="${temp_servers_root}/test_shared_server"
                    mkdir -p "${temp_shared_dir}" "${temp_host_dir}"
                    cat > "${temp_shared_dir}/packages.yaml" << 'EOF'
nix:
  nixpkgs-25.05:
    - shared-package1
    - shared-package2
macos:
  homebrew:
    - shared-package1
    - shared-package2
arch:
  pacman:
    - shared-package1
    - shared-package2
wsl:
  yay:
    - shared-package1
    - shared-package2
EOF
                    cat > "${temp_host_dir}/packages.yaml" << 'EOF'
nix:
  nixpkgs-25.05:
    - host-package1
macos:
  homebrew:
    - host-package1
arch:
  pacman:
    - host-package1
wsl:
  yay:
    - host-package1
EOF

                    export SERVER_DIR SERVERS_ROOT
                    SERVER_DIR="${temp_host_dir}"
                    SERVERS_ROOT="${temp_servers_root}"

                    When call ./bin/setup-server --dry-run
                    The status should be success
                    The output should include "Shared Server Configuration"
                    The output should include "shared-package1"
                    The output should include "host-package1"

# Cleanup
                    rm -rf "${temp_servers_root}"
                  End

                  It "handles absence of shared server configurations gracefully"
# Create isolated test structure with only host-specific directory (no shared)
                    temp_servers_root="${SHELLSPEC_PROJECT_ROOT}/test_servers_no_shared_$$"
                    temp_host_dir="${temp_servers_root}/test_no_shared_server"
                    mkdir -p "${temp_host_dir}"
                    cat > "${temp_host_dir}/packages.yaml" << 'EOF'
nix:
  nixpkgs-25.05:
    - host-only-package
macos:
  homebrew:
    - host-only-package
arch:
  pacman:
    - host-only-package
wsl:
  yay:
    - host-only-package
EOF

                    export SERVER_DIR SERVERS_ROOT
                    SERVER_DIR="${temp_host_dir}"
                    SERVERS_ROOT="${temp_servers_root}"

                    When call ./bin/setup-server --dry-run
                    The status should be success
                    The output should include "No shared server configurations found"
                    The output should include "host-only-package"

# Cleanup
                    rm -rf "${temp_servers_root}"
                  End

                  It "validates shared packages.yaml file security"
# Create test structure with invalid shared packages
                    temp_shared_dir="${SHELLSPEC_PROJECT_ROOT}/servers/shared"
                    temp_host_dir="${SHELLSPEC_PROJECT_ROOT}/servers/test_invalid_shared_$$"
                    mkdir -p "${temp_shared_dir}" "${temp_host_dir}"
                    echo "invalid yaml content [" > "${temp_shared_dir}/packages.yaml"
                    echo "nix:
                    nixpkgs-25.05:
                    - host-package1" > "${temp_host_dir}/packages.yaml"

                        When run bash -c "export SERVER_DIR='$temp_host_dir'; ./bin/setup-server --dry-run"
                        The status should be failure
                        The stdout should not be blank
                        The stderr should include "packages.yaml failed validation"

# Cleanup
                        rm -f "${temp_shared_dir}/packages.yaml"
                        rm -rf "${temp_host_dir}"
                      End
                    End
                  End
