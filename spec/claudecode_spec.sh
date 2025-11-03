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

            Describe 'ensure_marketplace_added()'
              # shellcheck disable=SC2329 # Function is invoked by ShellSpec BeforeEach
              setup_mock_claude() {
                # Create mock claude command as an executable script
              mkdir -p "$SHELLSPEC_TMPBASE/bin"
                cat > "$SHELLSPEC_TMPBASE/bin/claude" << MOCK_EOF
#!/usr/bin/env bash
echo "\$@" >> "$SHELLSPEC_TMPBASE/claude_commands.log"
exit 0
MOCK_EOF
              chmod +x "$SHELLSPEC_TMPBASE/bin/claude"
              export PATH="$SHELLSPEC_TMPBASE/bin:$PATH"
              : > "$SHELLSPEC_TMPBASE/claude_commands.log"
              }

              BeforeEach setup_mock_claude

              It 'calls claude plugin marketplace add with valid marketplace'
                When call ensure_marketplace_added "obra/superpowers-marketplace" false
                The status should be success
                The stdout should include "Adding marketplace: obra/superpowers-marketplace"
                The stdout should include "Marketplace added: obra/superpowers-marketplace"
              End

              It 'rejects unsafe marketplace names'
                When call ensure_marketplace_added "obra/super; rm -rf" false
                The status should be failure
                The stderr should include "Invalid marketplace name"
              End

              It 'shows dry-run message without calling claude'
                When call ensure_marketplace_added "obra/superpowers-marketplace" true
                The status should be success
                The stdout should include "Would add marketplace: obra/superpowers-marketplace"
              End
            End

            Describe 'install_or_update_plugin()'
              setup_mock_claude() {
                # Create mock claude command as an executable script
              mkdir -p "$SHELLSPEC_TMPBASE/bin"
                cat > "$SHELLSPEC_TMPBASE/bin/claude" << MOCK_EOF
#!/usr/bin/env bash
echo "\$@" >> "$SHELLSPEC_TMPBASE/claude_commands.log"
exit 0
MOCK_EOF
              chmod +x "$SHELLSPEC_TMPBASE/bin/claude"
              export PATH="$SHELLSPEC_TMPBASE/bin:$PATH"
              : > "$SHELLSPEC_TMPBASE/claude_commands.log"
              }

              BeforeEach setup_mock_claude

              It 'calls claude plugin install with valid plugin'
                When call install_or_update_plugin "superpowers@obra/superpowers-marketplace" false
                The status should be success
                The stdout should include "Installing plugin: superpowers@obra/superpowers-marketplace"
                The stdout should include "Plugin installed: superpowers@obra/superpowers-marketplace"
              End

              It 'rejects invalid plugin format'
                When call install_or_update_plugin "invalid-no-marketplace" false
                The status should be failure
                The stderr should include "Invalid plugin format"
              End

              It 'shows dry-run message without calling claude'
                When call install_or_update_plugin "superpowers@obra/superpowers-marketplace" true
                The status should be success
                The stdout should include "Would install plugin: superpowers@obra/superpowers-marketplace"
              End
            End

            Describe 'handle_claudecode_plugins()'
              setup_integration() {
                # Create temporary packages.yaml
              mkdir -p "$SHELLSPEC_TMPBASE"
                cat > "$SHELLSPEC_TMPBASE/packages.yaml" << 'EOF'
claudecode:
  plugins:
    - plugin1@owner1/marketplace1
    - plugin2@owner1/marketplace1
    - plugin3@owner2/marketplace2
EOF

              export DOTFILES_DIR="$SHELLSPEC_TMPBASE"

                # Mock claude command - expand SHELLSPEC_TMPBASE at creation time
              mkdir -p "$SHELLSPEC_TMPBASE/bin"
                cat > "$SHELLSPEC_TMPBASE/bin/claude" <<MOCK_EOF
#!/usr/bin/env bash
echo "\$@" >> "$SHELLSPEC_TMPBASE/claude_commands.log"
exit 0
MOCK_EOF
              chmod +x "$SHELLSPEC_TMPBASE/bin/claude"
              export PATH="$SHELLSPEC_TMPBASE/bin:$PATH"
              : > "$SHELLSPEC_TMPBASE/claude_commands.log"
              }

              BeforeEach setup_integration

              check_marketplace_count() {
              grep -c "marketplace add" "$SHELLSPEC_TMPBASE/claude_commands.log" || echo 0
              }

              check_plugin1_installed() {
              grep -c "plugin install plugin1@owner1/marketplace1" "$SHELLSPEC_TMPBASE/claude_commands.log" || echo 0
              }

              check_plugin2_installed() {
              grep -c "plugin install plugin2@owner1/marketplace1" "$SHELLSPEC_TMPBASE/claude_commands.log" || echo 0
              }

              check_plugin3_installed() {
              grep -c "plugin install plugin3@owner2/marketplace2" "$SHELLSPEC_TMPBASE/claude_commands.log" || echo 0
              }

              It 'processes all plugins and deduplicates marketplaces'
                When call handle_claudecode_plugins false
                The status should be success
                # Should add each marketplace only once
                The result of function check_marketplace_count should equal 2
                # Should install all plugins
                The result of function check_plugin1_installed should equal 1
                The result of function check_plugin2_installed should equal 1
                The result of function check_plugin3_installed should equal 1
              End

              It 'handles missing packages.yaml gracefully'
                rm "$SHELLSPEC_TMPBASE/packages.yaml"
                When call handle_claudecode_plugins false
                The status should be success
                The stdout should include "No packages.yaml found"
              End

              It 'handles empty claudecode section gracefully'
                cat > "$SHELLSPEC_TMPBASE/packages.yaml" << 'EOF'
arch:
  pacman:
    - vim
EOF
                When call handle_claudecode_plugins false
                The status should be success
                The stdout should include "No Claude Code plugins configured"
              End
            End
          End
