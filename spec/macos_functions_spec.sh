Describe "macos.functions.bash"

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
                  Before "source ./lib/macos.functions.bash"

                    Describe "install_homebrew function"
                      It "shows correct dry-run output when brew not installed"
      # Mock command -v to return failure for brew
      # shellcheck disable=SC2329  # Mock function for testing
                        command() {
                        if [[ "${1}" = "-v" ]] && [[ "${2}" = "brew" ]]; then
                        return 1
                        fi
        # Fall back to real command for other calls
                        /usr/bin/command "${@}"
                        }

                        When call install_homebrew true

                        The status should be success
                        The output should include "HOMEBREW SETUP:"
                        The output should include "install Homebrew via official installer"
                      End

                      It "shows correct dry-run output when brew already installed"
      # Mock command -v to return success for brew
      # shellcheck disable=SC2329  # Mock function for testing
                        command() {
                        if [[ "${1}" = "-v" ]] && [[ "${2}" = "brew" ]]; then
                        return 0
                        fi
        # Fall back to real command for other calls
                        /usr/bin/command "${@}"
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
                        The output should include "set WezTerm as default terminal"
                        The output should include "disable press-and-hold for VSCode and Cursor"
                        The output should include "set system locale to en_IE.UTF-8"
                        The output should include "enable separate spaces for each display"
                      End
                    End

                    Describe "generate_brewfile function"
    # Create a test packages file
                      Before 'TEST_PACKAGES_FILE="$(mktemp)"'
                        After 'rm -f "$TEST_PACKAGES_FILE"'

                          It "generates correct Brewfile format with homebrew and cask packages"
      # Create test packages.yaml with both homebrew and cask packages
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
    - git
    - neovim
    - jq
  cask:
    - alacritty
    - docker-desktop
EOF

                            When call generate_brewfile "$TEST_PACKAGES_FILE" "macos" false
      
                            The status should be success
      # Check that a Brewfile path is returned (extract just stdout, ignore stderr logging)
                            The output should match pattern "*/laingville_brewfile.*" 
      
      # Read the generated Brewfile and check its content
                            brewfile_path="$(generate_brewfile "$TEST_PACKAGES_FILE" "macos" false 2>/dev/null)"
                            The path "$brewfile_path" should be file
                            The contents of file "$brewfile_path" should include "# Generated Brewfile for macos packages"
                            The contents of file "$brewfile_path" should include 'brew "git"'
                            The contents of file "$brewfile_path" should include 'brew "neovim"'
                            The contents of file "$brewfile_path" should include 'brew "jq"'
                            The contents of file "$brewfile_path" should include 'cask "alacritty"'
                            The contents of file "$brewfile_path" should include 'cask "docker-desktop"'
                          End

                          It "handles empty packages gracefully"
      # Create test packages.yaml with no packages
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
  cask:
EOF

                            When call generate_brewfile "$TEST_PACKAGES_FILE" "macos" false
      
                            The status should be success
      # Expect stdout to contain the brewfile path
                            The output should match pattern "*/laingville_brewfile.*"
      # Check that a Brewfile is still generated
                            brewfile_path="$(generate_brewfile "$TEST_PACKAGES_FILE" "macos" false 2>/dev/null)"
                            The path "$brewfile_path" should be file
                            The contents of file "$brewfile_path" should include "# Generated Brewfile for macos packages"
                          End

                          It "shows correct dry-run output"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
    - git
  cask:
    - alacritty
EOF

                            When call generate_brewfile "$TEST_PACKAGES_FILE" "macos" true
      
                            The status should be success
                            The output should include "generate Brewfile from packages.yaml"
                          End

                          It "validates invalid YAML file"
      # Create invalid YAML
                            echo "invalid: yaml: content: [" > "$TEST_PACKAGES_FILE"
      
                            When call generate_brewfile "$TEST_PACKAGES_FILE" "macos" false
      
                            The status should be failure
                        # Expect stderr to contain security validation messages
                            The stderr should include "YAML file has unbalanced square brackets"
                            The stderr should include "SECURITY"
                            The stderr should include "INVALID_YAML"
                          End

                          It "validates invalid platform"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
    - git
EOF

                            When call generate_brewfile "$TEST_PACKAGES_FILE" "invalid../platform" false
      
                            The status should be failure
                        # Expect stderr to contain security validation messages
                            The stderr should include "SECURITY"
                            The stderr should include "INVALID_PLATFORM"
                          End

                          It "generates tap entries before brew entries"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  tap:
    - steveyegge/beads
    - homebrew/cask-fonts
  homebrew:
    - git
    - steveyegge/beads/bd
  cask:
    - alacritty
EOF

                            When call generate_brewfile "$TEST_PACKAGES_FILE" "macos" false

                            The status should be success
      # Check that a Brewfile path is returned
                            The output should match pattern "*/laingville_brewfile.*"
      # Read the generated Brewfile and check tap entries
                            brewfile_path="$(generate_brewfile "$TEST_PACKAGES_FILE" "macos" false 2>/dev/null)"
                            The path "$brewfile_path" should be file
                            The contents of file "$brewfile_path" should include 'tap "steveyegge/beads"'
                            The contents of file "$brewfile_path" should include 'tap "homebrew/cask-fonts"'
                            The contents of file "$brewfile_path" should include 'brew "steveyegge/beads/bd"'
      # Verify taps come before brew entries (check order by line numbers)
                            tap_line=$(grep -n '^tap' "$brewfile_path" | head -1 | cut -d: -f1)
                            brew_line=$(grep -n '^brew' "$brewfile_path" | head -1 | cut -d: -f1)
                            Assert [ "$tap_line" -lt "$brew_line" ]
                          End
                        End

                        Describe "install_packages_with_brewfile function"
                          Before 'TEST_PACKAGES_FILE="$(mktemp)"'
                            After 'rm -f "$TEST_PACKAGES_FILE"'

                              It "shows correct dry-run output for both package types"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
    - git
    - neovim
  cask:
    - alacritty
    - docker-desktop
EOF

                                When call install_packages_with_brewfile "$TEST_PACKAGES_FILE" "macos" true
      
                                The status should be success
                                The output should include "install via homebrew: git, neovim"
                                The output should include "install via cask: alacritty, docker-desktop"
                              End

                              It "shows taps in dry-run output"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  tap:
    - steveyegge/beads
    - homebrew/cask-fonts
  homebrew:
    - git
    - steveyegge/beads/bd
  cask:
    - alacritty
EOF

                                When call install_packages_with_brewfile "$TEST_PACKAGES_FILE" "macos" true

                                The status should be success
                                The output should include "add tap: steveyegge/beads, homebrew/cask-fonts"
                                The output should include "install via homebrew: git, steveyegge/beads/bd"
                                The output should include "install via cask: alacritty"
                              End

                              It "handles empty packages in dry-run mode"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
  cask:
EOF

                                When call install_packages_with_brewfile "$TEST_PACKAGES_FILE" "macos" true
      
                                The status should be success
                                The output should not include "install via homebrew:"
                                The output should not include "install via cask:"
                              End

                              It "skips installation when no packages found"
      cat > "$TEST_PACKAGES_FILE" << 'EOF'
macos:
  homebrew:
  cask:
EOF

      # Mock brew to detect if called
                                brew_called=false
      # shellcheck disable=SC2329
                                brew() {
                                brew_called=true
                                return 0
                                }
      
                                When call install_packages_with_brewfile "$TEST_PACKAGES_FILE" "macos" false
      
                                The status should be success
                                The output should include "No packages to install"
      # Verify brew bundle was not called
                                The variable brew_called should equal false
                              End
                            End

                            Describe "macOS functions handle non-dry-run mode gracefully"
                              It "handles non-dry-run mode without actual system changes"
      # Mock command -v to simulate brew not being available
      # shellcheck disable=SC2329  # Mock function for testing
                                command() {
                                if [[ "${1}" = "-v" ]] && [[ "${2}" = "brew" ]]; then
                                return 1
                                fi
        # Fall back to real command for other calls
                                /usr/bin/command "${@}"
                                }

      # Mock curl to prevent actual Homebrew installation
      # shellcheck disable=SC2329  # Mock function for testing
                                curl() {
                                echo "# Mock Homebrew installer script"
                                echo "echo 'Mock Homebrew installation'"
                                }

      # Mock defaults to prevent actual system changes
      # shellcheck disable=SC2329  # Mock function for testing
                                defaults() {
                                echo "Mock defaults command: ${*}"
                                }

      # Mock osascript to prevent actual login item changes
      # shellcheck disable=SC2329  # Mock function for testing
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
      # shellcheck disable=SC2329  # Mock function for testing
                                defaults() {
                                echo "Mock defaults command: ${*}"
                                }

      # Mock osascript to prevent actual login item changes
      # shellcheck disable=SC2329  # Mock function for testing
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

                              It "generate_brewfile function exists"
                                When run type generate_brewfile
      
                                The status should be success
                                The output should include "is a function"
                              End

                              It "install_packages_with_brewfile function exists"
                                When run type install_packages_with_brewfile
      
                                The status should be success
                                The output should include "is a function"
                              End
                            End

                            Describe "setup_systemd_services skips systemd on macOS"
                              It "skips systemd on macOS in dry-run mode"
      # Mock detect_platform to return macos
      # shellcheck disable=SC2329  # Mock function for testing
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
      # shellcheck disable=SC2329  # Mock function for testing
                                detect_platform() {
                                echo "macos"
                                }

                                When call setup_systemd_services false

                                The status should be success
                                The output should include "Skipping systemd services (not supported on macos)"
                              End
                            End
                          End
