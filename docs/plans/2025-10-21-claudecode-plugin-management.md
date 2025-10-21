# Claude Code Plugin Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically install and update Claude Code plugins from `packages.yaml` configuration when running `setup-user`, ensuring consistent plugin environments across all platforms.

**Architecture:** Imperative script approach following existing codebase patterns. Parse `claudecode.plugins` from YAML, extract marketplaces from `plugin@marketplace` format, idempotently add marketplaces, then install/update plugins using `claude` CLI commands.

**Tech Stack:** Bash 3.2+ (Mac/Linux/WSL), ShellSpec (testing), existing YAML parsing functions, `claude` CLI

---

## Phase 1: Bash Implementation

### Task 1: Create YAML Parsing Function

**Files:**
- Create: `lib/claudecode.functions.bash`
- Test: `spec/claudecode_spec.sh`

**Step 1: Write the failing test**

Create `spec/claudecode_spec.sh`:

```bash
#!/usr/bin/env bash

Describe 'Claude Code Plugin Management'
  Include lib/claudecode.functions.bash

  setup() {
    export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    export PROJECT_ROOT="$SCRIPT_DIR"
    export LIB_DIR="$PROJECT_ROOT/lib"

    # Source dependencies
    source "$LIB_DIR/polyfill.functions.bash"
    source "$LIB_DIR/logging.functions.bash"
    source "$LIB_DIR/security.functions.bash"
  }

  BeforeEach setup

  Describe 'extract_claudecode_plugins_from_yaml()'
    It 'extracts plugins from valid packages.yaml'
      yaml_content() {
        cat << 'EOF'
claudecode:
  plugins:
    - superpowers@obra/superpowers-marketplace
    - another-plugin@user/repo
EOF
      }

      Data
        yaml_content
      End

      When call extract_claudecode_plugins_from_yaml
      The line 1 of output should equal "superpowers@obra/superpowers-marketplace"
      The line 2 of output should equal "another-plugin@user/repo"
      The lines of output should equal 2
    End

    It 'returns nothing when claudecode section missing'
      yaml_content() {
        cat << 'EOF'
arch:
  pacman:
    - vim
EOF
      }

      Data
        yaml_content
      End

      When call extract_claudecode_plugins_from_yaml
      The output should equal ""
    End
  End
End
```

**Step 2: Run test to verify it fails**

```bash
cd .worktrees/feature/claudecode-plugin-management
shellspec spec/claudecode_spec.sh
```

Expected: FAIL with "extract_claudecode_plugins_from_yaml: command not found"

**Step 3: Write minimal implementation**

Create `lib/claudecode.functions.bash`:

```bash
#!/usr/bin/env bash

# Claude Code plugin management functions

# Extract plugins from packages.yaml
# Reads from stdin (YAML content)
# Outputs one plugin per line in format: plugin@marketplace
extract_claudecode_plugins_from_yaml() {
    local in_claudecode=false
    local in_plugins=false

    while IFS= read -r line; do
        # Remove leading whitespace for easier parsing
        local trimmed_line
        trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//')

        # Check for claudecode section
        if [ "$trimmed_line" = "claudecode:" ]; then
            in_claudecode=true
            continue
        fi

        # Exit claudecode section if we hit another top-level key
        if [ "$in_claudecode" = true ] && echo "$trimmed_line" | grep -q "^[a-z].*:$"; then
            in_claudecode=false
            in_plugins=false
            continue
        fi

        # Check for plugins subsection
        if [ "$in_claudecode" = true ] && [ "$trimmed_line" = "plugins:" ]; then
            in_plugins=true
            continue
        fi

        # Exit plugins subsection if we hit another subsection
        if [ "$in_plugins" = true ] && echo "$trimmed_line" | grep -q "^[a-z].*:$"; then
            in_plugins=false
            continue
        fi

        # Extract plugin entries (lines starting with -)
        if [ "$in_plugins" = true ] && echo "$trimmed_line" | grep -q "^- "; then
            local plugin
            plugin=$(echo "$trimmed_line" | sed 's/^- //')
            echo "$plugin"
        fi
    done
}
```

