#!/usr/bin/env bash

# Critical edge case tests for YAML parser
# Tests security and correctness issues that could cause silent failures

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe "YAML Parser - Critical Edge Cases"
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/platform.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/packages.functions.bash

  Describe "package names with colons"

    It "preserves package names containing colons (arch/pacman)"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-edge-cases.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "package-with-colons:v1.2.3:release"
      The output should include "tmux"
      The line 3 of output should equal "package-with-colons:v1.2.3:release"
    End

    It "preserves package names with colons in quotes (windows/psmodule)"
      When call extract_packages_from_yaml "windows" "psmodule" "spec/fixtures/yaml/packages-edge-cases.yaml"
      The output should include "PowerShellGet"
      The output should include "Module:With:Colons"
      The line 2 of output should equal "Module:With:Colons"
    End

  End

  Describe "package names with hash symbols"

    It "preserves hash symbols in package names (arch/yay)"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-edge-cases.yaml"
      The output should include "starship"
      The output should include "package#with#hashes"
      The output should include "yay"
      The line 2 of output should equal "package#with#hashes"
    End

    It "preserves hash in quoted package names (windows/winget)"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-edge-cases.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The output should include "Package.With#Hash"
      The line 3 of output should equal "Package.With#Hash"
    End

    It "preserves hash in middle of unquoted package name (macos/homebrew)"
      When call extract_packages_from_yaml "macos" "homebrew" "spec/fixtures/yaml/packages-edge-cases.yaml"
      The output should include "git"
      The output should include "package-with-#-hash"
      The output should include "ripgrep"
      The line 2 of output should equal "package-with-#-hash"
    End

  End

  Describe "quoted strings with comment-like content"

    It "preserves content inside quotes even if it looks like a comment"
      When call extract_packages_from_yaml "windows" "scoop" "spec/fixtures/yaml/packages-edge-cases.yaml"
      The output should include "git"
      The output should include "git # this looks like a comment"
      The line 2 of output should equal "git # this looks like a comment"
    End

  End

  Describe "tabs mixed with spaces in indentation"

    It "handles tabs mixed with spaces (arch/pacman)"
      When call extract_packages_from_yaml "arch" "pacman" "spec/fixtures/yaml/packages-tabs.yaml"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The lines of output should equal 3
    End

    It "handles tabs mixed with spaces (arch/yay)"
      When call extract_packages_from_yaml "arch" "yay" "spec/fixtures/yaml/packages-tabs.yaml"
      The output should include "starship"
      The output should include "yay"
      The lines of output should equal 2
    End

    It "handles tabs mixed with spaces (windows/winget)"
      When call extract_packages_from_yaml "windows" "winget" "spec/fixtures/yaml/packages-tabs.yaml"
      The output should include "Git.Git"
      The output should include "Microsoft.PowerShell"
      The lines of output should equal 2
    End

  End

  Describe "excessive whitespace handling"

    It "strips excessive leading and trailing whitespace from package names"
      temp_file=$(mktemp)
      cat > "${temp_file}" << 'EOF'
arch:
  pacman:
    -       git
    -   vim
    -tmux
EOF

      When call extract_packages_from_yaml "arch" "pacman" "${temp_file}"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The line 1 of output should equal "git"
      The line 2 of output should equal "vim"
      The line 3 of output should equal "tmux"

      rm -f "${temp_file}"
    End

  End

  Describe "max package limit (100 packages)"

    It "stops at 100 packages and truncates silently"
      temp_file=$(mktemp)
      echo "arch:" > "${temp_file}"
      echo "  pacman:" >> "${temp_file}"

      # Generate 105 packages
      for i in $(seq 1 105); do
      echo "    - package${i}" >> "${temp_file}"
      done

      result=$(extract_packages_from_yaml "arch" "pacman" "${temp_file}")
      count=$(echo "${result}" | wc -l | tr -d ' ')

      When call echo "${count}"
      The output should equal "100"

      rm -f "${temp_file}"
    End

  End

  Describe "empty list items"

    It "skips empty list items gracefully"
      temp_file=$(mktemp)
      cat > "${temp_file}" << 'EOF'
arch:
  pacman:
    - git
    -
    - vim
    -
    - tmux
EOF

      When call extract_packages_from_yaml "arch" "pacman" "${temp_file}"
      The output should include "git"
      The output should include "vim"
      The output should include "tmux"
      The lines of output should equal 3

      rm -f "${temp_file}"
    End

  End

  Describe "uppercase platform and manager names"

    It "does not match uppercase platform names (returns empty)"
      temp_file=$(mktemp)
      cat > "${temp_file}" << 'EOF'
Arch:
  pacman:
    - git
    - vim
EOF

      When call extract_packages_from_yaml "Arch" "pacman" "${temp_file}"
      The output should equal ""
      The status should be success

      rm -f "${temp_file}"
    End

    It "does not match uppercase manager names (returns empty)"
      temp_file=$(mktemp)
      cat > "${temp_file}" << 'EOF'
arch:
  Pacman:
    - git
    - vim
EOF

      When call extract_packages_from_yaml "arch" "Pacman" "${temp_file}"
      The output should equal ""
      The status should be success

      rm -f "${temp_file}"
    End

  End

  Describe "very long package names"

    It "handles package names with 1000+ characters"
      temp_file=$(mktemp)
      # Create a package name with 1500 characters
      long_name=$(printf 'a%.0s' {1..1500})

      cat > "${temp_file}" << EOF
arch:
  pacman:
    - git
    - ${long_name}
    - vim
EOF

      When call extract_packages_from_yaml "arch" "pacman" "${temp_file}"
      The output should include "git"
      The output should include "${long_name}"
      The output should include "vim"
      The lines of output should equal 3

      rm -f "${temp_file}"
    End

  End

  Describe "unicode and special characters"

    It "handles unicode characters in package names"
      temp_file=$(mktemp)
      cat > "${temp_file}" << 'EOF'
arch:
  pacman:
    - git
    - café
    - 日本語
    - vim
EOF

      When call extract_packages_from_yaml "arch" "pacman" "${temp_file}"
      The output should include "git"
      The output should include "café"
      The output should include "日本語"
      The output should include "vim"
      The lines of output should equal 4

      rm -f "${temp_file}"
    End

  End

End
