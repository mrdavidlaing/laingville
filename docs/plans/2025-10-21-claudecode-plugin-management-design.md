# Claude Code Plugin Management Design

**Date:** 2025-10-21
**Status:** Approved
**Implementation:** Phased (Bash first, then PowerShell)

## Overview

Extend the `setup-user` script to automatically install and update Claude Code plugins and marketplaces from configuration, ensuring consistent Claude Code environments across Mac, Windows, Linux, WSL, and Coder ephemeral environments.

## Goals

- **Consistency**: Same Claude Code plugins across all development environments
- **Automation**: Plugins install/update automatically when running `setup-user`
- **Version Control**: Track plugin configuration in git
- **Cross-Platform**: Support Mac, Windows (native), Linux, WSL, and Coder

## Configuration Format

### packages.yaml Extension

Add a new top-level `claudecode` section to `packages.yaml`:

```yaml
# Existing platform-specific sections
arch:
  pacman: [...]
  aur: [...]

windows:
  winget: [...]
  scoop: [...]

# New section - applies to all platforms
claudecode:
  plugins:
    - superpowers@obra/superpowers-marketplace
    - some-plugin@someuser/another-marketplace
```

### Format Details

- **Plugin format**: `plugin-name@owner/marketplace-repo`
- **Self-documenting**: Each entry explicitly shows its marketplace source
- **Order-independent**: Script extracts marketplaces from plugin entries
- **Idempotent**: Same marketplace added only once even if multiple plugins reference it

## Architecture

### Imperative Script Approach

Following existing codebase patterns with simple, straightforward bash/PowerShell functions that:
1. Parse `packages.yaml` to extract plugin list
2. For each plugin, extract marketplace and ensure it's added
3. Install/update each plugin using `claude` CLI

### Code Organization

**Bash Implementation:**
- `lib/claudecode.functions.bash` - Core functions
  - `handle_claudecode_plugins()` - Main entry point
  - `extract_marketplace_from_plugin()` - Parse `plugin@marketplace` format
  - `ensure_marketplace_added()` - Idempotently add marketplace
  - `install_or_update_plugin()` - Install/update individual plugin
  - `extract_claudecode_plugins_from_yaml()` - YAML parsing

**PowerShell Implementation:**
- `lib/claudecode.functions.ps1` - Core functions (mirrors bash)
  - Same function names (PowerShell naming conventions)
  - Same behavior and error handling
  - Uses `claude.exe` instead of `claude`

**Integration Points:**
- `bin/setup-user` (bash) - Add call to `handle_claudecode_plugins()`
- `bin/setup-user.ps1` (PowerShell) - Add call to `Handle-ClaudeCodePlugins`

### Component Interaction

```
setup-user
    ↓
handle_claudecode_plugins()
    ↓
extract_claudecode_plugins_from_yaml()
    ↓
for each plugin:
    ↓
    extract_marketplace_from_plugin()
    ↓
    ensure_marketplace_added()  ← (idempotent, deduplicated)
    ↓
    install_or_update_plugin()
```

## Implementation Details

### CLI Commands

Leveraging the official `claude` CLI:

```bash
# Add marketplace (idempotent)
claude plugin marketplace add obra/superpowers-marketplace

# Install/update plugin
claude plugin install superpowers@obra/superpowers-marketplace

# Update all marketplaces (optional future enhancement)
claude plugin marketplace update
```

### Marketplace Deduplication

Track seen marketplaces using space-separated string (bash 3.2 compatible):

```bash
seen_marketplaces=""
for plugin in "${plugins[@]}"; do
    marketplace=$(extract_marketplace_from_plugin "$plugin")
    if ! echo "$seen_marketplaces" | grep -q " $marketplace "; then
        ensure_marketplace_added "$marketplace"
        seen_marketplaces="$seen_marketplaces $marketplace "
    fi
done
```

### Update Behavior

**Always update** - Every run of `setup-user` will:
1. Add any missing marketplaces (idempotent)
2. Install missing plugins OR update existing ones
3. Ensures all environments stay current

### Error Handling

- **Missing `claude` CLI**: Log info message, skip plugin setup gracefully
- **Invalid plugin format**: Log warning, continue with remaining plugins
- **Marketplace add failure**: Log error, continue with remaining plugins
- **Plugin install failure**: Log error, continue with remaining plugins
- **Security validation**: Validate marketplace/plugin names before passing to shell

### Dry-Run Support

Using existing `log_dry_run` pattern:

```bash
if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would add marketplace: $marketplace"
    log_dry_run "Would install plugin: $plugin"
else
    claude plugin marketplace add "$marketplace"
    claude plugin install "$plugin"
fi
```

### Logging

