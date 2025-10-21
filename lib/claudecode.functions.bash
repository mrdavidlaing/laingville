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

    # Check for plugins subsection (must come before top-level exit check)
    if [ "$in_claudecode" = true ] && [ "$trimmed_line" = "plugins:" ]; then
      in_plugins=true
      continue
    fi

    # Exit claudecode section if we hit another top-level key (no leading whitespace in original line)
    if [ "$in_claudecode" = true ] && [ "$line" = "$trimmed_line" ] && echo "$trimmed_line" | grep -q "^[a-z].*:$"; then
      in_claudecode=false
      in_plugins=false
      continue
    fi

    # Exit plugins subsection if we hit another subsection within claudecode
    if [ "$in_plugins" = true ] && [ "$line" != "$trimmed_line" ] && echo "$trimmed_line" | grep -q "^[a-z].*:$"; then
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

  if claude plugin marketplace add "$marketplace" > /dev/null 2>&1; then
    log_success "Marketplace added: $marketplace"
    return 0
  else
    log_warning "Failed to add marketplace: $marketplace (may already exist)"
    return 0 # Not a fatal error - marketplace might already exist
  fi
}

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

  if claude plugin install "$plugin" > /dev/null 2>&1; then
    log_success "Plugin installed: $plugin"
    return 0
  else
    log_error "Failed to install plugin: $plugin"
    return 1
  fi
}
