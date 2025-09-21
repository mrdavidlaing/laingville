#!/usr/bin/env bash

Describe 'opkg package management'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  Describe 'install_opkg_packages()'
    Context 'with valid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
      setup() {
        # Mock opkg command
      opkg() {
      case "$1" in
      "update")
      echo "Updated package lists"
      return 0
      ;;
      "install")
      shift
      echo "Installing packages: $*"
      return 0
      ;;
      *)
      echo "opkg $*"
      return 0
      ;;
      esac
      }

        # Mock command to find opkg
      command() {
      if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
      return 0
      fi
      builtin command "$@"
      }
      }

      Before 'setup'

        It 'installs packages via opkg'
          When call install_opkg_packages $'git\nrsync' false
          The output should include "Installing packages:"
          The status should be success
        End

        It 'updates package list before installing'
          When call install_opkg_packages "git" false
          The output should include "Updated package lists"
          The status should be success
        End

        It 'handles individual package installation'
          When call install_opkg_packages $'htop\nnano' false
          The output should include "Installing packages: htop nano"
          The status should be success
        End
      End

      Context 'in dry-run mode'
        # shellcheck disable=SC2329  # ShellSpec setup function
        setup() {
          # Mock command to find opkg (dry-run doesn't need actual opkg)
        command() {
        if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
        return 0
        fi
        builtin command "$@"
        }
        }

        Before 'setup'

          It 'shows what would be installed without running opkg'
            When call install_opkg_packages $'git\nrsync\nhtop' true
            The output should include "install via opkg: git, rsync, htop"
            The output should include "update opkg package list"
            The status should be success
          End
        End

        Context 'with empty package list'
          It 'returns without doing anything'
            When call install_opkg_packages "" false
            The output should be blank
            The status should be success
          End
        End

        Context 'when opkg is not available'
          # shellcheck disable=SC2329  # ShellSpec setup function
          setup() {
          # Mock command to not find opkg
          command() {
          if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
          return 1
          fi
          builtin command "$@"
          }
          }

          Before 'setup'

            It 'warns and skips installation'
              When call install_opkg_packages "git" false
              The error should include "opkg not found"
              The status should be success
            End
          End

          Context 'with invalid package names'
            # shellcheck disable=SC2329  # ShellSpec setup function
            setup() {
              # Mock opkg and command
            opkg() {
            case "$1" in
            "update")
            echo "Updated package lists"
            return 0
            ;;
            "install")
            shift
            echo "Installing packages: $*"
            return 0
            ;;
            esac
            }

            command() {
            if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
            return 0
            fi
            builtin command "$@"
            }
            }

            Before 'setup'

              It 'filters out invalid packages'
                packages=$'valid-package\n../invalid\nvalid2'
                When call install_opkg_packages "${packages}" false
                The status should be success
                The output should include "Installing packages:"
                The output should include "valid-package"
                The output should include "valid2"
                The output should not include "Installing packages: ../invalid"
                The error should include "INVALID_PACKAGE - Rejected invalid package name: ../invalid"
              End
            End

            Context 'when package installation fails'
              # shellcheck disable=SC2329  # ShellSpec setup function
              setup() {
            # Mock failing opkg
              # shellcheck disable=SC2329  # Mock function for testing
              opkg() {
              case "$1" in
              "update")
              return 0
              ;;
              "install")
              if [[ "$*" == *"failing-package"* ]]; then
              return 1
              fi
              return 0
              ;;
              esac
              }

            # Mock command to find opkg
              # shellcheck disable=SC2329  # Mock function for testing
              command() {
              if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
              return 0
              fi
              builtin command "$@"
              }
              }

              Before 'setup'

                It 'reports failed packages'
                  packages=$'good-package\nfailing-package'
                  When call install_opkg_packages "${packages}" false
                  The status should be success
                  The output should include "Installing opkg packages: good-package failing-package"
                  The error should include "Failed to install opkg packages: failing-package"
                End
              End
            End
          End
