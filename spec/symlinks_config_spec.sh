#!/usr/bin/env bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe "symlinks configuration in symlinks.yaml"
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/platform.functions.bash
  Include lib/packages.functions.bash
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

  # Cleanup temp directories after each test
  AfterEach 'cleanup_temp_dir'
  
  cleanup_temp_dir() {
  if [[ -n "${temp_dir:-}" && -d "${temp_dir}" ]]; then
  rm -rf "${temp_dir}"
  unset temp_dir
  fi
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

    End

    It "extracts symlinks for wsl platform"
      temp_dir=$(mktemp -d)
      setup_test_config "${temp_dir}"

      When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "wsl"
      The output should include ".bashrc"
      The output should include ".config/tmux"
      The output should include ".gitconfig"
      The lines of output should equal 3

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

    End

    It "handles custom targets for macos platform"
      temp_dir=$(mktemp -d)
      setup_test_config "${temp_dir}"

      When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "macos"
      The output should include ".bashrc|"
      The output should include ".config/tmux|"
      The output should include ".config/aerospace|\${HOME}/.aerospace"
      The lines of output should equal 3

    End

    It "returns empty for non-existent platform"
      temp_dir=$(mktemp -d)
      setup_test_config "${temp_dir}"

      When call parse_symlinks_from_yaml "${temp_dir}/symlinks.yaml" "unknown"
      The output should equal ""

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

  End

  Describe "create_symlink_with_target"
    Describe "dry-run mode (existing tests)"
      It "creates symlink with default target"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "" "${temp_dir}/home" true
        The status should be success
        The output should include "Would: create: ${temp_dir}/home/.config/test.conf"

      End

      It "creates symlink with custom target"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"
        mkdir -p "${temp_dir}/custom"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "${temp_dir}/custom/test.conf" "${temp_dir}/home" true
        The status should be success
        The output should include "Would: create: ${temp_dir}/custom/test.conf"

      End
    End

    Describe "actual symlink creation"
      It "creates symlink with default target when target doesn't exist"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "" "${temp_dir}/home" false
        The status should be success
        The output should include "Created: ${temp_dir}/home/.config/test.conf"
        The path "${temp_dir}/home/.config/test.conf" should be symlink
        The contents of file "${temp_dir}/home/.config/test.conf" should equal "test content"

      End

      It "creates symlink with custom target when target doesn't exist"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "${temp_dir}/custom/test.conf" "${temp_dir}/home" false
        The status should be success
        The output should include "Created: ${temp_dir}/custom/test.conf"
        The path "${temp_dir}/custom/test.conf" should be symlink
        The contents of file "${temp_dir}/custom/test.conf" should equal "test content"

      End

      It "replaces existing symlink"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "old content" > "${temp_dir}/dotfiles/.config/old.conf"
        echo "new content" > "${temp_dir}/dotfiles/.config/new.conf"
        mkdir -p "${temp_dir}/home/.config"
        command ln -s "${temp_dir}/dotfiles/.config/old.conf" "${temp_dir}/home/.config/test.conf"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/new.conf" "" "${temp_dir}/home" false
        The status should be success
        The output should include "Created: ${temp_dir}/home/.config/new.conf"
        The path "${temp_dir}/home/.config/new.conf" should be symlink
        The contents of file "${temp_dir}/home/.config/new.conf" should equal "new content"

      End

      It "replaces existing regular file"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "symlink content" > "${temp_dir}/dotfiles/.config/test.conf"
        mkdir -p "${temp_dir}/home/.config"
        echo "regular file content" > "${temp_dir}/home/.config/test.conf"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "" "${temp_dir}/home" false
        The status should be success
        The output should include "Created: ${temp_dir}/home/.config/test.conf"
        The path "${temp_dir}/home/.config/test.conf" should be symlink
        The contents of file "${temp_dir}/home/.config/test.conf" should equal "symlink content"

      End

      It "recreates identical directory symlink without creating cyclic links"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config/testdir"
        echo "test content" > "${temp_dir}/dotfiles/.config/testdir/config.txt"
        mkdir -p "${temp_dir}/home/.config"
        
        # Create initial symlink (simulating first run of setup-user)
        command ln -s "${temp_dir}/dotfiles/.config/testdir" "${temp_dir}/home/.config/testdir"
        
        # Try to create the same symlink again (simulating second run of setup-user)
        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/testdir" "" "${temp_dir}/home" false
        The status should be success
        The output should include "Created: ${temp_dir}/home/.config/testdir"
        
        # Verify target is correct symlink
        The path "${temp_dir}/home/.config/testdir" should be symlink
        The contents of file "${temp_dir}/home/.config/testdir/config.txt" should equal "test content"
        
        # CRITICAL: Verify no cyclic symlink was created in source directory
        The path "${temp_dir}/dotfiles/.config/testdir/testdir" should not be exist

      End
    End

    Describe "existing directory scenarios"
      It "fails when target exists as directory"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"
        mkdir -p "${temp_dir}/home/.config/test.conf"  # Create as directory

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "" "${temp_dir}/home" false
        The status should be failure
        The error should include "Target '${temp_dir}/home/.config/test.conf' already exists as a directory"
        The error should include "Cannot create symlink"
        The path "${temp_dir}/home/.config/test.conf" should be directory
        The path "${temp_dir}/home/.config/test.conf/test.conf" should not be exist

      End

      It "fails when custom target exists as directory"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"
        mkdir -p "${temp_dir}/custom/test.conf"  # Create target as directory

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "${temp_dir}/custom/test.conf" "${temp_dir}/home" false
        The status should be failure
        The error should include "Target '${temp_dir}/custom/test.conf' already exists as a directory"
        The error should include "Cannot create symlink"
        The path "${temp_dir}/custom/test.conf" should be directory
        The path "${temp_dir}/custom/test.conf/test.conf" should not be exist

      End

      It "fails when target exists as directory in dry-run mode"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"
        mkdir -p "${temp_dir}/home/.config/test.conf"  # Create as directory

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "" "${temp_dir}/home" true
        The status should be failure
        The error should include "Target '${temp_dir}/home/.config/test.conf' already exists as a directory"
        The error should include "Cannot create symlink"
        The path "${temp_dir}/home/.config/test.conf" should be directory

      End
    End

    Describe "environment variable expansion in custom targets"
      It "expands environment variables in custom target paths"
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/dotfiles/.config"
        echo "test content" > "${temp_dir}/dotfiles/.config/test.conf"
        export TEST_TARGET_DIR="${temp_dir}/expanded"

        When call create_symlink_with_target "${temp_dir}/dotfiles/.config/test.conf" "\${TEST_TARGET_DIR}/test.conf" "${temp_dir}/home" false
        The status should be success
        The output should include "Created: ${temp_dir}/expanded/test.conf"
        The path "${temp_dir}/expanded/test.conf" should be symlink
        The contents of file "${temp_dir}/expanded/test.conf" should equal "test content"

        unset TEST_TARGET_DIR
      End
    End

  End

  Describe "create_symlink_force (cross-platform polyfill)"
    It "uses -sfh flags on macOS"
      # Mock ln command to capture arguments
      # shellcheck disable=SC2329
      ln() {
      LN_CALLED_WITH="$*"
      }
      
      # Mock detect_os to return macOS  
      # shellcheck disable=SC2329
      detect_os() { echo "macos"; }
      
      When call create_symlink_force "source_path" "target_path"
      The variable LN_CALLED_WITH should equal "-sfh source_path target_path"
    End

    It "uses -sfn flags on Linux"
      # Mock ln command to capture arguments
      # shellcheck disable=SC2329
      ln() {
        LN_CALLED_WITH="$*"
      }
      
      # Mock detect_os to return Linux
      # shellcheck disable=SC2329
      detect_os() { echo "linux"; }
      
      When call create_symlink_force "source_path" "target_path" 
      The variable LN_CALLED_WITH should equal "-sfn source_path target_path"
    End

    It "uses fallback with rm+ln on unknown platforms when target exists"
      temp_dir=$(mktemp -d)
      # Create actual target file to satisfy the [[ -e ]] condition
      touch "${temp_dir}/target_path"
      
      # Mock rm command to capture arguments (don't actually remove)
      rm() {
        RM_CALLED_WITH="$*"
      }
      
      # Mock ln command to capture arguments
      # shellcheck disable=SC2329
      ln() {
        LN_CALLED_WITH="$*"
      }
      
      # Mock detect_os to return unknown platform
      detect_os() { echo "unknown"; }
      
      When call create_symlink_force "source_path" "${temp_dir}/target_path"
      The variable RM_CALLED_WITH should equal "-f ${temp_dir}/target_path"
      The variable LN_CALLED_WITH should equal "-s source_path ${temp_dir}/target_path"
      
      command rm -rf "${temp_dir}"  # Use command to bypass our mock
    End

    It "validates required arguments"
      When call create_symlink_force "" "target_path"
      The status should be failure
      The stderr should include "create_symlink_force requires source and target arguments"
    End

    It "validates both arguments are provided"
      When call create_symlink_force "source_path" ""
      The status should be failure
      The stderr should include "create_symlink_force requires source and target arguments"
    End
  End

End