**Step 4: Run test to verify it passes**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: PASS (2 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/claudecode.functions.bash spec/claudecode_spec.sh
git commit -m "feat(claudecode): add YAML plugin extraction function

Parse claudecode.plugins from packages.yaml and output one plugin per line.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Create Marketplace Extraction Function

**Files:**
- Modify: `lib/claudecode.functions.bash`
- Modify: `spec/claudecode_spec.sh`

**Step 1: Write the failing test**

Add to `spec/claudecode_spec.sh` before the final `End`:

```bash
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
```

**Step 2: Run test to verify it fails**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: FAIL with "extract_marketplace_from_plugin: command not found"

**Step 3: Write minimal implementation**

Add to `lib/claudecode.functions.bash`:

```bash
# Extract marketplace from plugin@marketplace format
# Args: $1 = plugin string (e.g., "superpowers@obra/superpowers-marketplace")
# Outputs: marketplace (e.g., "obra/superpowers-marketplace")
# Returns: 0 on success, 1 if format invalid
extract_marketplace_from_plugin() {
    local plugin="$1"

    if [ -z "$plugin" ]; then
        return 1
    fi

    # Check if plugin contains @
    if ! echo "$plugin" | grep -q "@"; then
        return 1
    fi

    # Extract everything after @
    local marketplace
    marketplace=$(echo "$plugin" | sed 's/^[^@]*@//')

    if [ -z "$marketplace" ]; then
        return 1
    fi

    echo "$marketplace"
    return 0
}
```

**Step 4: Run test to verify it passes**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: PASS (5 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/claudecode.functions.bash spec/claudecode_spec.sh
git commit -m "feat(claudecode): add marketplace extraction from plugin format

Extract marketplace from plugin@marketplace string format.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Create Marketplace Add Function with Security Validation

**Files:**
- Modify: `lib/claudecode.functions.bash`
- Modify: `spec/claudecode_spec.sh`

**Step 1: Write the failing test**

Add to `spec/claudecode_spec.sh`:

```bash
  Describe 'ensure_marketplace_added()'
    setup_mock_claude() {
      # Create mock claude command
      claude() {
        echo "$@" >> "$SHELLSPEC_TMPBASE/claude_commands.log"
        return 0
      }
      export -f claude
      mkdir -p "$SHELLSPEC_TMPBASE"
      : > "$SHELLSPEC_TMPBASE/claude_commands.log"
    }

    BeforeEach setup_mock_claude

    It 'calls claude plugin marketplace add with valid marketplace'
      When call ensure_marketplace_added "obra/superpowers-marketplace" false
      The status should be success
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should include "plugin marketplace add obra/superpowers-marketplace"
    End

    It 'rejects unsafe marketplace names'
      When call ensure_marketplace_added "obra/super; rm -rf" false
      The status should be failure
      The stderr should include "Invalid marketplace name"
    End

    It 'shows dry-run message without calling claude'
      When call ensure_marketplace_added "obra/superpowers-marketplace" true
      The status should be success
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should not include "plugin marketplace add"
    End
  End
```

**Step 2: Run test to verify it fails**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: FAIL with "ensure_marketplace_added: command not found"

**Step 3: Write minimal implementation**

Add to `lib/claudecode.functions.bash` (after sourcing required functions at top):

```bash
# Ensure marketplace is added to Claude Code
# Args: $1 = marketplace (e.g., "obra/superpowers-marketplace")
#       $2 = dry_run (true/false)
# Returns: 0 on success, 1 on failure
ensure_marketplace_added() {
    local marketplace="$1"
    local dry_run="${2:-false}"

    if [ -z "$marketplace" ]; then
        log_error "Marketplace name is required"
        return 1
    fi

    # Security validation - marketplace should be owner/repo format
    # Allow alphanumeric, hyphens, underscores, and forward slash
    if ! echo "$marketplace" | grep -qE "^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$"; then
        log_error "Invalid marketplace name: $marketplace"
        return 1
    fi

    if [ "$dry_run" = true ]; then
        log_dry_run "Would add marketplace: $marketplace"
        return 0
    fi

    log_info "Adding marketplace: $marketplace"

    if claude plugin marketplace add "$marketplace" >/dev/null 2>&1; then
        log_success "Marketplace added: $marketplace"
        return 0
    else
        log_warning "Failed to add marketplace: $marketplace (may already exist)"
        return 0  # Not a fatal error - marketplace might already exist
    fi
}
```

**Step 4: Run test to verify it passes**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: PASS (8 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/claudecode.functions.bash spec/claudecode_spec.sh
git commit -m "feat(claudecode): add marketplace installation with security validation

Idempotently add marketplaces with validation against command injection.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Create Plugin Install Function

**Files:**
- Modify: `lib/claudecode.functions.bash`
- Modify: `spec/claudecode_spec.sh`

**Step 1: Write the failing test**

Add to `spec/claudecode_spec.sh`:

```bash
  Describe 'install_or_update_plugin()'
    setup_mock_claude() {
      claude() {
        echo "$@" >> "$SHELLSPEC_TMPBASE/claude_commands.log"
        return 0
      }
      export -f claude
      mkdir -p "$SHELLSPEC_TMPBASE"
      : > "$SHELLSPEC_TMPBASE/claude_commands.log"
    }

    BeforeEach setup_mock_claude

    It 'calls claude plugin install with valid plugin'
      When call install_or_update_plugin "superpowers@obra/superpowers-marketplace" false
      The status should be success
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should include "plugin install superpowers@obra/superpowers-marketplace"
    End

    It 'rejects invalid plugin format'
      When call install_or_update_plugin "invalid-no-marketplace" false
      The status should be failure
      The stderr should include "Invalid plugin format"
    End

    It 'shows dry-run message without calling claude'
      When call install_or_update_plugin "superpowers@obra/superpowers-marketplace" true
      The status should be success
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should not include "plugin install"
    End
  End
```

**Step 2: Run test to verify it fails**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: FAIL with "install_or_update_plugin: command not found"

**Step 3: Write minimal implementation**

Add to `lib/claudecode.functions.bash`:

```bash
# Install or update a Claude Code plugin
# Args: $1 = plugin (e.g., "superpowers@obra/superpowers-marketplace")
#       $2 = dry_run (true/false)
# Returns: 0 on success, 1 on failure
install_or_update_plugin() {
    local plugin="$1"
    local dry_run="${2:-false}"

    if [ -z "$plugin" ]; then
        log_error "Plugin name is required"
        return 1
    fi

    # Validate plugin format (must contain @)
    if ! echo "$plugin" | grep -q "@"; then
        log_error "Invalid plugin format: $plugin (expected plugin@marketplace)"
        return 1
    fi

    # Security validation - extract parts and validate
    local plugin_name marketplace
    plugin_name=$(echo "$plugin" | sed 's/@.*//')
    marketplace=$(extract_marketplace_from_plugin "$plugin")

    if [ -z "$plugin_name" ] || [ -z "$marketplace" ]; then
        log_error "Invalid plugin format: $plugin"
        return 1
    fi

    # Validate characters (alphanumeric, hyphens, underscores, @, /)
    if ! echo "$plugin" | grep -qE "^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$"; then
        log_error "Invalid plugin name: $plugin"
        return 1
    fi

    if [ "$dry_run" = true ]; then
        log_dry_run "Would install plugin: $plugin"
        return 0
    fi

    log_info "Installing plugin: $plugin"

    if claude plugin install "$plugin" >/dev/null 2>&1; then
        log_success "Plugin installed: $plugin"
        return 0
    else
        log_error "Failed to install plugin: $plugin"
        return 1
    fi
}
```

**Step 4: Run test to verify it passes**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: PASS (11 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/claudecode.functions.bash spec/claudecode_spec.sh
git commit -m "feat(claudecode): add plugin installation function

Install/update plugins with format validation and security checks.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Create Main Handler Function

**Files:**
- Modify: `lib/claudecode.functions.bash`
- Modify: `spec/claudecode_spec.sh`

**Step 1: Write the failing test**

Add to `spec/claudecode_spec.sh`:

```bash
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

      # Mock claude command
      claude() {
        echo "$@" >> "$SHELLSPEC_TMPBASE/claude_commands.log"
        return 0
      }
      export -f claude
      : > "$SHELLSPEC_TMPBASE/claude_commands.log"
    }

    BeforeEach setup_integration

    It 'processes all plugins and deduplicates marketplaces'
      When call handle_claudecode_plugins false
      The status should be success
      # Should add each marketplace only once
      The result of function check_marketplace_count should equal 2
      # Should install all plugins
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should include "plugin install plugin1@owner1/marketplace1"
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should include "plugin install plugin2@owner1/marketplace1"
      The file "$SHELLSPEC_TMPBASE/claude_commands.log" should include "plugin install plugin3@owner2/marketplace2"
    End

    check_marketplace_count() {
      grep -c "marketplace add" "$SHELLSPEC_TMPBASE/claude_commands.log" || echo 0
    }

    It 'handles missing packages.yaml gracefully'
      rm "$SHELLSPEC_TMPBASE/packages.yaml"
      When call handle_claudecode_plugins false
      The status should be success
      The stderr should include "packages.yaml not found"
    End

    It 'handles empty claudecode section gracefully'
      cat > "$SHELLSPEC_TMPBASE/packages.yaml" << 'EOF'
arch:
  pacman:
    - vim
EOF
      When call handle_claudecode_plugins false
      The status should be success
    End
  End
```

**Step 2: Run test to verify it fails**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: FAIL with "handle_claudecode_plugins: command not found"

**Step 3: Write minimal implementation**

Add to `lib/claudecode.functions.bash`:

```bash
# Main handler for Claude Code plugin management
# Args: $1 = dry_run (true/false)
# Returns: 0 on success, 1 on failure
handle_claudecode_plugins() {
    local dry_run="${1:-false}"

    # Check if packages.yaml exists
    local packages_file="$DOTFILES_DIR/packages.yaml"
    if [ ! -f "$packages_file" ]; then
        log_info "No packages.yaml found, skipping Claude Code plugin setup"
        return 0
    fi

    # Extract plugins from YAML
    local plugins
    plugins=$(cat "$packages_file" | extract_claudecode_plugins_from_yaml)

    if [ -z "$plugins" ]; then
        log_info "No Claude Code plugins configured"
        return 0
    fi

    # Track seen marketplaces (bash 3.2 compatible - space-separated string)
    local seen_marketplaces=" "

    # Process each plugin
    while IFS= read -r plugin; do
        if [ -z "$plugin" ]; then
            continue
        fi

        # Extract marketplace
        local marketplace
        marketplace=$(extract_marketplace_from_plugin "$plugin")

        if [ -z "$marketplace" ]; then
            log_warning "Invalid plugin format: $plugin (skipping)"
            continue
        fi

        # Add marketplace if not seen before
        if ! echo "$seen_marketplaces" | grep -q " $marketplace "; then
            ensure_marketplace_added "$marketplace" "$dry_run"
            seen_marketplaces="${seen_marketplaces}${marketplace} "
        fi

        # Install/update plugin
        install_or_update_plugin "$plugin" "$dry_run" || {
            log_warning "Continuing with remaining plugins..."
        }
    done <<< "$plugins"

    log_success "Claude Code plugin setup complete"
    return 0
}
```

**Step 4: Run test to verify it passes**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: PASS (14 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/claudecode.functions.bash spec/claudecode_spec.sh
git commit -m "feat(claudecode): add main plugin handler with marketplace deduplication

Process all plugins from packages.yaml with automatic marketplace management.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Integrate into setup-user Script

**Files:**
- Modify: `bin/setup-user`

**Step 1: Add source statement**

Find the section with function sourcing (around line 6-21) and add:

```bash
source "$LIB_DIR/claudecode.functions.bash"
```

After line 18 (after `source "$LIB_DIR/git.functions.bash"`).

**Step 2: Add integration call**

Find the package management section (around line 133, after `handle_packages`).

Add after line 133:

```bash
# Claude Code plugin management
if command -v claude >/dev/null 2>&1; then
    log_subsection "Claude Code Plugins"
    handle_claudecode_plugins "$DRY_RUN"
else
    log_info "Claude Code CLI not found, skipping plugin setup"
fi
```

**Step 3: Test integration manually**

Create test configuration in your actual dotfiles:

```bash
# Add to dotfiles/mrdavidlaing/packages.yaml
cat >> dotfiles/mrdavidlaing/packages.yaml << 'EOF'

# Claude Code plugins
claudecode:
  plugins:
    - superpowers@obra/superpowers-marketplace
EOF
```

**Step 4: Run setup-user in dry-run mode**

```bash
./bin/setup-user --dry-run
```

Expected: Should show dry-run messages for Claude Code plugin setup

**Step 5: Commit**

```bash
git add bin/setup-user dotfiles/mrdavidlaing/packages.yaml
git commit -m "feat(setup-user): integrate Claude Code plugin management

Add Claude Code plugin installation to setup-user workflow.
Configure superpowers marketplace for mrdavidlaing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Add Documentation to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add documentation section**

Add after the "Package Management" section (around line 66):

```markdown
### Claude Code Plugin Management

Each user and server can define Claude Code plugins and marketplaces to install in their respective `packages.yaml` files under the `claudecode` section.

**Plugin format:** `plugin-name@owner/marketplace-repo`

Example configuration:
```yaml
claudecode:
  plugins:
    - superpowers@obra/superpowers-marketplace
    - another-plugin@user/marketplace-repo
```

**How it works:**
- Plugins are specified with their marketplace source included
- Marketplaces are automatically added before plugin installation
- Same marketplace is only added once even if multiple plugins use it
- Plugins are installed/updated on every run of `setup-user`
- Requires `claude` CLI to be installed

**Platform support:** Works on all platforms where Claude Code CLI is available (Mac, Windows, Linux, WSL).
```

**Step 2: Commit documentation**

```bash
git add CLAUDE.md
git commit -m "docs: add Claude Code plugin management documentation

Document the claudecode section in packages.yaml and plugin format.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Run Full Test Suite

**Files:**
- N/A (verification only)

**Step 1: Run all tests**

```bash
shellspec
```

Expected: All tests pass (474+ examples, 4 pre-existing failures unrelated to our work)

**Step 2: Run only our new tests**

```bash
shellspec spec/claudecode_spec.sh
```

Expected: PASS (14 examples, 0 failures)

**Step 3: Verify no regressions**

Check that the failure count hasn't increased from baseline:
- Baseline: 4 failures (PowerShell formatting tests)
- Current: Should still be 4 failures

**Step 4: Test integration manually (if claude CLI available)**

```bash
./bin/setup-user --dry-run
```

Expected: Shows Claude Code plugin dry-run messages

---

## Phase 2: PowerShell Implementation

> **Note:** This phase requires a Windows machine. Create these tasks in a separate session on Windows.

### Task 9: Create PowerShell Functions

**Files:**
- Create: `lib/claudecode.functions.ps1`
- Test: `spec/powershell/claudecode.functions.Tests.ps1`

**Overview:** Mirror the bash implementation in PowerShell:
- `Extract-ClaudeCodePluginsFromYaml` - Parse YAML (reuse existing YAML functions)
- `Get-MarketplaceFromPlugin` - Extract marketplace from plugin@marketplace
- `Add-ClaudeCodeMarketplace` - Call `claude.exe plugin marketplace add`
- `Install-ClaudeCodePlugin` - Call `claude.exe plugin install`
- `Invoke-ClaudeCodePluginSetup` - Main handler (mirrors `handle_claudecode_plugins`)

**Testing:** Use Pester framework, mock `claude.exe` calls, test against real packages.yaml

### Task 10: Integrate into setup-user.ps1

**Files:**
- Modify: `bin/setup-user.ps1`
- Modify: `lib/setup-user.functions.ps1`

**Integration point:** In `Invoke-UserSetup` function, after package installation (around line 508), add:

```powershell
# Claude Code plugin management
if (Get-Command claude.exe -ErrorAction SilentlyContinue) {
    Write-Step "Claude Code Plugins"
    Invoke-ClaudeCodePluginSetup -DryRun:$DryRun
}
else {
    Write-LogInfo "Claude Code CLI not found, skipping plugin setup"
}
```

---

## Success Criteria

✅ All bash tests pass (spec/claudecode_spec.sh)
✅ Integration test in dry-run mode works
✅ Documentation updated in CLAUDE.md
✅ No regressions in existing tests
✅ Code follows existing patterns (logging, security, error handling)
✅ Bash 3.2 compatibility maintained
✅ (Phase 2) PowerShell implementation mirrors bash functionality
✅ (Phase 2) Pester tests pass

---

## Notes

- Phase 1 (Bash) can be completed on Mac/Linux
- Phase 2 (PowerShell) requires Windows machine
- Design document saved at: `docs/plans/2025-10-21-claudecode-plugin-management-design.md`
- Keep commits small and focused (one per task step when appropriate)
- Test frequently to catch issues early
