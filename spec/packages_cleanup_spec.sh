#!/usr/bin/env bash

Describe 'Package cleanup functionality'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/platform.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  Describe 'extract_cleanup_packages_from_yaml()'
    It 'extracts pacman_cleanup packages for arch platform'
      When call extract_cleanup_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "vim"
      The output should include "alacritty"
      The lines of output should equal 2
      The status should be success
    End

    It 'extracts yay_cleanup packages for arch platform'
      When call extract_cleanup_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "alacritty-git"
      The lines of output should equal 1
      The status should be success
    End

    It 'extracts winget_cleanup packages for windows platform'
      When call extract_cleanup_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "Alacritty.Alacritty"
      The lines of output should equal 1
      The status should be success
    End

    It 'extracts scoop_cleanup packages for windows platform'
      When call extract_cleanup_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "alacritty"
      The lines of output should equal 1
      The status should be success
    End

    It 'extracts homebrew_cleanup packages for macos platform'
      When call extract_cleanup_packages_from_yaml "macos" "homebrew" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "vim"
      The lines of output should equal 1
      The status should be success
    End

    It 'extracts cask_cleanup packages for macos platform'
      When call extract_cleanup_packages_from_yaml "macos" "cask" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "alacritty"
      The lines of output should equal 1
      The status should be success
    End

    It 'returns empty when no cleanup section exists'
      When call extract_cleanup_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-basic.yaml"
      The output should equal ""
      The status should be success
    End

    It 'returns empty for non-existent platform'
      When call extract_cleanup_packages_from_yaml "unknown" "pacman" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should equal ""
      The status should be success
    End

    It 'validates platform name for security'
      When call extract_cleanup_packages_from_yaml "../etc/passwd" "pacman" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The status should be failure
      The stderr should include "INVALID_PLATFORM"
    End

    It 'validates manager name for security'
      When call extract_cleanup_packages_from_yaml "arch" "../etc/passwd" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The status should be failure
      The stderr should include "INVALID_MANAGER"
    End

    It 'extracts nixpkgs-25.05_cleanup packages for nix platform'
      When call extract_cleanup_packages_from_yaml "nix" "nixpkgs-25.05" "spec/fixtures/yaml/packages-with-cleanup.yaml"
      The output should include "vim"
      The output should include "emacs"
      The lines of output should equal 2
      The status should be success
    End
  End

  Describe 'remove_pacman_packages()'
    Context 'with valid packages'
      # shellcheck disable=SC2329
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

        It 'removes packages one by one'
          When call remove_pacman_packages $'vim\nalacritty' false

          The output should include 'MOCK pacman: -R --noconfirm vim'
          The output should include 'MOCK pacman: -R --noconfirm alacritty'
          The status should be success
        End
      End

      Context 'with some packages not installed'
      # shellcheck disable=SC2329
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
        case "$*" in
        "-Q vim")
        echo "vim 9.0.1-1"
        return 0
        ;;
        "-Q alacritty")
        # Package not installed
        return 1
        ;;
        "-Q nodejs")
        echo "nodejs 25.1.0-2"
        return 0
        ;;
        *)
        echo "MOCK pacman: $*"
        return 0
        ;;
        esac
        }
        }

        Before 'setup'

          It 'skips packages that are not installed'
            When call remove_pacman_packages $'vim\nalacritty\nnodejs' false

            The output should include 'MOCK pacman: -R --noconfirm vim'
            The output should not include 'MOCK pacman: -R --noconfirm alacritty'
            The output should include 'MOCK pacman: -R --noconfirm nodejs'
            The status should be success
          End
        End

        Context 'when package removal fails'
      # shellcheck disable=SC2329
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
          case "$*" in
          "-Q"*)
        # All packages are installed
          return 0
          ;;
          "-R --noconfirm vim")
        # Removal fails
          echo "error: failed to remove vim"
          return 1
          ;;
          *)
          echo "MOCK pacman: $*"
          return 0
          ;;
          esac
          }
          }

          Before 'setup'

            It 'continues removing other packages and reports failures'
              When call remove_pacman_packages $'vim\nalacritty' false

              The output should include 'MOCK pacman: -R --noconfirm alacritty'
              The output should include 'Failed to remove some pacman packages: vim'
              The status should be success
            End
          End
        End

        Context 'in dry-run mode'
      # shellcheck disable=SC2329
          setup() {
          command() {
          if [[ "$1" = "-v" && "$2" = "pacman" ]]; then
          return 0
          fi
          builtin command "$@"
          }
          }

          Before 'setup'

            It 'shows planned pacman removal'
              When call remove_pacman_packages $'vim\nalacritty' true

              The output should include 'remove via pacman: vim, alacritty'
              The status should be success
            End
          End

          Context 'when pacman is unavailable'
      # shellcheck disable=SC2329
            setup() {
            command() {
            if [[ "$1" = "-v" && "$2" = "pacman" ]]; then
            return 1
            fi
            builtin command "$@"
            }
            }

            Before 'setup'

              It 'logs a warning and skips removal'
                When call remove_pacman_packages $'vim\nalacritty' false

                The output should include 'Warning: pacman not found, skipping pacman package removal'
                The status should be success
              End
            End

            Context 'with invalid packages'
      # shellcheck disable=SC2329
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
                  packages=$'vim\n../bad\nalacritty'
                  When call remove_pacman_packages "${packages}" false

                  The output should include 'MOCK pacman: -R --noconfirm vim'
                  The output should include 'MOCK pacman: -R --noconfirm alacritty'
                  The stderr should include 'Skipping invalid package name: ../bad'
                  The stderr should include 'INVALID_PACKAGE'
                  The status should be success
                End
              End

              Describe 'remove_yay_packages()'
                Context 'with valid packages'
      # shellcheck disable=SC2329
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

                    It 'removes packages using yay -R'
                      When call remove_yay_packages $'alacritty-git\nsome-aur-pkg' false

                      The output should include 'MOCK yay: -R --noconfirm alacritty-git some-aur-pkg'
                      The status should be success
                    End
                  End

                  Context 'in dry-run mode'
      # shellcheck disable=SC2329
                    setup() {
                    command() {
                    if [[ "$1" = "-v" && "$2" = "yay" ]]; then
                    return 0
                    fi
                    builtin command "$@"
                    }
                    }

                    Before 'setup'

                      It 'shows planned yay removal'
                        When call remove_yay_packages $'alacritty-git' true

                        The output should include 'remove via yay: alacritty-git'
                        The status should be success
                      End
                    End
                  End

                  Describe 'remove_homebrew_packages()'
                    Context 'with valid packages'
      # shellcheck disable=SC2329
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

                        It 'removes packages using brew uninstall'
                          When call remove_homebrew_packages $'vim\nalacritty' false

                          The output should include 'MOCK brew: uninstall vim'
                          The output should include 'MOCK brew: uninstall alacritty'
                          The status should be success
                        End
                      End

                      Context 'in dry-run mode'
      # shellcheck disable=SC2329
                        setup() {
                        command() {
                        if [[ "$1" = "-v" && "$2" = "brew" ]]; then
                        return 0
                        fi
                        builtin command "$@"
                        }
                        }

                        Before 'setup'

                          It 'shows planned homebrew removal'
                            When call remove_homebrew_packages $'vim\nalacritty' true

                            The output should include 'remove via homebrew: vim, alacritty'
                            The status should be success
                          End
                        End
                      End

                      Describe 'remove_cask_packages()'
                        Context 'with valid packages'
      # shellcheck disable=SC2329
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

                            It 'removes packages using brew uninstall --cask'
                              When call remove_cask_packages $'alacritty\nraycast' false

                              The output should include 'MOCK brew: uninstall --cask alacritty'
                              The output should include 'MOCK brew: uninstall --cask raycast'
                              The status should be success
                            End
                          End

                          Context 'in dry-run mode'
      # shellcheck disable=SC2329
                            setup() {
                            command() {
                            if [[ "$1" = "-v" && "$2" = "brew" ]]; then
                            return 0
                            fi
                            builtin command "$@"
                            }
                            }

                            Before 'setup'

                              It 'shows planned cask removal'
                                When call remove_cask_packages $'alacritty\nraycast' true

                                The output should include 'remove via cask: alacritty, raycast'
                                The status should be success
                              End
                            End
                          End

                          Describe 'remove_opkg_packages()'
                            Context 'with valid packages'
      # shellcheck disable=SC2329
                              setup() {
                              command() {
                              if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
                              return 0
                              fi
                              builtin command "$@"
                              }

                              opkg() {
                              echo "MOCK opkg: $*"
                              return 0
                              }
                              }

                              Before 'setup'

                                It 'removes packages using opkg remove'
                                  When call remove_opkg_packages $'vim\nalacritty' false

                                  The output should include 'MOCK opkg: remove vim alacritty'
                                  The status should be success
                                End
                              End

                              Context 'in dry-run mode'
      # shellcheck disable=SC2329
                                setup() {
                                command() {
                                if [[ "$1" = "-v" && "$2" = "opkg" ]]; then
                                return 0
                                fi
                                builtin command "$@"
                                }
                                }

                                Before 'setup'

                                  It 'shows planned opkg removal'
                                    When call remove_opkg_packages $'vim\nalacritty' true

                                    The output should include 'remove via opkg: vim, alacritty'
                                    The status should be success
                                  End
                                End
                              End

                              Describe 'remove_nix_packages()'
                                Context 'with valid packages'
      # shellcheck disable=SC2329
                                  setup() {
                                  command() {
                                  if [[ "$1" = "-v" && "$2" = "nix" ]]; then
                                  return 0
                                  fi
                                  builtin command "$@"
                                  }

                                  nix() {
                                  echo "MOCK nix: $*"
                                  return 0
                                  }
                                  }

                                  Before 'setup'

                                    It 'removes packages using nix profile remove'
                                      When call remove_nix_packages $'vim\nemacs' "25.05" false

                                      The output should include 'MOCK nix: profile remove'
                                      The status should be success
                                    End
                                  End

                                  Context 'in dry-run mode'
      # shellcheck disable=SC2329
                                    setup() {
                                    command() {
                                    if [[ "$1" = "-v" && "$2" = "nix" ]]; then
                                    return 0
                                    fi
                                    builtin command "$@"
                                    }
                                    }

                                    Before 'setup'

                                      It 'shows planned nix removal'
                                        When call remove_nix_packages $'vim\nemacs' "25.05" true

                                        The output should include 'remove via nixpkgs-25.05: vim, emacs'
                                        The status should be success
                                      End
                                    End

                                    Context 'when nix is unavailable'
      # shellcheck disable=SC2329
                                      setup() {
                                      command() {
                                      if [[ "$1" = "-v" && "$2" = "nix" ]]; then
                                      return 1
                                      fi
                                      builtin command "$@"
                                      }
                                      }

                                      Before 'setup'

                                        It 'logs a warning and skips removal'
                                          When call remove_nix_packages $'vim\nemacs' "25.05" false

                                          The output should include 'Warning: nix not found, skipping nix package removal'
                                          The status should be success
                                        End
                                      End

                                      Context 'with invalid packages'
      # shellcheck disable=SC2329
                                        setup() {
                                        command() {
                                        if [[ "$1" = "-v" && "$2" = "nix" ]]; then
                                        return 0
                                        fi
                                        builtin command "$@"
                                        }

                                        nix() {
                                        echo "MOCK nix: $*"
                                        return 0
                                        }
                                        }

                                        Before 'setup'

                                          It 'filters out invalid package names'
                                            packages=$'vim\n../bad\nemacs'
                                            When call remove_nix_packages "${packages}" "25.05" false

                                            The output should include 'MOCK nix: profile remove'
                                            The stderr should include 'Skipping invalid package name: ../bad'
                                            The stderr should include 'INVALID_PACKAGE'
                                            The status should be success
                                          End
                                        End
                                      End
                                    End

                                  Describe 'Integration: cleanup for all platforms'
                                    It 'calls opkg cleanup for freshtomato platform'
      # Mock functions
                                      remove_opkg_packages() { echo "MOCK: remove_opkg_packages called with: $1"; }
                                      install_opkg_packages() { echo "MOCK: install_opkg_packages called"; }

                                      When call handle_packages_from_file "freshtomato" true "spec/fixtures/yaml/packages-with-cleanup.yaml" "TEST"
                                      The output should include 'MOCK: remove_opkg_packages called'
                                      The status should be success
                                    End

                                    It 'calls nix cleanup for nix platform'
      # Mock functions
                                      remove_nix_packages() { echo "MOCK: remove_nix_packages called with version: $2, packages: $1"; }
                                      install_nix_packages() { echo "MOCK: install_nix_packages called"; }

                                      When call handle_packages_from_file "nix" true "spec/fixtures/yaml/packages-with-cleanup.yaml" "TEST"
                                      The output should include 'MOCK: remove_nix_packages called with version: 25.05'
                                      The status should be success
                                    End
                                  End
