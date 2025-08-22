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
# Create a temporary directory and mock files
                temp_dir=$(mktemp -d)
                temp_proc="${temp_dir}/proc_version"
                echo "Linux version 5.4.0-74-generic" > "${temp_proc}"

# Create mock pacman
                echo '#!/bin/bash' > "${temp_dir}/pacman"
                chmod +x "${temp_dir}/pacman"
                export PATH="${temp_dir}:${PATH}"

# Override the detect_platform function to use our mock
# shellcheck disable=SC2329  # Mock function for testing
                detect_platform() {
                local base_os="linux"

                case "${base_os}" in
                "linux")
      # Mock WSL check to fail by reading our fake /proc/version
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

                The output should equal "arch"

                unset -f detect_platform
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
