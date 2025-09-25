#!/usr/bin/env bash

Describe 'yay package management'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  Describe 'install_yay_packages()'
    Context 'with valid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
      setup() {
      command() {
      if [[ "$1" = "-v" && "$2" = "yay" ]]; then
      return 0
      fi
      builtin command "$@"
      }

      yay() {
      echo "MOCK yay: $*"
      return 0
      }
      }

      Before 'setup'

        It 'refreshes databases and installs packages'
          When call install_yay_packages $'hyprland\nwaybar' false

          The output should include 'MOCK yay: -Syy'
          The output should include 'MOCK yay: -S --needed --noconfirm --batchinstall hyprland waybar'
          The status should be success
        End
      End

      Context 'in dry-run mode'
      # shellcheck disable=SC2329  # ShellSpec setup function
        setup() {
        command() {
        if [[ "$1" = "-v" && "$2" = "yay" ]]; then
        return 0
        fi
        builtin command "$@"
        }
        }

        Before 'setup'

          It 'shows planned yay installation'
            When call install_yay_packages $'hyprland\nwaybar' true

            The output should include 'install via yay: hyprland, waybar'
            The status should be success
          End
        End

        Context 'when yay is unavailable'
      # shellcheck disable=SC2329  # ShellSpec setup function
          setup() {
          command() {
          if [[ "$1" = "-v" && "$2" = "yay" ]]; then
          return 1
          fi
          builtin command "$@"
          }
          }

          Before 'setup'

            It 'logs a warning and skips installation'
              When call install_yay_packages $'hyprland\nwaybar' false

              The output should include 'Warning: yay not found, skipping AUR packages'
              The status should be success
            End
          End

          Context 'with invalid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
            setup() {
            command() {
            if [[ "$1" = "-v" && "$2" = "yay" ]]; then
            return 0
            fi
            builtin command "$@"
            }

            yay() {
            echo "MOCK yay: $*"
            return 0
            }
            }

            Before 'setup'

              It 'filters out invalid package names'
                packages=$'hyprland\n../bad\nwaybar'
                When call install_yay_packages "${packages}" false

                The output should include 'MOCK yay: -S --needed --noconfirm --batchinstall hyprland waybar'
                The stderr should include 'Skipping invalid package name: ../bad'
                The stderr should include 'INVALID_PACKAGE'
                The status should be success
              End
            End
          End
        End
