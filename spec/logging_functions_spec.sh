#!/usr/bin/env bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe "logging.functions.bash"
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/security.functions.bash"

# Test isolation setup
        Before() {
  # Save original environment
        ORIG_TERM="${TERM:-}"
        ORIG_USER="${USER:-}"
        ORIG_PATH="${PATH:-}"
        ORIG_LOG_QUIET="${LOG_QUIET:-}"
        ORIG_LOG_NO_COLOR="${LOG_NO_COLOR:-}"
        ORIG_LOG_COLOR_ENABLED="${LOG_COLOR_ENABLED:-}"
        ORIG_LOG_DEBUG="${LOG_DEBUG:-}"
        ORIG_DRY_RUN="${DRY_RUN:-}"
        ORIG_SHELLSPEC_PROJECT_ROOT="${SHELLSPEC_PROJECT_ROOT:-}"
        ORIG_SHELLSPEC_RUNNING="${SHELLSPEC_RUNNING:-}"

  # Create isolated test environment
        TEST_DIR=$(mktemp -d)
        export HOME="${TEST_DIR}/home"
        mkdir -p "${HOME}"

  # Reset logging state
        LOG_INDENT_LEVEL=0
        LOG_QUIET=false
        LOG_NO_COLOR=false
        LOG_COLOR_ENABLED=false
        unset LOG_TIMERS 2> /dev/null || true

  # Mock external commands for complete isolation
        mock_logger_unavailable() {
        # shellcheck disable=SC2329
        command() {
        case "$*" in
        "-v logger") return 1 ;; # logger not available
        *) return 1 ;;
        esac
        }
        }

        mock_date() {
        # shellcheck disable=SC2329
        date() {
        case "$1" in
        "+%H:%M:%S") echo "12:34:56" ;;
        "+%s") echo "1640995200" ;; # Fixed epoch time
        "+%Y-%m-%d %H:%M:%S") echo "2024-01-01 12:34:56" ;;
        *) echo "Mon Jan  1 12:34:56 UTC 2024" ;;
        esac
        }
        }

        mock_basename() {
        # shellcheck disable=SC2329
        basename() {
        echo "test-script"
        }
        }

  # Apply mocks by default
        mock_logger_unavailable
        mock_date
        mock_basename
        }

        After() {
  # Restore original environment
        export TERM="${ORIG_TERM}"
        export USER="${ORIG_USER}"
        export PATH="${ORIG_PATH}"
        export LOG_QUIET="${ORIG_LOG_QUIET}"
        export LOG_NO_COLOR="${ORIG_LOG_NO_COLOR}"
        export LOG_COLOR_ENABLED="${ORIG_LOG_COLOR_ENABLED}"
        export LOG_DEBUG="${ORIG_LOG_DEBUG}"
        export DRY_RUN="${ORIG_DRY_RUN}"
        export SHELLSPEC_PROJECT_ROOT="${ORIG_SHELLSPEC_PROJECT_ROOT}"
        export SHELLSPEC_RUNNING="${ORIG_SHELLSPEC_RUNNING}"

  # Clean up test directory
        rm -rf "${TEST_DIR}" 2> /dev/null || true

  # Reset function mocks
        unset -f command 2> /dev/null || true
        unset -f date 2> /dev/null || true
        unset -f basename 2> /dev/null || true
        unset -f logger 2> /dev/null || true
        }

# Source the logging functions after setup
        Before "source ./lib/logging.functions.bash"

          Describe "log initialization and color detection"
            It "detects color support when TERM supports colors"
              export TERM="xterm-256color"
              export LOG_NO_COLOR="false"

              When call log_init

              The variable LOG_COLOR_ENABLED should equal "true"
              The output should include "Starting"
            End

            It "disables colors when LOG_NO_COLOR is true"
              export TERM="xterm-256color"
              export LOG_NO_COLOR="true"

              When call log_init

              The variable LOG_COLOR_ENABLED should equal "false"
              The output should include "Starting"
            End

            It "disables colors on dumb terminal"
              export TERM="dumb"
              export LOG_NO_COLOR="false"

              When call log_init

              The variable LOG_COLOR_ENABLED should equal "false"
              The output should include "Starting"
            End

            It "enables colors for xterm terminal"
              export TERM="xterm"
              export LOG_NO_COLOR="false"

              When call log_init

              The variable LOG_COLOR_ENABLED should equal "true"
              The output should include "Starting"
            End

            It "enables colors for screen terminal"
              export TERM="screen"
              export LOG_NO_COLOR="false"

              When call log_init

              The variable LOG_COLOR_ENABLED should equal "true"
              The output should include "Starting"
            End

            It "displays script start banner"
              export TERM="xterm"
              export LOG_NO_COLOR="true" # No colors for predictable output
