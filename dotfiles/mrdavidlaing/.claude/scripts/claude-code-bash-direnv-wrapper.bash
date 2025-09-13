#!/bin/bash

# Claude Code Bash Direnv PreToolUse Hook
# This script runs before Bash commands to ensure direnv is allowed
# for directories with .envrc files

set -euo pipefail

# Enable debug mode if CLAUDE_CODE_DIRENV_DEBUG is set
DEBUG=${CLAUDE_CODE_DIRENV_DEBUG:-0}

debug_log() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "[claude-code-direnv-hook] $*" >&2
  fi
}

# Read JSON input from stdin
if [ -t 0 ]; then
  debug_log "No stdin input (running in terminal for testing)"
  exit 0
fi

# Read JSON from stdin using bash built-in (no cat needed)
IFS= read -r -d '' JSON_INPUT || true
debug_log "Received JSON: $JSON_INPUT"

# Check if jq is available
if ! command -v jq > /dev/null 2>&1; then
  debug_log "jq not found, cannot parse JSON input"
  exit 0
fi

# Extract the working directory from the JSON
WORKING_DIR=$(echo "$JSON_INPUT" | jq -r '.tool_input.working_directory // empty')

if [ -z "$WORKING_DIR" ]; then
  debug_log "No working_directory found in JSON"
  exit 0
fi

debug_log "Working directory: $WORKING_DIR"

# Check if direnv is available
if ! command -v direnv > /dev/null 2>&1; then
  debug_log "direnv not found in PATH"
  exit 0
fi

# Function to find the nearest .envrc file
find_envrc_dir() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.envrc" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# Check for .envrc in the working directory or parent directories
# shellcheck disable=SC2310 # We intentionally check function success in if statement
if ENVRC_DIR=$(find_envrc_dir "$WORKING_DIR"); then
  debug_log "Found .envrc in: $ENVRC_DIR"

  # Allow direnv for this directory
  debug_log "Running: direnv allow '$ENVRC_DIR'"
  if direnv allow "$ENVRC_DIR" 2>&1 | while read -r line; do debug_log "direnv: $line"; done; then
    debug_log "Successfully allowed direnv for $ENVRC_DIR"
  else
    debug_log "Failed to allow direnv for $ENVRC_DIR (may already be allowed)"
  fi
else
  debug_log "No .envrc found in $WORKING_DIR or parent directories"
fi

# Always exit 0 to allow the command to proceed
exit 0
