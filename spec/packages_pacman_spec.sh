#!/usr/bin/env bash

Describe 'pacman package management'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  Describe 'install_pacman_packages()'
    Context 'with valid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
      setup() {
        # Mock command lookup to find pacman
      command() {
      if [[ "$1" = "-v" && "$2" = "pacman" ]]; then
      return 0
      fi
      builtin command "$@"
      }

        # Bypass sudo while still invoking the pacman function
      sudo() {
      "$@"
      }

        # Track pacman invocations
      pacman() {
      echo "MOCK pacman: $*"
      return 0
      }
      }

      Before 'setup'

        It 'performs system upgrade before installing packages'
          When call install_pacman_packages $'git\nneovim' false

          The output should include 'MOCK pacman: -Syu --noconfirm'
          The output should include 'MOCK pacman: -S --needed --noconfirm git neovim'
          The status should be success
        End
      End

      Context 'in dry-run mode'
      # shellcheck disable=SC2329  # ShellSpec setup function
        setup() {
        command() {
        if [[ "$1" = "-v" && "$2" = "pacman" ]]; then
        return 0
        fi
        builtin command "$@"
        }
        }

        Before 'setup'

          It 'shows planned pacman installation'
            When call install_pacman_packages $'git\nneovim' true

            The output should include 'install via pacman: git, neovim'
            The status should be success
          End
        End

        Context 'when pacman is unavailable'
      # shellcheck disable=SC2329  # ShellSpec setup function
          setup() {
          command() {
          if [[ "$1" = "-v" && "$2" = "pacman" ]]; then
          return 1
          fi
          builtin command "$@"
          }
          }

          Before 'setup'

            It 'logs a warning and skips installation'
              When call install_pacman_packages $'git\nneovim' false

              The output should include 'Warning: pacman not found, skipping pacman packages'
              The status should be success
            End
          End

          Context 'with invalid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
            setup() {
            command() {
            if [[ "$1" = "-v" && "$2" = "pacman" ]]; then
            return 0
            fi
            builtin command "$@"
            }

            sudo() {
            "$@"
            }

            pacman() {
            echo "MOCK pacman: $*"
            return 0
            }
            }

            Before 'setup'

              It 'filters out invalid package names'
                packages=$'git\n../bad\nhtop'
                When call install_pacman_packages "${packages}" false

                The output should include 'MOCK pacman: -S --needed --noconfirm git htop'
                The stderr should include 'Skipping invalid package name: ../bad'
                The stderr should include 'INVALID_PACKAGE'
                The status should be success
              End
            End
          End
        End
