#!/usr/bin/env bash
#
# Generate Claude Code settings.json from template
#
# This script generates a machine-specific settings.json from templates
# based on the current platform and bash availability.
#
# If ~/.claude/settings.json already exists, shows a diff instead of overwriting.
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source required functions
LIB_DIR="$PROJECT_ROOT/lib"
source "$LIB_DIR/logging.functions.bash"
source "$LIB_DIR/platform.functions.bash"

# Configuration
TEMPLATE_FILE="$SCRIPT_DIR/settings.template.json"
WINDOWS_TEMPLATE="$SCRIPT_DIR/settings.windows.json"
TARGET_DIR="$HOME/.claude"
TARGET_FILE="$TARGET_DIR/settings.json"

# Check if template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log_error "Template not found: $TEMPLATE_FILE"
  exit 1
fi

log_info "Generating Claude Code settings from template..."

# Detect platform
PLATFORM="${PLATFORM:-$(detect_platform)}"

# Choose template based on platform and bash availability
SOURCE_TEMPLATE="$TEMPLATE_FILE"
if [[ "$PLATFORM" = "windows" ]]; then
  # Check if bash is in system PATH
  if ! command -v bash >/dev/null 2>&1; then
    if [[ -f "$WINDOWS_TEMPLATE" ]]; then
      SOURCE_TEMPLATE="$WINDOWS_TEMPLATE"
      log_info "Using Windows-specific template (bash not in PATH)"
    else
      log_warning "bash not in PATH and no Windows template found"
    fi
  fi
fi

# Get current username for template substitution
USERNAME="${USER:-${USERNAME:-$(whoami)}}"

# Generate settings to temporary file
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

if command -v sed >/dev/null 2>&1; then
  sed "s/{{USERNAME}}/$USERNAME/g" "$SOURCE_TEMPLATE" > "$TEMP_FILE"
else
  # Fallback: just copy without substitution
  cp "$SOURCE_TEMPLATE" "$TEMP_FILE"
  log_warning "sed not available, copied template without username substitution"
fi

# Ensure target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
  mkdir -p "$TARGET_DIR"
fi

# Check if target file already exists
if [[ -f "$TARGET_FILE" ]]; then
  # Compare with what would be generated
  if diff -q "$TEMP_FILE" "$TARGET_FILE" >/dev/null 2>&1; then
    log_success "Settings file is already up to date"
    exit 0
  else
    log_warning "Settings file exists and differs from template"
    echo ""
    echo "Differences (template → current):"
    echo "-----------------------------------"
    # Show diff (try color first, fall back to plain)
    if command -v diff >/dev/null 2>&1; then
      diff -u "$TEMP_FILE" "$TARGET_FILE" || true
    fi
    echo ""
    log_info "To update settings, run: rm $TARGET_FILE && $0"
    exit 0
  fi
fi

# File doesn't exist - create it
cp "$TEMP_FILE" "$TARGET_FILE"
log_success "Created $TARGET_FILE"

log_success "Claude Code settings generation complete!"
