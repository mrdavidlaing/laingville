#!/usr/bin/env bash

Describe 'Homebrew package management'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  Describe 'install_homebrew_packages()'
    Context 'with valid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
      setup() {
      command() {
      if [[ "$1" = "-v" && "$2" = "brew" ]]; then
      return 0
      fi
      builtin command "$@"
      }

      brew() {
      echo "MOCK brew: $*"
      return 0
      }
      }

      Before 'setup'

        It 'installs each package individually'
          When call install_homebrew_packages $'git\nneovim' false

          The output should include 'MOCK brew: install git'
          The output should include 'MOCK brew: install neovim'
          The status should be success
        End
      End

      Context 'in dry-run mode'
      # shellcheck disable=SC2329  # ShellSpec setup function
        setup() {
        command() {
        if [[ "$1" = "-v" && "$2" = "brew" ]]; then
        return 0
        fi
        builtin command "$@"
        }
        }

        Before 'setup'

          It 'shows planned Homebrew installation'
            When call install_homebrew_packages $'git\nneovim' true

            The output should include 'install via homebrew: git, neovim'
            The status should be success
          End
        End

        Context 'when brew is unavailable'
      # shellcheck disable=SC2329  # ShellSpec setup function
          setup() {
          command() {
          if [[ "$1" = "-v" && "$2" = "brew" ]]; then
          return 1
          fi
          builtin command "$@"
          }
          }

          Before 'setup'

            It 'logs a warning and skips installation'
              When call install_homebrew_packages $'git\nneovim' false

              The output should include 'Warning: homebrew not found, skipping homebrew packages'
              The status should be success
            End
          End

          Context 'with invalid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
            setup() {
            command() {
            if [[ "$1" = "-v" && "$2" = "brew" ]]; then
            return 0
            fi
            builtin command "$@"
            }

            brew() {
            echo "MOCK brew: $*"
            return 0
            }
            }

            Before 'setup'

              It 'filters out invalid package names'
                packages=$'git\n../bad\nneovim'
                When call install_homebrew_packages "${packages}" false

                The output should include 'MOCK brew: install git'
                The output should include 'MOCK brew: install neovim'
                The stderr should include 'Skipping invalid package name: ../bad'
                The stderr should include 'INVALID_PACKAGE'
                The status should be success
              End
            End
          End

          Describe 'install_cask_packages()'
            Context 'with valid packages'
      # shellcheck disable=SC2329  # ShellSpec setup function
              setup() {
              command() {
              if [[ "$1" = "-v" && "$2" = "brew" ]]; then
              return 0
              fi
              builtin command "$@"
              }

              brew() {
              echo "MOCK brew: $*"
              return 0
              }
              }

              Before 'setup'

                It 'installs each cask individually'
                  When call install_cask_packages $'wezterm\nraycast' false

                  The output should include 'MOCK brew: install --cask wezterm'
                  The output should include 'MOCK brew: install --cask raycast'
                  The status should be success
                End
              End

              Context 'in dry-run mode'
      # shellcheck disable=SC2329  # ShellSpec setup function
                setup() {
                command() {
                if [[ "$1" = "-v" && "$2" = "brew" ]]; then
                return 0
                fi
                builtin command "$@"
                }
                }

                Before 'setup'

                  It 'shows planned cask installation'
                    When call install_cask_packages $'wezterm\nraycast' true

                    The output should include 'install via cask: wezterm, raycast'
                    The status should be success
                  End
                End

                Context 'when brew is unavailable'
      # shellcheck disable=SC2329  # ShellSpec setup function
                  setup() {
                  command() {
                  if [[ "$1" = "-v" && "$2" = "brew" ]]; then
                  return 1
                  fi
                  builtin command "$@"
                  }
                  }

                  Before 'setup'

                    It 'logs a warning and skips installation'
                      When call install_cask_packages $'wezterm\nraycast' false

                      The output should include 'Warning: homebrew not found, skipping cask packages'
                      The status should be success
                    End
                  End

                  Context 'with invalid casks'
      # shellcheck disable=SC2329  # ShellSpec setup function
                    setup() {
                    command() {
                    if [[ "$1" = "-v" && "$2" = "brew" ]]; then
                    return 0
                    fi
                    builtin command "$@"
                    }

                    brew() {
                    echo "MOCK brew: $*"
                    return 0
                    }
                    }

                    Before 'setup'

                      It 'filters out invalid cask names'
                        packages=$'wezterm\n../bad\nraycast'
                        When call install_cask_packages "${packages}" false

                        The output should include 'MOCK brew: install --cask wezterm'
                        The output should include 'MOCK brew: install --cask raycast'
                        The stderr should include 'Skipping invalid package name: ../bad'
                        The stderr should include 'INVALID_PACKAGE'
                        The status should be success
                      End
                    End
                  End
                End
