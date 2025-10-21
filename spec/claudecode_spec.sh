#!/usr/bin/env bash

Describe 'Claude Code Plugin Management'

# ShellSpec framework functions trigger SC2218 false positives
# shellcheck disable=SC2218
# shellcheck disable=SC2154  # SHELLSPEC_PROJECT_ROOT is set by shellspec framework
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"
    Before "source ./lib/polyfill.functions.bash"
      Before "source ./lib/logging.functions.bash"
        Before "source ./lib/security.functions.bash"
          Before "source ./lib/claudecode.functions.bash"

            Describe 'extract_claudecode_plugins_from_yaml()'
              It 'extracts plugins from valid packages.yaml'
                test_plugins() {
                printf 'claudecode:\n  plugins:\n    - superpowers@obra/superpowers-marketplace\n    - another-plugin@user/repo\n' | extract_claudecode_plugins_from_yaml
                }
                When call test_plugins
                The line 1 of output should equal "superpowers@obra/superpowers-marketplace"
                The line 2 of output should equal "another-plugin@user/repo"
                The lines of output should equal 2
              End

              It 'returns nothing when claudecode section missing'
                test_no_plugins() {
                printf 'arch:\n  pacman:\n    - vim\n' | extract_claudecode_plugins_from_yaml
                }
                When call test_no_plugins
                The output should equal ""
              End
            End

            Describe 'extract_marketplace_from_plugin()'
              It 'extracts marketplace from plugin@marketplace format'
                When call extract_marketplace_from_plugin "superpowers@obra/superpowers-marketplace"
                The output should equal "obra/superpowers-marketplace"
              End

              It 'returns empty for invalid format without @'
                When call extract_marketplace_from_plugin "invalid-plugin"
                The output should equal ""
                The status should be failure
              End

              It 'handles plugin names with hyphens'
                When call extract_marketplace_from_plugin "my-plugin@owner/my-marketplace"
                The output should equal "owner/my-marketplace"
              End
            End
          End
