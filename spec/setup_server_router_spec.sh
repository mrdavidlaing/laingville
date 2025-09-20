#!/usr/bin/env bash

Describe 'setup-server with freshtomato platform'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/platform.functions.bash
  Include lib/packages.functions.bash
  Include lib/setup-server.functions.bash

  Describe 'handle_packages_from_file() with freshtomato'
    setup() {
      # Create test packages file
    mkdir -p servers/testrouter
      cat > servers/testrouter/packages.yaml << 'EOF'
freshtomato:
  opkg:
    - git
    - rsync
    - htop
  custom:
    - test_custom_script
EOF

      # Mock opkg command
      opkg() {
        case "$1" in
          "update")
            echo "Updated package lists"
            ;;
          "install")
            shift
            echo "Installing: $*"
            ;;
        esac
      }
    }

    cleanup() {
      rm -rf servers/testrouter
    }

    Before 'setup'
    After 'cleanup'

    It 'processes freshtomato packages correctly'
      When call handle_packages_from_file "freshtomato" true "servers/testrouter/packages.yaml" "SERVER"
      The output should include "install via opkg: git, rsync, htop"
      The status should be success
    End

    It 'installs opkg packages when not in dry-run'
      When call handle_packages_from_file "freshtomato" false "servers/testrouter/packages.yaml" "SERVER"
      The output should include "Updated package lists"
      The output should include "Installing: git rsync htop"
      The status should be success
    End
  End

  Describe 'extract_packages_from_yaml() for freshtomato'
    setup() {
      mkdir -p servers/testrouter
      cat > servers/testrouter/packages.yaml << 'EOF'
freshtomato:
  opkg:
    - git
    - rsync
    - htop
    - nano
  custom:
    - apply_router_configs
EOF
    }

    cleanup() {
      rm -rf servers/testrouter
    }

    Before 'setup'
    After 'cleanup'

    It 'returns empty for non-router platforms'
      When call extract_packages_from_yaml "macos" "opkg" "servers/testrouter/packages.yaml"
      The output should be blank
      The status should be success
    End

    It 'extracts opkg packages for freshtomato platform'
      When call extract_packages_from_yaml "freshtomato" "opkg" "servers/testrouter/packages.yaml"
      The line 1 of output should equal "git"
      The line 2 of output should equal "rsync"
      The line 3 of output should equal "htop"
      The line 4 of output should equal "nano"
      The status should be success
    End

    It 'extracts custom scripts for freshtomato platform'
      When call extract_packages_from_yaml "freshtomato" "custom" "servers/testrouter/packages.yaml"
      The output should equal "apply_router_configs"
      The status should be success
    End

    It 'extracts opkg packages for freshtomato platform (dwaca config test)'
      # Create temporary test config with freshtomato platform
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/servers/testrouter"
      cat > "${temp_dir}/servers/testrouter/packages.yaml" << 'EOF'
freshtomato:
  opkg:
    - vim
    - htop
  custom:
    - apply_motd
    - apply_profile
EOF

      When call extract_packages_from_yaml "freshtomato" "opkg" "${temp_dir}/servers/testrouter/packages.yaml"
      The line 1 of output should equal "vim"
      The line 2 of output should equal "htop"
      The status should be success

      rm -rf "${temp_dir}"
    End

    It 'extracts custom scripts for freshtomato platform (dwaca config test)'
      # Create temporary test config with freshtomato platform
      temp_dir=$(mktemp -d)
      mkdir -p "${temp_dir}/servers/testrouter"
      cat > "${temp_dir}/servers/testrouter/packages.yaml" << 'EOF'
freshtomato:
  opkg:
    - vim
    - htop
  custom:
    - apply_motd
    - apply_profile
    - setup_init_scripts
EOF

      When call extract_packages_from_yaml "freshtomato" "custom" "${temp_dir}/servers/testrouter/packages.yaml"
      The line 1 of output should equal "apply_motd"
      The line 2 of output should equal "apply_profile"
      The line 3 of output should equal "setup_init_scripts"
      The status should be success

      rm -rf "${temp_dir}"
    End
  End

  Describe 'map_hostname_to_server_dir()'
    It 'maps router hostname to correct server directory'
      When call map_hostname_to_server_dir "dwaca"
      The output should equal "servers/dwaca"
      The status should be success
    End

    It 'maps any hostname to servers directory'
      When call map_hostname_to_server_dir "testrouter"
      The output should equal "servers/testrouter"
      The status should be success
    End
  End
End