# Override basename mock for this specific test
              # shellcheck disable=SC2329
        basename() { echo "test-script"; }

              When call log_init

              The output should include "Starting test-script"
            End

            It "shows dry-run mode banner when enabled"
              export TERM="xterm"
              export LOG_NO_COLOR="true"
              export DRY_RUN="true"

              When call log_init

              The output should include "DRY RUN MODE - No changes will be made"
            End
          End

          Describe "_log_color helper function"
            It "applies color when colors are enabled"
              LOG_COLOR_ENABLED=true

              When call _log_color "\033[32m" "test message"

              The output should equal "$(echo -e "\033[32mtest message\033[0m")"
            End

            It "outputs plain text when colors are disabled"
              LOG_COLOR_ENABLED=false

              When call _log_color "\033[32m" "test message"

              The output should equal "test message"
            End
          End

          Describe "_log_timestamp helper function"
            It "returns formatted timestamp"
# Override date mock for this specific test
              # shellcheck disable=SC2329
        date() {
              case "$1" in
              "+%H:%M:%S") echo "12:34:56" ;;
              *) echo "12:34:56" ;;
              esac
              }

              When call _log_timestamp

              The output should equal "12:34:56"
            End
          End

          Describe "_log_indent helper function"
            It "returns no indentation at level 0"
              LOG_INDENT_LEVEL=0

              When call _log_indent

              The output should equal ""
            End

            It "returns proper indentation at level 2"
              LOG_INDENT_LEVEL=2

              When call _log_indent

              The output should equal "    " # 4 spaces (2 * 2)
            End

            It "returns proper indentation at level 5"
              LOG_INDENT_LEVEL=5

              When call _log_indent

              The output should equal "          " # 10 spaces (5 * 2)
            End
          End

          Describe "log_section function"
            It "outputs section header with underline"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_section "Test Section"

              The output should include "Test Section"
              The output should include "--------------------"
            End

            It "respects indentation level"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=2

              When call log_section "Indented Section"

              The output should include "    Indented Section"
            End
          End

          Describe "log_subsection function"
            It "outputs subsection header"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_subsection "Test Subsection"

              The output should include "Test Subsection"
            End

            It "respects indentation level"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=1

              When call log_subsection "Indented Subsection"

              The output should include "  Indented Subsection"
            End
          End

          Describe "log_success function"
            It "outputs success message with icon"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_success "Operation completed"

              The output should include "[OK] Operation completed"
            End

            It "respects indentation"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=2

              When call log_success "Indented success"

              The output should include "    [OK] Indented success"
            End
          End

          Describe "log_error function"
            It "outputs error message to stderr"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_error "Something failed"

              The stderr should include "[ERROR] ERROR: Something failed"
              The stdout should equal ""
            End

            It "respects indentation in error messages"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=1

              When call log_error "Indented error"

              The stderr should include "  [ERROR] ERROR: Indented error"
            End
          End

          Describe "log_warning function"
            It "outputs warning message with icon"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_warning "This is a warning"

              The output should include "[WARN] Warning: This is a warning"
            End
          End

          Describe "log_info function"
            It "outputs info message when not quiet"
              export LOG_NO_COLOR="true"
              LOG_QUIET=false
              LOG_INDENT_LEVEL=0

              When call log_info "Information message"

              The output should include "[INFO] Information message"
            End

            It "suppresses output when LOG_QUIET is true"
              export LOG_NO_COLOR="true"
              LOG_QUIET=true

              When call log_info "Hidden message"

              The output should equal ""
            End
          End

          Describe "log_debug function"
            It "outputs debug message when LOG_DEBUG is true"
              export LOG_NO_COLOR="true"
              export LOG_DEBUG="true"
              LOG_INDENT_LEVEL=0

              When call log_debug "Debug information"

              The output should include "[DEBUG] Debug information"
            End

            It "suppresses output when LOG_DEBUG is not set"
              export LOG_NO_COLOR="true"
              unset LOG_DEBUG

              When call log_debug "Hidden debug"

              The output should equal ""
            End

            It "suppresses output when LOG_DEBUG is false"
              export LOG_NO_COLOR="true"
              export LOG_DEBUG="false"

              When call log_debug "Hidden debug"

              The output should equal ""
            End
          End

          Describe "log_dry_run function"
            It "outputs dry-run message with icon"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_dry_run "install package"

              The output should include "* Would: install package"
            End
          End

          Describe "log_progress function"
            It "outputs progress with counter"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_progress "5" "10" "processing item"

              The output should include "(5/10) processing item"
            End
          End

          Describe "indentation management"
            It "increments indent level"
              LOG_INDENT_LEVEL=0
              test_increment() {
              log_indent
              echo "INDENT_LEVEL=${LOG_INDENT_LEVEL}"
              }

              When run test_increment

              The output should include "INDENT_LEVEL=1"
              The status should be success
            End

            It "decrements indent level"
              LOG_INDENT_LEVEL=2

              When call log_unindent

              The variable LOG_INDENT_LEVEL should equal 1
            End

            It "does not go below zero when unindenting"
              LOG_INDENT_LEVEL=0
              test_unindent() {
              log_unindent
              echo "INDENT_LEVEL=${LOG_INDENT_LEVEL}"
              }

              When run test_unindent

              The output should include "INDENT_LEVEL=0"
              The status should be success
            End

            It "executes command with temporary indentation"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              test_command() {
              log_info "Indented message"
              }

              When call log_with_indent test_command

              The output should include "  [INFO] Indented message"
              The variable LOG_INDENT_LEVEL should equal 0 # Should be back to original
            End
          End

          Describe "summary functions"
            It "starts summary with title"
              export LOG_NO_COLOR="true"

              When call log_summary_start "Test Summary"

              The output should include "[Test Summary Summary]"
            End

            It "outputs summary item with success status"
              export LOG_NO_COLOR="true"

              When call log_summary_item "success" "Operation succeeded"

              The output should include "- [OK] Operation succeeded"
            End

            It "outputs summary item with warning status"
              export LOG_NO_COLOR="true"

              When call log_summary_item "warning" "Minor issue occurred"

              The output should include "- [WARN] Minor issue occurred"
            End

            It "outputs summary item with error status"
              export LOG_NO_COLOR="true"

              When call log_summary_item "error" "Operation failed"

              The output should include "- [ERROR] Operation failed"
            End

            It "outputs summary item with info status"
              export LOG_NO_COLOR="true"

              When call log_summary_item "info" "General information"

              The output should include "- [INFO] General information"
            End

            It "outputs summary item with unknown status"
              export LOG_NO_COLOR="true"

              When call log_summary_item "unknown" "Unknown status"

              The output should include "- • Unknown status"
            End

            It "ends summary properly"
              export LOG_NO_COLOR="true"

              When call log_summary_end

              The output should include "[END]"
            End
          End

          Describe "timer functions"
            Context "with bash 4+ (associative arrays)"
