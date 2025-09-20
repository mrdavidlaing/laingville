#!/usr/bin/env bash

Describe 'setup-server with router-merlin platform'
  Include lib/logging.functions.bash
  Include lib/security.functions.bash
  Include lib/polyfill.functions.bash
  Include lib/platform.functions.bash
  Include lib/packages.functions.bash
  Include lib/setup-server.functions.bash

  Describe 'handle_packages_from_file() with router-merlin'
    setup() {
      # Create test packages file
    mkdir -p servers/testrouter
      cat > servers/testrouter/packages.yaml << 'EOF'
router-merlin:
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

    It 'processes router-merlin packages correctly'
      When call handle_packages_from_file "router-merlin" true "servers/testrouter/packages.yaml" "SERVER"
      The output should include "install via opkg: git, rsync, htop"
      The status should be success
    End

    It 'installs opkg packages when not in dry-run'
      When call handle_packages_from_file "router-merlin" false "servers/testrouter/packages.yaml" "SERVER"
      The output should include "Updated package lists"
      The output should include "Installing: git rsync htop"
      The status should be success
    End
  End

  Describe 'extract_packages_from_yaml() for router-merlin'
    setup() {
      mkdir -p servers/testrouter
      cat > servers/testrouter/packages.yaml << 'EOF'
router-merlin:
  opkg:
    - git
    - rsync
    - htop
    - nano
  custom:
    - apply_router_configs

macos:
  homebrew:
    - git
    - curl
EOF
    }

    cleanup() {
      rm -rf servers/testrouter
    }

    Before 'setup'
    After 'cleanup'

    It 'extracts opkg packages for router-merlin platform'
      When call extract_packages_from_yaml "router-merlin" "opkg" "servers/testrouter/packages.yaml"
      The line 1 of output should equal "git"
      The line 2 of output should equal "rsync"
      The line 3 of output should equal "htop"
      The line 4 of output should equal "nano"
      The status should be success
    End

    It 'extracts custom scripts for router-merlin platform'
      When call extract_packages_from_yaml "router-merlin" "custom" "servers/testrouter/packages.yaml"
      The output should equal "apply_router_configs"
      The status should be success
    End

    It 'returns empty for non-router platforms'
      When call extract_packages_from_yaml "macos" "opkg" "servers/testrouter/packages.yaml"
      The output should be blank
      The status should be success
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
