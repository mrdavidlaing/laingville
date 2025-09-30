#!/usr/bin/env bash

# ShellSpec framework functions trigger SC2218 false positives
# shellcheck disable=SC2218

Describe "Symlinks cleanup functionality"
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/platform.functions.bash
  Include lib/packages.functions.bash
  Include lib/shared.functions.bash
  Include lib/setup-user.functions.bash
  Include lib/symlinks.functions.bash

  # Cleanup temp directories after each test
  AfterEach 'cleanup_temp_dir'
  
  cleanup_temp_dir() {
  if [[ -n "${temp_dir:-}" && -d "${temp_dir}" ]]; then
  rm -rf "${temp_dir}"
  unset temp_dir
  fi
  }

  Describe "parse_cleanup_symlinks_from_yaml"
    It "extracts cleanup symlinks for arch platform"
      When call parse_cleanup_symlinks_from_yaml "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "arch"
      The output should include ".config/alacritty"
      The output should include ".config/vim"
      The lines of output should equal 2
      The status should be success
    End

    It "extracts cleanup symlinks for wsl platform"
      When call parse_cleanup_symlinks_from_yaml "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "wsl"
      The output should include ".config/vim"
      The lines of output should equal 1
      The status should be success
    End

    It "extracts cleanup symlinks with custom targets for windows platform"
      When call parse_cleanup_symlinks_from_yaml "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "windows"
      # Should output in format: source|target (pipe-separated)
      The output should include ".config/alacritty/alacritty.toml|\$APPDATA/alacritty/alacritty.toml"
      The output should include ".config/alacritty/themes|\$APPDATA/alacritty/themes"
      The lines of output should equal 2
      The status should be success
    End

    It "extracts cleanup symlinks for macos platform"
      When call parse_cleanup_symlinks_from_yaml "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "macos"
      The output should include ".config/alacritty"
      The lines of output should equal 1
      The status should be success
    End

    It "returns empty when no cleanup section exists"
      temp_dir=$(mktemp -d)
      cat > "${temp_dir}/symlinks.yaml" << 'EOF'
arch:
  - .bashrc
  - .config/nvim
