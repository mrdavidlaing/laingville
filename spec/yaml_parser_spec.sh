#!/usr/bin/env bash

# Comprehensive YAML parser tests for bash implementation
# These tests mirror the PowerShell test suite to ensure parity
# Tests use shared fixtures in spec/fixtures/yaml/

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe "YAML Parser (bash implementation)"
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/platform.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  # Helper to count lines of output
  count_lines() {
  wc -l | tr -d ' '
  }

  Describe "extract_packages_from_yaml - basic list format"

    It "extracts arch/pacman packages from basic format"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
      The line 3 of output should equal "tmux"
    End

    It "extracts arch/yay packages from basic format"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "starship"
      The output should include "yay"
      The line 1 of output should equal "starship"
      The line 2 of output should equal "yay"
    End

    It "extracts windows/winget packages from basic format"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The output should include "Microsoft.VisualStudioCode"
      The line 1 of output should equal "Git.Git"
    End

    It "extracts windows/scoop packages from basic format"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "git"
      The output should include "versions/wezterm-nightly"
      The line 1 of output should equal "git"
      The line 2 of output should equal "versions/wezterm-nightly"
    End

    It "extracts windows/psmodule packages from basic format"
      When call extract_packages_from_yaml "windows" "psmodule" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "PowerShellGet"
      The output should include "Pester"
      The line 1 of output should equal "PowerShellGet"
      The line 2 of output should equal "Pester"
    End

    It "extracts macos/homebrew packages from basic format"
      When call extract_packages_from_yaml "macos" "homebrew" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "git"
      The output should include "starship"
      The output should include "ripgrep"
      The line 1 of output should equal "git"
    End

    It "extracts macos/cask packages from basic format"
      When call extract_packages_from_yaml "macos" "cask" "spec/fixtures/yaml/packages-basic.yaml"
      The output should include "visual-studio-code"
      The output should include "docker"
      The line 1 of output should equal "visual-studio-code"
      The line 2 of output should equal "docker"
    End

  End

  Describe "extract_packages_from_yaml - comments handling"

    It "strips inline comments from package names"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-comments.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The output should not include "#"
      The output should not include "Distributed version control"
      The line 1 of output should equal "git"
    End

    It "ignores comment-only lines"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-comments.yaml"
      The output should include "starship"
      The output should include "yay"
      The output should not include "# AUR packages"
      The output should not include "Cross-shell prompt"
      The line 1 of output should equal "starship"
    End

    It "handles inline comments after package names in windows section"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-comments.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The output should include "Microsoft.VisualStudioCode"
      The output should not include "Version control system"
      The output should not include "PowerShell 7+"
      The line 1 of output should equal "Git.Git"
    End

    It "handles standalone comments between packages"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-comments.yaml"
      The output should include "versions/wezterm-nightly"
      The output should not include "# Terminal emulators"
      The line 1 of output should equal "versions/wezterm-nightly"
    End

  End

  Describe "extract_packages_from_yaml - quoted strings"

    It "strips double quotes from package names"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-quotes.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The output should not include '"'
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
      The line 3 of output should equal "tmux"
    End

    It "strips single quotes from package names"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-quotes.yaml"
      The output should include "starship"
      The output should include "yay"
      The output should not include "'"
      The line 1 of output should equal "starship"
      The line 2 of output should equal "yay"
    End

    It "handles mix of quoted and unquoted packages (windows)"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-quotes.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The output should include "Microsoft.VisualStudioCode"
      The line 1 of output should equal "Git.Git"
      The line 2 of output should equal "Microsoft.PowerShell"
      The line 3 of output should equal "Microsoft.VisualStudioCode"
    End

    It "handles scoop packages with buckets (quoted)"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-quotes.yaml"
      The output should include "git"
      The output should include "versions/wezterm-nightly"
      The line 1 of output should equal "git"
      The line 2 of output should equal "versions/wezterm-nightly"
    End

  End

  Describe "extract_packages_from_yaml - mixed formats"

    It "handles quotes + comments + varying whitespace (arch)"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-mixed.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The output should include "bash"
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
      The line 3 of output should equal "tmux"
      The line 4 of output should equal "bash"
    End

    It "handles mixed formatting in windows packages"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-mixed.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The output should include "Microsoft.VisualStudioCode"
      The line 1 of output should equal "Git.Git"
      The line 2 of output should equal "Microsoft.PowerShell"
      The line 3 of output should equal "Microsoft.VisualStudioCode"
    End

    It "handles mixed formatting in scoop packages"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-mixed.yaml"
      The output should include "git"
      The output should include "versions/wezterm-nightly"
      The line 1 of output should equal "git"
      The line 2 of output should equal "versions/wezterm-nightly"
    End

  End

  Describe "extract_packages_from_yaml - empty sections"

    It "returns empty output for empty arch/pacman section"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-empty.yaml"
      The output should equal ""
      The status should be success
    End

    It "returns empty output for empty windows/winget section"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-empty.yaml"
      The output should equal ""
      The status should be success
    End

    It "returns empty output for empty windows/psmodule section"
      When call extract_packages_from_yaml "windows" "psmodule" "spec/fixtures/yaml/packages-empty.yaml"
      The output should equal ""
      The status should be success
    End

    It "extracts packages from non-empty section despite other empty sections"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-empty.yaml"
      The output should include "starship"
      The line 1 of output should equal "starship"
    End

    It "extracts packages from windows/scoop despite other empty sections"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-empty.yaml"
      The output should include "git"
      The line 1 of output should equal "git"
    End

  End

  Describe "extract_packages_from_yaml - missing platforms"

    It "returns empty output for non-existent platform (wsl)"
      When call extract_packages_from_yaml "wsl" "pacman" "spec/fixtures/yaml/packages-missing-platform.yaml"
      The output should equal ""
      The status should be success
    End

    It "returns empty output for non-existent platform (windows)"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-missing-platform.yaml"
      The output should equal ""
      The status should be success
    End

    It "extracts packages from existing platform (arch) when others missing"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-missing-platform.yaml"
      The output should include "git"
      The output should include "vim"
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
    End

    It "extracts packages from existing arch/yay when others missing"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-missing-platform.yaml"
      The output should include "starship"
      The line 1 of output should equal "starship"
    End

    It "returns empty for missing manager within existing platform"
      When call extract_packages_from_yaml "macos" "cask" "spec/fixtures/yaml/packages-missing-platform.yaml"
      The output should equal ""
      The status should be success
    End

  End

  Describe "extract_packages_from_yaml - error handling"

    It "returns error for non-existent file"
      When call extract_packages_from_yaml "arch" "pacman" "/nonexistent/packages.yaml"
      The status should be failure
      The output should equal ""
      The stderr should not equal ""
    End

    It "returns error for invalid platform key (contains special chars)"
      When call extract_packages_from_yaml "arch;rm -rf" "pacman" "spec/fixtures/yaml/packages-basic.yaml"
      The status should be failure
      The stderr should include "INVALID_PLATFORM"
    End

    It "returns error for invalid manager key (contains special chars)"
      When call extract_packages_from_yaml "arch" "pacman;rm -rf" "spec/fixtures/yaml/packages-basic.yaml"
      The status should be failure
      The stderr should include "INVALID_MANAGER"
    End

    It "handles file with no packages gracefully"
      temp_file=$(mktemp)
      echo "# Empty YAML file" > "${temp_file}"

      When call extract_packages_from_yaml "arch" "pacman" "${temp_file}"
      The output should equal ""
      The status should be success

      rm -f "${temp_file}"
    End

  End

  Describe "extract_packages_from_yaml - real world configs"

    It "extracts packages from real mrdavidlaing config (arch)"
      Skip if "mrdavidlaing config not present" test ! -f "dotfiles/mrdavidlaing/packages.yaml"

      When call extract_packages_from_yaml "arch" "yay" "dotfiles/mrdavidlaing/packages.yaml"
      The output should not be blank
      The output should include "starship"
    End

    It "extracts packages from real mrdavidlaing config (macos)"
      Skip if "mrdavidlaing config not present" test ! -f "dotfiles/mrdavidlaing/packages.yaml"

      When call extract_packages_from_yaml "macos" "homebrew" "dotfiles/mrdavidlaing/packages.yaml"
      The output should not be blank
      The output should include "git"
      The output should include "starship"
      The output should include "ripgrep"
    End

  End

  Describe "extract_packages_from_yaml - flexible indentation"

    It "handles 2-space indentation (standard)"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-flexible-indent.yaml"
      The output should include "git"
      The output should include "vim"
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
    End

    It "handles 4-space indentation"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-flexible-indent.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The line 1 of output should equal "Git.Git"
      The line 2 of output should equal "Microsoft.PowerShell"
    End

    It "handles 3-space indentation (unusual but valid)"
      When call extract_packages_from_yaml "macos" "homebrew" "spec/fixtures/yaml/packages-flexible-indent.yaml"
      The output should include "git"
      The output should include "starship"
      The line 1 of output should equal "git"
      The line 2 of output should equal "starship"
    End

    It "handles 4-space indentation for scoop"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-flexible-indent.yaml"
      The output should include "git"
      The output should include "versions/wezterm-nightly"
      The line 1 of output should equal "git"
      The line 2 of output should equal "versions/wezterm-nightly"
    End

  End

  Describe "extract_packages_from_yaml - inline array format"

    It "extracts packages from inline array (windows/winget)"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-inline-array.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The line 1 of output should equal "Git.Git"
      The line 2 of output should equal "Microsoft.PowerShell"
    End

    It "extracts packages from inline array (windows/scoop)"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-inline-array.yaml"
      The output should include "git"
      The output should include "versions/wezterm-nightly"
      The line 1 of output should equal "git"
      The line 2 of output should equal "versions/wezterm-nightly"
    End

    It "extracts packages from inline array (windows/psmodule)"
      When call extract_packages_from_yaml "windows" "psmodule" "spec/fixtures/yaml/packages-inline-array.yaml"
      The output should include "PowerShellGet"
      The output should include "Pester"
      The line 1 of output should equal "PowerShellGet"
      The line 2 of output should equal "Pester"
    End

    It "extracts packages from inline array (arch/pacman)"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-inline-array.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
      The line 3 of output should equal "tmux"
    End

    It "extracts packages from inline array (arch/yay)"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-inline-array.yaml"
      The output should include "starship"
      The output should include "yay"
      The line 1 of output should equal "starship"
      The line 2 of output should equal "yay"
    End

  End

End
