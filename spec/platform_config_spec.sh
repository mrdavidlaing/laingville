#!/usr/bin/env bash

Describe 'get_platform_config_path function'
Include lib/polyfill.functions.bash
Include lib/logging.functions.bash
Include lib/security.functions.bash
Include lib/shared.functions.bash
Include lib/setup-user.functions.bash

Describe 'on Linux/WSL without Windows environment'
BeforeEach 'unset WINDIR APPDATA LOCALAPPDATA'

It 'returns standard Unix path for alacritty config'
When call get_platform_config_path ".config/alacritty/" "alacritty.toml"
The output should equal "${HOME}/.config/alacritty/alacritty.toml"
End

It 'returns standard Unix path for alacritty themes'
When call get_platform_config_path ".config/alacritty/themes/" "solarized_dark.toml"
The output should equal "${HOME}/.config/alacritty/themes/solarized_dark.toml"
End

It 'returns standard Unix path for nested alacritty directories'
When call get_platform_config_path ".config/alacritty/foo/bar/" "config.toml"
The output should equal "${HOME}/.config/alacritty/foo/bar/config.toml"
End

It 'returns standard Unix path for 1Password config'
When call get_platform_config_path ".config/1Password/settings/" "settings.json"
The output should equal "${HOME}/.config/1Password/settings/settings.json"
End

It 'returns standard Unix path for other configs'
When call get_platform_config_path ".config/starship/" "starship.toml"
The output should equal "${HOME}/.config/starship/starship.toml"
End
End

Describe 'on Windows (Git Bash/MSYS)'
BeforeEach 'setup_windows_env'
AfterEach 'cleanup_windows_env'

# shellcheck disable=SC2329  # Mock function for testing
setup_windows_env() {
  export WINDIR="/mnt/c/Windows"
  export APPDATA="/mnt/c/Users/TestUser/AppData/Roaming"
  export LOCALAPPDATA="/mnt/c/Users/TestUser/AppData/Local"
  # Create mock mkdir function that doesn't actually create directories
  # shellcheck disable=SC2329  # Mock function for testing
  mkdir() {
    return 0
  }
}

# shellcheck disable=SC2329  # Mock function for testing
cleanup_windows_env() {
  unset WINDIR APPDATA LOCALAPPDATA
  unset -f mkdir
}

It 'maps alacritty root config to APPDATA'
When call get_platform_config_path ".config/alacritty/" "alacritty.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/alacritty.toml"
End

It 'preserves themes subdirectory for alacritty'
When call get_platform_config_path ".config/alacritty/themes/" "solarized_dark.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/themes/solarized_dark.toml"
End

It 'preserves themes subdirectory for another theme'
When call get_platform_config_path ".config/alacritty/themes/" "nord.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/themes/nord.toml"
End

It 'preserves nested directory structure for alacritty'
When call get_platform_config_path ".config/alacritty/foo/bar/baz/" "config.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/foo/bar/baz/config.toml"
End

It 'maps 1Password config to LOCALAPPDATA'
When call get_platform_config_path ".config/1Password/settings/" "settings.json"
The output should equal "/mnt/c/Users/TestUser/AppData/Local/1Password/settings.json"
End

It 'returns standard Unix path for non-mapped configs'
When call get_platform_config_path ".config/starship/" "starship.toml"
The output should equal "${HOME}/.config/starship/starship.toml"
End

It 'handles Windows paths with backslashes in APPDATA'
export APPDATA='C:\Users\TestUser\AppData\Roaming'
When call get_platform_config_path ".config/alacritty/themes/" "dark.toml"
The output should equal "C:/Users/TestUser/AppData/Roaming/alacritty/themes/dark.toml"
End
End

Describe 'edge cases'
BeforeEach 'setup_windows_env'
AfterEach 'cleanup_windows_env'

# shellcheck disable=SC2329  # Mock function for testing
setup_windows_env() {
  export WINDIR="/mnt/c/Windows"
  export APPDATA="/mnt/c/Users/TestUser/AppData/Roaming"
  # shellcheck disable=SC2329  # Mock function for testing
  mkdir() { return 0; }
}

# shellcheck disable=SC2329  # Mock function for testing
cleanup_windows_env() {
  unset WINDIR APPDATA
  unset -f mkdir
}

It 'handles empty filename'
When call get_platform_config_path ".config/alacritty/" ""
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/"
End

It 'handles path without trailing slash'
When call get_platform_config_path ".config/alacritty" "test.toml"
The output should equal "${HOME}/.config/alacrittytest.toml"
End

It 'handles deep nesting correctly'
When call get_platform_config_path ".config/alacritty/a/b/c/d/e/" "file.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/a/b/c/d/e/file.toml"
End
End

Describe 'directory creation behavior'
BeforeEach 'setup_tracking'
AfterEach 'cleanup_tracking'

setup_tracking() {
  export WINDIR="/mnt/c/Windows"
  export APPDATA="/mnt/c/Users/TestUser/AppData/Roaming"
  export MKDIR_CALLS=""

  # Track mkdir calls
  # shellcheck disable=SC2329  # Mock function for testing
  mkdir() {
    MKDIR_CALLS="${MKDIR_CALLS}|${*}"
    return 0
  }
}

cleanup_tracking() {
  unset WINDIR APPDATA MKDIR_CALLS
  unset -f mkdir
}

It 'creates parent directory for themes'
When call get_platform_config_path ".config/alacritty/themes/" "solarized.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/themes/solarized.toml"
The variable MKDIR_CALLS should include "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/themes"
End

It 'creates nested directories'
When call get_platform_config_path ".config/alacritty/foo/bar/" "test.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/foo/bar/test.toml"
The variable MKDIR_CALLS should include "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/foo/bar"
End

It 'only creates base directory for root level files'
When call get_platform_config_path ".config/alacritty/" "alacritty.toml"
The output should equal "/mnt/c/Users/TestUser/AppData/Roaming/alacritty/alacritty.toml"
The variable MKDIR_CALLS should include "/mnt/c/Users/TestUser/AppData/Roaming/alacritty"
The variable MKDIR_CALLS should not include "themes"
End
End
End