# Most modern systems have bash 4+
              It "starts and ends timer successfully"
                LOG_TIMERS=() # Initialize associative array
                export LOG_NO_COLOR="true"

                When run bash -c '
                source ./lib/logging.functions.bash
                log_timer_start "test"
                sleep 0.1  # Small delay to ensure time difference
                log_timer_end "test" "Test operation completed"
                '

                The output should include "Test operation completed"
                The status should be success
              End

              It "handles timer end with custom message"
                LOG_TIMERS=()
                export LOG_NO_COLOR="true"

                When run bash -c '
                source ./lib/logging.functions.bash
                log_timer_start "custom"
                log_timer_end "custom" "Custom message"
                '

                The output should include "Custom message"
              End

              It "handles timer end without custom message"
                LOG_TIMERS=()
                export LOG_NO_COLOR="true"

                When run bash -c '
                source ./lib/logging.functions.bash
                log_timer_start "default"
                log_timer_end "default"
                '

                The output should include "Completed default in"
              End
            End
          End

          Describe "specialized logging functions"
            It "logs package installation in normal mode"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_package_install "pacman" "vim git" "false"

              The output should include "[INFO] Installing via pacman: vim git"
            End

            It "logs package installation in dry-run mode"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_package_install "yay" "aur-package" "true"

              The output should include "* Would: Install via yay: aur-package"
            End

            It "logs symlink creation in normal mode"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_symlink "/home/user/.config" "/dotfiles/.config" "false"

              The output should include "[OK] Linked /home/user/.config"
            End

            It "logs symlink creation in dry-run mode"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_symlink "/home/user/.vimrc" "/dotfiles/.vimrc" "true"

              The output should include "* Would: Link /home/user/.vimrc → /dotfiles/.vimrc"
            End

            It "logs successful script result"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_script_result "setup.sh" "true"

              The output should include "[OK] Script setup.sh completed"
            End

            It "logs failed script result"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

              When call log_script_result "setup.sh" "false"

              The stderr should include "[ERROR] ERROR: Script setup.sh failed"
            End
          End

          Describe "log_security_event function"
            It "logs security event to stderr without system logger"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

