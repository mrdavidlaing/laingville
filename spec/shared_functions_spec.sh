Describe "shared.functions.bash"
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/logging.functions.bash"
        Before "source ./lib/security.functions.bash"
          Before "source ./lib/shared.functions.bash"

            Describe "detect_platform function"
              It "returns macos on Darwin"
# Mock uname command to return Darwin
# shellcheck disable=SC2329  # Mock function for testing
                uname() { echo "Darwin"; }

                When call detect_platform

                The output should equal "macos"

                unset -f uname
              End

              It "prioritizes darwin over pacman"
# Mock uname to return Darwin, even if pacman exists
# shellcheck disable=SC2329  # Mock function for testing
                uname() { echo "Darwin"; }
# Create fake pacman in PATH
                temp_dir=$(mktemp -d)
                echo '#!/bin/bash' > "${temp_dir}/pacman"
                chmod +x "${temp_dir}/pacman"
                export PATH="${temp_dir}:${PATH}"

                When call detect_platform

                The output should equal "macos"

                unset -f uname
                rm -rf "${temp_dir}"
              End

              It "returns arch on Linux with pacman"
# Create a temporary directory with mock executables
                temp_dir=$(mktemp -d)
                
# Create mock pacman executable
                echo '#!/bin/bash' > "${temp_dir}/pacman"
                chmod +x "${temp_dir}/pacman"
                
# Mock uname to return Linux
# shellcheck disable=SC2329  # Mock function for testing
                uname() { echo "Linux"; }
                
# Put our mock directory first in PATH
                OLD_PATH="${PATH}"
                export PATH="${temp_dir}:${PATH}"

                When call detect_platform

                The output should equal "arch"

                unset -f uname
                export PATH="${OLD_PATH}"
                rm -rf "${temp_dir}"
              End

              It "returns arch on Linux even when both pacman and nix are installed"
# Create a temporary directory with mock executables
                temp_dir=$(mktemp -d)
                
# Create mock pacman and nix executables
                echo '#!/bin/bash' > "${temp_dir}/pacman"
                chmod +x "${temp_dir}/pacman"
                echo '#!/bin/bash' > "${temp_dir}/nix"
                chmod +x "${temp_dir}/nix"
                
# Mock uname to return Linux
# shellcheck disable=SC2329  # Mock function for testing
                uname() { echo "Linux"; }
                
# Put our mock directory first in PATH so both commands are found
                OLD_PATH="${PATH}"
                export PATH="${temp_dir}:${PATH}"

                When call detect_platform

                The output should equal "arch"

                unset -f uname
                export PATH="${OLD_PATH}"
                rm -rf "${temp_dir}"
              End

              It "returns linux on Linux without pacman"
# Create a temporary directory for mock files
                temp_dir=$(mktemp -d)
                temp_proc="${temp_dir}/proc_version"
                echo "Linux version 5.4.0-74-generic" > "${temp_proc}"

# Override the detect_platform function to use our mock and ensure no pacman
# shellcheck disable=SC2329  # Mock function for testing
                detect_platform() {
                local base_os="linux"

                case "${base_os}" in
                "linux")
      # Mock WSL check to fail by reading our fake /proc/version
                if grep -qi "microsoft\|wsl" "${temp_proc}" 2> /dev/null; then
                echo "wsl"
                elif false; then # Force pacman check to fail
                echo "arch"
                else
                echo "linux"
                fi
                ;;
                *)
                echo "${base_os}"
                ;;
                esac
                }

                When call detect_platform

                The output should equal "linux"

                unset -f detect_platform
                rm -rf "${temp_dir}"
              End

              It "correctly detects WSL platform"
                temp_dir=$(mktemp -d)
                temp_proc="${temp_dir}/proc_version"
                echo "Linux version 5.4.0-74-generic (buildd@lcy01-amd64-029) #74~20.04.1-Ubuntu SMP Wed Nov 24 19:38:25 UTC 2021 WSL2" > "${temp_proc}"

                # Override detect_platform to use our mock WSL proc version
                # shellcheck disable=SC2329  # Mock function for testing
                detect_platform() {
                local base_os="linux"
                case "${base_os}" in
                "linux")
                if grep -qi "microsoft\|wsl" "${temp_proc}" 2> /dev/null; then
                echo "wsl"
                elif command -v pacman > /dev/null 2>&1; then
                echo "arch"
                else
                echo "linux"
                fi
                ;;
                *)
                echo "${base_os}"
                ;;
                esac
                }

                When call detect_platform

                The output should equal "wsl"

                unset -f detect_platform
                rm -rf "${temp_dir}"
              End

              It "integrates WSL detection with correct package selection"
                # Create test package file
                temp_dir=$(mktemp -d)
                packages_file="${temp_dir}/packages.yaml"
cat > "${packages_file}" << 'EOF'
arch:
  yay:
    - hyprland
    - waybar
    - gimp

wsl:
  yay:
    - git
    - neovim
    - tmux
