#!/usr/bin/env bash

Describe "symlinks configuration in symlinks.yaml"
Include lib/shared.functions.bash
Include lib/setup-user.functions.bash
Include lib/symlinks.functions.bash

# Create a test symlinks.yaml with symlinks configuration
setup_test_config() {
  local test_dir="${1}"
  cat > "${test_dir}/symlinks.yaml" << 'EOF'
arch:
  - .bashrc
  - .config/tmux
  - .config/nvim

wsl:
  - .bashrc
  - .config/tmux
  # Simple string format
  - .gitconfig

windows:
  # Object format with custom target
  - source: .config/alacritty/alacritty.toml
    target: ${APPDATA}/alacritty/alacritty.toml
  - source: .config/alacritty/themes
    target: ${APPDATA}/alacritty/themes
  # Mixed formats in same list
  - .gitconfig
  - source: .config/1Password/settings
    target: $LOCALAPPDATA/1Password/settings

macos:
  - .bashrc
  - .config/tmux
  - source: .config/aerospace
    target: ${HOME}/.aerospace
EOF
}

Describe "parse_symlinks_from_yaml"
It "extracts simple string symlinks for arch platform"
temp_dir=$(mktemp -d)
setup_test_config "${temp_dir}"

When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "arch"
The output should include ".bashrc"
The output should include ".config/tmux"
The output should include ".config/nvim"
The lines of output should equal 3

rm -rf "${temp_dir}"
End

It "extracts symlinks for wsl platform"
temp_dir=$(mktemp -d)
setup_test_config "${temp_dir}"

When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "wsl"
The output should include ".bashrc"
The output should include ".config/tmux"
The output should include ".gitconfig"
The lines of output should equal 3

rm -rf "${temp_dir}"
End

It "handles mixed format symlinks for windows platform"
temp_dir=$(mktemp -d)
setup_test_config "${temp_dir}"

When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "windows"
# Should output in format: source|target (pipe-separated, env vars NOT expanded)
The output should include ".config/alacritty/alacritty.toml|\${APPDATA}/alacritty/alacritty.toml"
The output should include ".config/alacritty/themes|\${APPDATA}/alacritty/themes"
The output should include ".gitconfig|" # No custom target
The output should include ".config/1Password/settings|\$LOCALAPPDATA/1Password/settings"
The lines of output should equal 4

rm -rf "${temp_dir}"
End

It "handles custom targets for macos platform"
temp_dir=$(mktemp -d)
setup_test_config "${temp_dir}"

When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "macos"
The output should include ".bashrc|"
The output should include ".config/tmux|"
The output should include ".config/aerospace|\${HOME}/.aerospace"
The lines of output should equal 3

rm -rf "${temp_dir}"
End

It "returns empty for non-existent platform"
temp_dir=$(mktemp -d)
setup_test_config "${temp_dir}"

When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "unknown"
The output should equal ""

rm -rf "${temp_dir}"
End

It "handles missing symlinks section gracefully"
temp_dir=$(mktemp -d)
cat > "${temp_dir}/symlinks.yaml" << 'EOF'
# File with no symlinks for arch platform
macos:
  - .bashrc
EOF

When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "arch"
The output should equal ""

rm -rf "${temp_dir}"
End

It "handles missing symlinks.yaml file"
When call parse_symlinks_from_yaml "/nonexistent/symlinks.yaml" "arch"
The status should be failure
The output should equal ""
End
End

Describe "process_symlink_entry"
It "processes simple string entry"
When call process_symlink_entry ".bashrc"
The output should equal ".bashrc|"
End

It "processes object with custom target"
When call process_symlink_entry "source:.config/alacritty target:${APPDATA}/alacritty"
The output should equal ".config/alacritty|${APPDATA}/alacritty"
End

It "expands environment variables in target"
export TEST_VAR="/test/path"
When call process_symlink_entry "source:.config/test target:${TEST_VAR}/config"
The output should equal ".config/test|/test/path/config"
unset TEST_VAR
End

It "handles Windows environment variables"
export APPDATA="C:/Users/Test/AppData/Roaming"
When call process_symlink_entry "source:.config/alacritty target:${APPDATA}/alacritty"
The output should equal ".config/alacritty|C:/Users/Test/AppData/Roaming/alacritty"
unset APPDATA
End
End

Describe "create_symlink_with_target"
It "creates symlink with default target"
temp_dir=$(mktemp -d)
mkdir -p "${temp_dir}/dotfiles/.config"
echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"

When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "" "${temp_dir}/home" true
The status should be success
The output should include "Would: create: ${temp_dir}/home/.config/test.conf"

rm -rf "${temp_dir}"
End

It "creates symlink with custom target"
temp_dir=$(mktemp -d)
mkdir -p "${temp_dir}/dotfiles/.config"
echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"
mkdir -p "${temp_dir}/custom"

When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "${temp_dir}/custom/test.conf" "${temp_dir}/home" true
The status should be success
The output should include "Would: create: ${temp_dir}/custom/test.conf"

rm -rf "${temp_dir}"
End

It "handles APPDATA variable substitution"
temp_dir=$(mktemp -d)
mkdir -p "${temp_dir}/dotfiles/.config/alacritty"
echo "test content" > "${temp_dir}/dotfiles/.config/alacritty/alacritty.toml"
export APPDATA="${temp_dir}/AppData/Roaming"
mkdir -p "${APPDATA}"

When call create_symlink_with_target "${temp_dir}/dotfiles/.config/alacritty/alacritty.toml" "\${APPDATA}/alacritty/alacritty.toml" "${temp_dir}/home" true
The status should be success
The output should include "Would: create: ${temp_dir}/AppData/Roaming/alacritty/alacritty.toml"

unset APPDATA
rm -rf "${temp_dir}"
End
End
End