# Mock logger command to not exist and date command
              # shellcheck disable=SC2329
        command() { return 1; }
              # shellcheck disable=SC2329
        date() {
              case "$1" in
              "+%Y-%m-%d %H:%M:%S") echo "2024-01-01 12:34:56" ;;
              *) echo "2024-01-01 12:34:56" ;;
              esac
              }

              When call log_security_event "INJECTION_ATTEMPT" "Malicious input detected"

              The stderr should include "SECURITY[2024-01-01 12:34:56]: INJECTION_ATTEMPT - Malicious input detected"
            End

            It "logs security event to system logger when available"
              export LOG_NO_COLOR="true"
              LOG_INDENT_LEVEL=0

# Mock logger command to exist and capture its call
              # shellcheck disable=SC2329
        command() {
              case "$*" in
              "-v logger") return 0 ;;
              *) return 1 ;;
              esac
              }

              # shellcheck disable=SC2329
        date() {
              case "$1" in
              "+%Y-%m-%d %H:%M:%S") echo "2024-01-01 12:34:56" ;;
              *) echo "2024-01-01 12:34:56" ;;
              esac
              }

              logger() {
              echo "LOGGER_CALLED: $*" >&2
        return 0
        }

        When call log_security_event "TEST_EVENT" "Test security message"

        The stderr should include "SECURITY[2024-01-01 12:34:56]: TEST_EVENT - Test security message"
        The stderr should include "LOGGER_CALLED: -t laingville-setup SECURITY: TEST_EVENT - Test security message"
      End
    End

    Describe "log_finish function"
      It "skips logging during shellspec tests"
        export SHELLSPEC_PROJECT_ROOT="/test/path"
        export SHELLSPEC_RUNNING="true"

        When call log_finish "0"

        The output should equal ""
      End

      It "logs successful completion"
        unset SHELLSPEC_PROJECT_ROOT
        unset SHELLSPEC_RUNNING
        export LOG_NO_COLOR="true"
# Override basename mock for this specific test
              # shellcheck disable=SC2329
        basename() { echo "test-script"; }

              When call log_finish "0"

              The output should include "[OK] Completed test-script successfully"
            End

            It "logs failure with exit code"
              unset SHELLSPEC_PROJECT_ROOT
              unset SHELLSPEC_RUNNING
              export LOG_NO_COLOR="true"
# Override basename mock for this specific test
              # shellcheck disable=SC2329
        basename() { echo "test-script"; }

              When call log_finish "1"

              The stderr should include "[ERROR] ERROR: Failed test-script with exit code 1"
              The stdout should equal ""
            End
          End

        End
