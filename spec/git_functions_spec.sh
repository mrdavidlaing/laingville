Describe "git.functions.bash"
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/logging.functions.bash"
        Before "source ./lib/security.functions.bash"
          Before "source ./lib/platform.functions.bash"
            Before "source ./lib/packages.functions.bash"
              Before "source ./lib/shared.functions.bash"
                Before "source ./lib/git.functions.bash"

  # Set up test environment
                  Before "export PROJECT_ROOT='${SHELLSPEC_PROJECT_ROOT}'"

                    Describe "setup_git_hooks function"

                      Context "when not in a git repository"
                        It "skips setup in dry-run mode"
        # Mock git rev-parse to fail
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          if [[ "$1" == "rev-parse" ]]; then
                          return 1
                          fi
                          }

                          When call setup_git_hooks true
                          The output should include "skip git hooks setup (not in a git repository)"
                          The status should be success

                          unset -f git
                        End

                        It "skips setup in normal mode"
        # Mock git rev-parse to fail
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          if [[ "$1" == "rev-parse" ]]; then
                          return 1
                          fi
                          }

                          When call setup_git_hooks false
                          The output should include "Skipping git hooks setup (not in a git repository)"
                          The status should be success

                          unset -f git
                        End
                      End

                      Context "when .hooks directory does not exist"
                        It "skips setup in dry-run mode"
        # Create temp directory without .hooks
                          temp_project_dir=$(mktemp -d)
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git rev-parse to succeed
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          if [[ "$1" == "rev-parse" ]]; then
                          echo ".git"
                          return 0
                          fi
                          }

                          When call setup_git_hooks true
                          The output should include "skip git hooks setup (no .hooks directory found)"
                          The status should be success

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End

                        It "skips setup in normal mode"
        # Create temp directory without .hooks
                          temp_project_dir=$(mktemp -d)
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git rev-parse to succeed
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          if [[ "$1" == "rev-parse" ]]; then
                          echo ".git"
                          return 0
                          fi
                          }

                          When call setup_git_hooks false
                          The output should include "No .hooks directory found, skipping git hooks setup"
                          The status should be success

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End
                      End

                      Context "when .hooks directory exists with valid hooks"
                        It "shows hooks in dry-run mode"
        # Create temp directory with .hooks
                          temp_project_dir=$(mktemp -d)
                          mkdir -p "${temp_project_dir}/.hooks"
                          echo '#!/bin/bash' > "${temp_project_dir}/.hooks/pre-push"
                          chmod +x "${temp_project_dir}/.hooks/pre-push"
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git rev-parse to succeed
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          if [[ "$1" == "rev-parse" ]]; then
                          echo ".git"
                          return 0
                          fi
                          }

                          When call setup_git_hooks true
                          The output should include "GIT HOOKS:"
                          The output should include "configure git core.hooksPath to .hooks"
                          The output should include "enable hook: pre-push"
                          The status should be success

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End

                        It "configures git hooks in normal mode"
        # Create temp directory with .hooks
                          temp_project_dir=$(mktemp -d)
                          mkdir -p "${temp_project_dir}/.hooks"
                          echo '#!/bin/bash' > "${temp_project_dir}/.hooks/pre-push"
                          chmod +x "${temp_project_dir}/.hooks/pre-push"
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git commands
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          case "$1" in
                          "rev-parse")
                          echo ".git"
                          return 0
                          ;;
                          "config")
                          if [[ "$2" == "core.hooksPath" && "$3" == ".hooks" ]]; then
                          return 0
                          fi
                          return 1
                          ;;
                          *)
                          return 1
                          ;;
                          esac
                          }

                          When call setup_git_hooks false
                          The output should include "Setting up git hooks..."
                          The output should include "Git configured to use .hooks directory"
                          The output should include "Git hooks setup complete (1 hooks configured)"
                          The status should be success

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End
                      End

                      Context "when .hooks directory contains non-executable hooks"
                        It "shows hooks would be made executable in dry-run mode"
        # Create temp directory with non-executable hook
                          temp_project_dir=$(mktemp -d)
                          mkdir -p "${temp_project_dir}/.hooks"
                          echo '#!/bin/bash' > "${temp_project_dir}/.hooks/pre-commit"
        # Don't make it executable to test detection
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git rev-parse to succeed
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          if [[ "$1" == "rev-parse" ]]; then
                          echo ".git"
                          return 0
                          fi
                          }

                          When call setup_git_hooks true
                          The output should include "enable hook: pre-commit (would make executable)"
                          The status should be success

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End

                        It "makes hooks executable in normal mode"
        # Create temp directory with non-executable hook
                          temp_project_dir=$(mktemp -d)
                          mkdir -p "${temp_project_dir}/.hooks"
                          echo '#!/bin/bash' > "${temp_project_dir}/.hooks/pre-commit"
        # Don't make it executable initially
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git commands
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          case "$1" in
                          "rev-parse")
                          echo ".git"
                          return 0
                          ;;
                          "config")
                          if [[ "$2" == "core.hooksPath" && "$3" == ".hooks" ]]; then
                          return 0
                          fi
                          return 1
                          ;;
                          *)
                          return 1
                          ;;
                          esac
                          }

                          When call setup_git_hooks false
                          The output should include "Made hook executable: pre-commit"
                          The output should include "Git hooks setup complete (1 hooks configured)"
                          The status should be success

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End
                      End

                      Context "when git config fails"
                        It "handles git config failure gracefully"
        # Create temp directory with hooks
                          temp_project_dir=$(mktemp -d)
                          mkdir -p "${temp_project_dir}/.hooks"
                          echo '#!/bin/bash' > "${temp_project_dir}/.hooks/pre-push"
                          export PROJECT_ROOT="${temp_project_dir}"
        
        # Mock git commands with config failure
        # shellcheck disable=SC2329  # Mock function for testing
                          git() { 
                          case "$1" in
                          "rev-parse")
                          echo ".git"
                          return 0
                          ;;
                          "config")
                          return 1  # Simulate failure
                          ;;
                          *)
                          return 1
                          ;;
                          esac
                          }

                          When call setup_git_hooks false
                          The output should include "Failed to configure git hooks path"
                          The status should be failure

                          unset -f git
                          rm -rf "${temp_project_dir}"
                        End
                      End

                    End
                  End