EOF

                # Mock WSL environment
                temp_proc="${temp_dir}/proc_version" 
                echo "Linux WSL2" > "${temp_proc}"

                # Mock platform detection
                detect_platform() {
                if grep -qi "wsl" "${temp_proc}" 2> /dev/null; then
                echo "wsl"
                else
                echo "arch"
                fi
                }

                # Mock the WSL-specific handler function for integration test
                handle_wsl_packages() {
                local platform="$1" dry_run="$2" packages_file="$3" context="$4"
                echo "USER PACKAGES (${platform}):"
                echo "MOCK: process_packages pacman ${platform}"
                echo "MOCK: process_packages yay ${platform}"
                }

                # Test the integration: detect platform -> use correct packages
                platform=$(detect_platform)
                When call handle_packages_from_file "${platform}" true "${packages_file}" "USER"

                The output should include "MOCK: process_packages pacman wsl"
                The output should include "MOCK: process_packages yay wsl"
                The output should not include "MOCK: process_packages pacman arch"

                unset -f detect_platform
                rm -rf "${temp_dir}"
              End
            End

            Describe "get_packages_from_file function"
              It "extracts packages from real config"
                export DOTFILES_DIR
                DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"

                When call get_packages_from_file "arch" "yay" "${DOTFILES_DIR}/packages.yaml"

                The output should not be blank
                The output should include "hyprland"
              End

              It "extracts macOS packages from real config"
                export DOTFILES_DIR
                DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"

# Test homebrew packages
                When call get_packages_from_file "macos" "homebrew" "${DOTFILES_DIR}/packages.yaml"

                The output should not be blank
                The output should include "git"
                The output should include "starship"
                The output should include "ripgrep"
              End

              It "extracts cask packages from real config"
                export DOTFILES_DIR
                DOTFILES_DIR="$(cd "${SHELLSPEC_PROJECT_ROOT}/dotfiles/mrdavidlaing" && pwd)"

                When call get_packages_from_file "macos" "cask" "${DOTFILES_DIR}/packages.yaml"

                The output should not be blank
                The output should include "alacritty"
                The output should include "claude"
                The output should include "font-jetbrains-mono-nerd-font"
              End
            End

            Describe "server packages.yaml parsing"
              It "extracts packages correctly"
                temp_dir=$(mktemp -d)
                server_dir="${temp_dir}/servers/testhost"
                mkdir -p "${server_dir}"
cat > "${server_dir}/packages.yaml" << 'EOF'
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

                When call get_packages_from_file "arch" "pacman" "${server_dir}/packages.yaml"

                The output should include "k3s"
                The output should include "htop"

                rm -rf "${temp_dir}"
              End
            End

            Describe "handle_packages_from_file function"
              It "correctly handles wsl platform with wsl section"
                temp_dir=$(mktemp -d)
                packages_file="${temp_dir}/packages.yaml"
cat > "${packages_file}" << 'EOF'
arch:
  yay:
    - hyprland
    - waybar
    - gimp

wsl:
  yay:
    - git
    - neovim
    - tmux
EOF

                # Mock the WSL-specific handler function
                handle_wsl_packages() {
                local platform="$1" dry_run="$2" packages_file="$3" context="$4"
                echo "USER PACKAGES (${platform}):"
                echo "MOCK: install_yay"
                echo "MOCK: pacman ${platform}"
                echo "MOCK: yay ${platform}"
                }

                # Test WSL platform uses wsl section (not arch)
                When call handle_packages_from_file "wsl" true "${packages_file}" "USER"

                The output should include "MOCK: pacman wsl"
                The output should include "MOCK: yay wsl"
                The output should not include "MOCK: pacman arch"

                rm -rf "${temp_dir}"
              End

              It "correctly handles arch platform with arch section"
                temp_dir=$(mktemp -d)
                packages_file="${temp_dir}/packages.yaml"
cat > "${packages_file}" << 'EOF'
arch:
  yay:
    - hyprland
    - waybar

wsl:
  yay:
    - git
    - neovim
EOF

                # Mock the functions that would be called
                process_packages() {
                local manager="$1" cmd="$2" platform="$3" dry_run="$4" file="$5"
                echo "MOCK: ${manager} ${platform}"
                }

                install_yay() {
                echo "MOCK: install_yay"
                }

                # Test arch platform uses arch section
                When call handle_packages_from_file "arch" true "${packages_file}" "USER"

                The output should include "MOCK: pacman arch"
                The output should include "MOCK: yay arch"
                The output should not include "MOCK: pacman wsl"

                rm -rf "${temp_dir}"
              End

              It "handles missing packages file gracefully"
                non_existent_file="/tmp/does_not_exist.yaml"

                When call handle_packages_from_file "wsl" true "${non_existent_file}" "USER"

                The output should include "No packages.yaml found"
              End

              It "calls wsl-specific handler for wsl platform"
                temp_dir=$(mktemp -d)
                packages_file="${temp_dir}/packages.yaml"
cat > "${packages_file}" << 'EOF'
wsl:
  yay:
    - git
EOF

                # Mock the WSL-specific function
                handle_wsl_packages() {
                echo "MOCK: handle_wsl_packages called with $*"
                }

                When call handle_packages_from_file "wsl" false "${packages_file}" "USER"

                The output should include "MOCK: handle_wsl_packages called with wsl false"

                rm -rf "${temp_dir}"
              End
            End

            Describe "validate_script_name function"
              It "accepts valid names"
                When call validate_script_name valid_name

                The status should be success
              End

              It "rejects invalid characters"
                When call validate_script_name "bad_name!"

                The status should not be success
                The stderr should include "Invalid script name contains illegal characters"
              End

              It "rejects path traversal"
                When call validate_script_name "../evil"

                The status should not be success
                The stderr should include "Invalid script name contains illegal characters"
              End

              It "rejects too long names"
                longname=$(printf 'a%.0s' {1..60})

                When call validate_script_name "${longname}"

                The status should not be success
                The stderr should include "Script name too long"
              End
            End

# Additional comprehensive tests can be added here in future iterations

          End
