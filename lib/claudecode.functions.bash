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
