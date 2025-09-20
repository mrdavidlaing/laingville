#!/bin/sh
# Claude Code PostToolUse formatting hook
# This script formats the specific file that was just edited

# Export common PATH locations for Linux and macOS
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:/opt/local/bin:$PATH"

# Source user's shell configuration if available (POSIX-compatible)
if [ -f "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi

# Change to project directory
cd "$CLAUDE_PROJECT_DIR" || exit 1

# Check if shfmt is available
if ! command -v shfmt > /dev/null 2>&1; then
  exit 0
fi

# Read the JSON input from stdin to get the edited file
INPUT=$(cat)
EDITED_FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Only format if it's a shell script
if [ -n "$EDITED_FILE" ] && [ -f "$EDITED_FILE" ]; then
  case "$EDITED_FILE" in
    *.sh | *.bash)
      # Store original content checksum
      BEFORE_CHECKSUM=$(md5sum "$EDITED_FILE" 2> /dev/null || cksum "$EDITED_FILE" 2> /dev/null)

      # Format the file
      shfmt -w "$EDITED_FILE" 2> /dev/null

      # Check if file was actually changed
      AFTER_CHECKSUM=$(md5sum "$EDITED_FILE" 2> /dev/null || cksum "$EDITED_FILE" 2> /dev/null)

      if [ "$BEFORE_CHECKSUM" != "$AFTER_CHECKSUM" ]; then
        echo "[Formatted] $EDITED_FILE"
      fi
      ;;
  esac
fi

# Always exit successfully to not block Claude
exit 0