Using standard logging helpers for consistent output:

**Bash:**
- `log_subsection "Claude Code Plugins"`
- `log_info "Adding marketplace: $marketplace"`
- `log_success "Installed plugin: $plugin"`
- `log_warning "Plugin format invalid: $plugin"`
- `log_error "Failed to install plugin: $plugin"`
- `log_dry_run "Would add marketplace: $marketplace"`

**PowerShell:**
- `Write-Step "Claude Code Plugins"`
- `Write-LogInfo "Adding marketplace: $marketplace"`
- `Write-LogSuccess "Installed plugin: $plugin"`
- `Write-LogWarning "Plugin format invalid: $plugin"`
- `Write-LogError "Failed to install plugin: $plugin"`

### Security Validation

Reuse existing security functions:

```bash
# Validate marketplace name (owner/repo format)
if ! is_safe_filename "$marketplace"; then
    log_error "Invalid marketplace name: $marketplace"
    continue
fi
```

### Bash 3.2 Compatibility

**Avoid:**
- Associative arrays (`declare -A`)
- Case modification (`${var^^}`)
- Globstar (`**/*.sh`)

**Use instead:**
- Parallel arrays or space-separated strings
- `tr` for case conversion
- `find` for recursive searches

## Testing Strategy

### Bash Tests (ShellSpec)

**Test file:** `spec/claudecode_spec.sh`

Coverage:
- Parse plugin format correctly (extract marketplace from `plugin@marketplace`)
- Handle plugins from same marketplace (deduplicate marketplace additions)
- Validate plugin format (reject entries without `@`)
- Security validation (reject unsafe marketplace/plugin names)
- Dry-run mode shows correct messages without executing commands
- Error handling when `claude` binary not found
- YAML extraction reads `claudecode.plugins` list correctly
- Empty/missing `claudecode` section handled gracefully
- Bash 3.2 compatibility (no forbidden features)

### PowerShell Tests (Pester)

**Test file:** `spec/powershell/claudecode.functions.Tests.ps1`

Coverage (mirrors bash tests):
- Same functional tests as bash version
- PowerShell-specific syntax and patterns
- Validates `claude.exe` command construction
- Tests against real `packages.yaml` files

### CI Integration

Both test suites run automatically in GitHub Actions:
- ShellSpec tests on Linux/Mac runners
- Pester tests on Windows runners
- All tests must pass for CI success

## Implementation Phases

### Phase 1: Bash Implementation

**Can implement on current Mac environment**

Tasks:
1. Create `lib/claudecode.functions.bash`
2. Implement core functions
3. Add integration to `bin/setup-user`
4. Create `spec/claudecode_spec.sh`
5. Test locally on Mac
6. Validate on WSL/Linux if available

**Deliverable:** Working bash implementation with tests

### Phase 2: PowerShell Implementation

**Requires Windows machine session**

Tasks:
1. Create `lib/claudecode.functions.ps1`
2. Mirror bash functionality in PowerShell
3. Add integration to `bin/setup-user.ps1`
4. Create `spec/powershell/claudecode.functions.Tests.ps1`
5. Test on native Windows

**Deliverable:** Working PowerShell implementation with tests

## Example Usage

### Configuration

User adds to `dotfiles/mrdavidlaing/packages.yaml`:

```yaml
claudecode:
  plugins:
    - superpowers@obra/superpowers-marketplace
```

### Execution

```bash
# Mac/Linux/WSL
./bin/setup-user

# Output:
# ════════════════════════════════════
# Claude Code Plugins
# ════════════════════════════════════
# ✓ Adding marketplace: obra/superpowers-marketplace
# ✓ Installing plugin: superpowers@obra/superpowers-marketplace
```

### Dry-Run

```bash
./bin/setup-user --dry-run

# [DRY RUN] Would add marketplace: obra/superpowers-marketplace
# [DRY RUN] Would install plugin: superpowers@obra/superpowers-marketplace
```

## Future Enhancements

Possible future additions (not in scope for initial implementation):

- Platform-specific plugins (if needed): `claudecode.macos.plugins`, `claudecode.windows.plugins`
- Plugin version pinning: `plugin@marketplace#v1.2.3`
- Disable/enable plugin management via flag
- Plugin removal support (currently only adds/updates)
- Settings synchronization (in addition to plugins)

## Success Criteria

✓ Running `setup-user` installs/updates Claude Code plugins
✓ New machines get plugins automatically
✓ Configuration tracked in git
✓ Works on Mac, Windows, Arch, WSL, and Coder
✓ Dry-run mode works correctly
✓ Comprehensive test coverage
✓ Error handling prevents setup-user failures
✓ Follows existing codebase patterns and conventions
