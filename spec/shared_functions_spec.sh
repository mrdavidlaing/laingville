Describe "shared.functions.bash"
  Before "cd '$SHELLSPEC_PROJECT_ROOT'"
  Before "source ./lib/polyfill.functions.bash"
  Before "source ./lib/logging.functions.bash"
  Before "source ./lib/security.functions.bash"
  Before "source ./lib/shared.functions.bash"

  Describe "detect_platform function"
    It "returns macos on Darwin"
      # Mock OSTYPE for macOS
      export OSTYPE="darwin21.6.0"
      
      When call detect_platform
      
      The output should equal "macos"
    End

    It "prioritizes darwin over pacman"
      # Even if pacman exists, should return macos on Darwin
      export OSTYPE="darwin21.6.0"
      # Create fake pacman in PATH
      temp_dir=$(mktemp -d)
      echo '#!/bin/bash' > "$temp_dir/pacman"
      chmod +x "$temp_dir/pacman"
      export PATH="$temp_dir:$PATH"
      
      When call detect_platform
      
      The output should equal "macos"
      
      rm -rf "$temp_dir"
    End
  End

  Describe "get_packages_from_file function"
    It "extracts packages from real config"
      export DOTFILES_DIR="$(cd "$SHELLSPEC_PROJECT_ROOT/dotfiles/mrdavidlaing" && pwd)"
      
      When call get_packages_from_file "arch" "yay" "$DOTFILES_DIR/packages.yml"
      
      The output should not be blank
      The output should include "hyprland"
    End

    It "extracts macOS packages from real config"
      export DOTFILES_DIR="$(cd "$SHELLSPEC_PROJECT_ROOT/dotfiles/mrdavidlaing" && pwd)"
      
      # Test homebrew packages
      When call get_packages_from_file "macos" "homebrew" "$DOTFILES_DIR/packages.yml"
      
      The output should not be blank
      The output should include "git"
      The output should include "starship"
      The output should include "ripgrep"
    End

    It "extracts cask packages from real config"
      export DOTFILES_DIR="$(cd "$SHELLSPEC_PROJECT_ROOT/dotfiles/mrdavidlaing" && pwd)"
      
      When call get_packages_from_file "macos" "cask" "$DOTFILES_DIR/packages.yml"
      
      The output should not be blank
      The output should include "alacritty"
      The output should include "claude"
      The output should include "font-jetbrains-mono-nerd-font"
    End
  End

  Describe "server packages.yml parsing"
    It "extracts packages correctly"
      temp_dir=$(mktemp -d)
      server_dir="$temp_dir/servers/testhost"
      mkdir -p "$server_dir"
      cat > "$server_dir/packages.yml" << 'EOF'
arch:
  pacman:
    - k3s
    - htop
    - curl
  aur:
    - some-aur-package

windows:
  winget:
    - SomeApp
EOF
      
      When call get_packages_from_file "arch" "pacman" "$server_dir/packages.yml"
      
      The output should include "k3s"
      The output should include "htop"
      
      rm -rf "$temp_dir"
    End
  End

  Describe "validate_script_name function"
    It "accepts valid names"
      When call validate_script_name valid_name
      
      The status should be success
    End

    It "rejects invalid characters"
      When call validate_script_name "bad_name!"
      
      The status should not be success
      The stderr should include "Invalid script name contains illegal characters"
    End

    It "rejects path traversal"
      When call validate_script_name "../evil"
      
      The status should not be success
      The stderr should include "Invalid script name contains illegal characters"
    End

    It "rejects too long names"
      longname=$(printf 'a%.0s' {1..60})
      
      When call validate_script_name "$longname"
      
      The status should not be success
      The stderr should include "Script name too long"
    End
  End
End