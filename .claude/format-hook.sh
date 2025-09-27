#!/bin/sh
# Claude Code PostToolUse formatting hook
# This script formats the specific file that was just edited using the centralized formatter

# Export common PATH locations for Linux and macOS
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:/opt/local/bin:$PATH"

# Source user's shell configuration if available (POSIX-compatible)
if [ -f "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi

# Change to project directory
cd "$CLAUDE_PROJECT_DIR" || exit 1

# Check if the centralized formatter exists
if [ ! -x "./scripts/format-files.sh" ]; then
  echo "Error: format-files.sh script not found or not executable at: $(pwd)/scripts/format-files.sh" >&2
  echo "       Please ensure the format-files.sh script exists and is executable" >&2
  exit 1
fi

# Read the JSON input from stdin to get the edited file
INPUT=$(cat)
EDITED_FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Only format if the file exists and is a supported type
# Skip fixture files as they are test data
if [ -n "$EDITED_FILE" ] && [ -f "$EDITED_FILE" ]; then
  case "$EDITED_FILE" in
    spec/fixtures/*)
      # Skip fixture files - they are test data
      ;;
    *.sh | *.bash | *.ps1)
      # Store original content checksum
      BEFORE_CHECKSUM=$(cksum "$EDITED_FILE" 2> /dev/null | awk '{print $1}')

      # Use the centralized formatter in single-file mode
      if ./scripts/format-files.sh "$EDITED_FILE" 2>&1; then
        # Check if file was actually changed
        AFTER_CHECKSUM=$(cksum "$EDITED_FILE" 2> /dev/null | awk '{print $1}')

        if [ "$BEFORE_CHECKSUM" != "$AFTER_CHECKSUM" ]; then
          echo "[Formatted] $EDITED_FILE"
        fi
      else
        echo "[Format Error] Failed to format $EDITED_FILE - see output above"
      fi
      ;;
  esac
fi

# Always exit successfully to not block Claude
exit 0