EOF

      When call parse_cleanup_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "arch"
      The output should equal ""
      The status should be success
    End

    It "returns empty for non-existent platform"
      When call parse_cleanup_symlinks_from_yaml "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "unknown"
      The output should equal ""
      The status should be success
    End

    It "handles missing symlinks.yaml file"
      When call parse_cleanup_symlinks_from_yaml "/nonexistent/symlinks.yaml" "arch"
      The status should be failure
      The output should equal ""
    End
  End

  Describe "remove_symlink"
    It "removes a broken symlink in dry-run mode"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/home/.config"
      # Create broken symlink
      command ln -s "/nonexistent/source" "${temp_dir}/home/.config/alacritty"

      When call remove_symlink "${temp_dir}/home/.config/alacritty" true
      The status should be success
      The output should include "Would remove: ${temp_dir}/home/.config/alacritty"
      The path "${temp_dir}/home/.config/alacritty" should be symlink
    End

    It "removes a broken symlink"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/home/.config"
      # Create broken symlink
      command ln -s "/nonexistent/source" "${temp_dir}/home/.config/alacritty"

      When call remove_symlink "${temp_dir}/home/.config/alacritty" false
      The status should be success
      The output should include "Removed: ${temp_dir}/home/.config/alacritty"
      The path "${temp_dir}/home/.config/alacritty" should not be exist
    End

    It "removes a valid symlink in dry-run mode"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/dotfiles/.config"
      mkdir -p "${temp_dir}/home/.config"
      echo "test" > "${temp_dir}/dotfiles/.config/alacritty"
      command ln -s "${temp_dir}/dotfiles/.config/alacritty" "${temp_dir}/home/.config/alacritty"

      When call remove_symlink "${temp_dir}/home/.config/alacritty" true
      The status should be success
      The output should include "Would remove: ${temp_dir}/home/.config/alacritty"
      The path "${temp_dir}/home/.config/alacritty" should be exist
    End

    It "removes a valid symlink"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/dotfiles/.config"
      mkdir -p "${temp_dir}/home/.config"
      echo "test" > "${temp_dir}/dotfiles/.config/alacritty"
      command ln -s "${temp_dir}/dotfiles/.config/alacritty" "${temp_dir}/home/.config/alacritty"

      When call remove_symlink "${temp_dir}/home/.config/alacritty" false
      The status should be success
      The output should include "Removed: ${temp_dir}/home/.config/alacritty"
      The path "${temp_dir}/home/.config/alacritty" should not be exist
    End

    It "skips removal if target does not exist"
      temp_dir=$(mktemp -d)

      When call remove_symlink "${temp_dir}/home/.config/alacritty" false
      The status should be success
      The output should include "Skipped (not found): ${temp_dir}/home/.config/alacritty"
    End

    It "skips removal if target is not a symlink"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/home/.config"
      echo "regular file" > "${temp_dir}/home/.config/alacritty"

      When call remove_symlink "${temp_dir}/home/.config/alacritty" false
      The status should be success
      The output should include "Skipped (not a symlink): ${temp_dir}/home/.config/alacritty"
      The path "${temp_dir}/home/.config/alacritty" should be exist
    End

    It "skips removal if target is a directory"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/home/.config/alacritty"

      When call remove_symlink "${temp_dir}/home/.config/alacritty" false
      The status should be success
      The output should include "Skipped (not a symlink): ${temp_dir}/home/.config/alacritty"
      The path "${temp_dir}/home/.config/alacritty" should be directory
    End
  End

  Describe "process_cleanup_symlinks"
    It "removes cleanup symlinks with default targets in dry-run mode"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/home/.config"
      # Create broken symlinks
      command ln -s "/nonexistent/alacritty" "${temp_dir}/home/.config/alacritty"
      command ln -s "/nonexistent/vim" "${temp_dir}/home/.config/vim"

      When call process_cleanup_symlinks "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "arch" "${temp_dir}/dotfiles" "${temp_dir}/home" true
      The status should be success
      The output should include "Would remove: ${temp_dir}/home/.config/alacritty"
      The output should include "Would remove: ${temp_dir}/home/.config/vim"
      The path "${temp_dir}/home/.config/alacritty" should be symlink
      The path "${temp_dir}/home/.config/vim" should be symlink
    End

    It "removes cleanup symlinks with default targets"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/home/.config"
      # Create broken symlinks
      command ln -s "/nonexistent/alacritty" "${temp_dir}/home/.config/alacritty"
      command ln -s "/nonexistent/vim" "${temp_dir}/home/.config/vim"

      When call process_cleanup_symlinks "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "arch" "${temp_dir}/dotfiles" "${temp_dir}/home" false
      The status should be success
      The output should include "Removed: ${temp_dir}/home/.config/alacritty"
      The output should include "Removed: ${temp_dir}/home/.config/vim"
      The path "${temp_dir}/home/.config/alacritty" should not be exist
      The path "${temp_dir}/home/.config/vim" should not be exist
    End

    It "handles cleanup symlinks with custom targets"
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/appdata/alacritty"
      export APPDATA="${temp_dir}/appdata"
      # Create broken symlinks at custom target locations
      command ln -s "/nonexistent/alacritty.toml" "${temp_dir}/appdata/alacritty/alacritty.toml"
      command ln -s "/nonexistent/themes" "${temp_dir}/appdata/alacritty/themes"

      When call process_cleanup_symlinks "spec/fixtures/yaml/symlinks-with-cleanup.yaml" "windows" "${temp_dir}/dotfiles" "${temp_dir}/home" false
      The status should be success
      The output should include "Removed: ${temp_dir}/appdata/alacritty/alacritty.toml"
      The output should include "Removed: ${temp_dir}/appdata/alacritty/themes"
      The path "${temp_dir}/appdata/alacritty/alacritty.toml" should not be exist
      The path "${temp_dir}/appdata/alacritty/themes" should not be exist

      unset APPDATA
    End

    It "returns success when no cleanup section exists"
      temp_dir=$(mktemp -d)
      cat > "${temp_dir}/symlinks.yaml" << 'EOF'
arch:
  - .bashrc
EOF

      When call process_cleanup_symlinks "${temp_dir}/symlinks.yaml" "arch" "${temp_dir}/dotfiles" "${temp_dir}/home" false
      The status should be success
      The output should equal ""
    End
  End
End
