#!/bin/bash
# format-files.sh
# Centralized file formatting script that handles different file types appropriately
# Can handle single files or batches of files
# Usage: ./scripts/format-files.sh [--check] [--batch] <file_path> [file_path2 ...]

set -e

# Global variables
CHECK_MODE=false
BATCH_MODE=false
QUIET_MODE=false
VERBOSE_MODE=false
FILES=()
VERSION="2.0.0"

# Function to show usage
show_usage() {
  echo "Usage: $0 [OPTIONS] <file_path> [file_path2 ...]"
  echo ""
  echo "Options:"
  echo "  -c, --check     - Check formatting without modifying files (exit 1 if changes needed)"
  echo "  -b, --batch     - (Optional) Explicitly enable batch mode (automatically enabled for multiple files)"
  echo "  -q, --quiet     - Suppress progress output"
  echo "  -v, --verbose   - Show detailed processing information"
  echo "  --version       - Show version information"
  echo "  -h, --help      - Show this help message"
  echo ""
  echo "Arguments:"
  echo "  file_path       - Path(s) to the file(s) to format"
  echo ""
  echo "Supports:"
  echo "  *.sh, *.bash (non-spec) - shfmt formatting"
  echo "  *_spec.sh              - ShellSpec formatting"
  echo ""
  echo "Examples:"
  echo "  $0 script.sh                    # Format single file"
  echo "  $0 file1.sh file2.sh           # Format multiple files"
  echo "  $0 --check script.sh           # Check single file"
  echo "  $0 --check *.sh                # Check multiple files"
}

# Format a single bash file using shfmt
format_bash_file() {
  local file_path="$1"
  local check_mode="$2"

  if ! command -v shfmt > /dev/null 2>&1; then
    echo "Error: shfmt not found. Please install shfmt to format bash files." >&2
    return 1
  fi

  if [[ "$check_mode" == "true" ]]; then
    # Check mode - exit 1 if formatting is needed
    if ! shfmt -d "$file_path" > /dev/null 2>&1; then
      echo "File needs shfmt formatting: $file_path" >&2
      return 1
    fi
  else
    # Format in place
    if [[ "$BATCH_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
      echo "Formatting bash file: $(basename "$file_path")" >&2
    fi
    shfmt -w "$file_path"
  fi

  return 0
}

# Format ShellSpec files using integrated AWK logic
format_shellspec_file() {
  local file_path="$1"
  local check_mode="$2"
  local temp_file="${file_path}.fmt-tmp$$"

  if [[ "$check_mode" == "true" ]]; then
    # Check mode - test if file would be changed by formatting
    if format_shellspec_awk "$file_path" "$temp_file"; then
      if ! diff -q "$file_path" "$temp_file" > /dev/null 2>&1; then
        echo "File needs ShellSpec formatting: $file_path" >&2
        rm -f "$temp_file"
        return 1
      fi
    fi
    rm -f "$temp_file"
    return 0
  else
    # Format in place
    if [[ "$BATCH_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
      echo "Formatting ShellSpec file: $(basename "$file_path")" >&2
    fi

    if format_shellspec_awk "$file_path" "$temp_file" && [ -s "$temp_file" ]; then
      if ! diff -q "$file_path" "$temp_file" > /dev/null 2>&1; then
        mv "$temp_file" "$file_path"
        return 0
      fi
    fi
    rm -f "$temp_file"
  fi

  return 0
}

# AWK-based ShellSpec formatting function using external script
format_shellspec_awk() {
  local input_file="$1"
  local output_file="$2"

  # Use external AWK script for better maintainability
  local script_dir="$(dirname "$(dirname "$0")")"
  local awk_script="$script_dir/lib/shellspec-formatter.awk"

  if [[ ! -f "$awk_script" ]]; then
    echo "Error: ShellSpec formatter AWK script not found: $awk_script" >&2
    return 1
  fi

  awk -f "$awk_script" "$input_file" > "$output_file"
}

# Get file type information: returns "formatter_name handler_function"
get_file_info() {
  local file_path="$1"
  local basename
  basename=$(basename "$file_path")

  case "$basename" in
    *_spec.sh)
      echo "shellspec format_shellspec_file"
      ;;
    *.sh | *.bash)
      echo "shfmt format_bash_file"
      ;;
    *)
      echo "none none"
      ;;
  esac
}

# Router function that determines file type and calls appropriate formatter
format_single_file() {
  local file_path="$1"
  local check_mode="$2"

  if [[ ! -f "$file_path" ]]; then
    echo "Error: File does not exist: $file_path" >&2
    return 1
  fi

  # Get formatter information
  local file_info formatter_name handler_function
  file_info=$(get_file_info "$file_path")
  formatter_name=$(echo "$file_info" | awk '{print $1}')
  handler_function=$(echo "$file_info" | awk '{print $2}')

  # Apply appropriate formatting
  if [[ "$handler_function" != "none" ]]; then
    "$handler_function" "$file_path" "$check_mode"
  else
    # Unsupported file type
    if [[ "$BATCH_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
      echo "No formatter available for file type: $(basename "$file_path")" >&2
    fi
    return 0
  fi
}

# Process multiple files efficiently in batch mode
format_batch_files() {
  local check_mode="$1"
  shift
  local files=("$@")

  local formatted=0
  local total=0
  local errors=0
  local changed_files=()

  if [[ "$QUIET_MODE" != "true" ]]; then
    echo "🎨 Processing ${#files[@]} files..." >&2
  fi

  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    total=$((total + 1))

    # Store file checksum before formatting (for format mode only)
    local before_checksum=""
    if [[ "$check_mode" != "true" ]]; then
      before_checksum=$(cksum "$file" 2> /dev/null | awk '{print $1}')
    fi

    # Show file being processed inline (no newline yet) unless in quiet mode
    local file_info formatter_name
    file_info=$(get_file_info "$file")
    formatter_name=$(echo "$file_info" | awk '{print $1}')
    if [[ "$QUIET_MODE" != "true" ]]; then
      printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "$formatter_name" >&2
    fi

    # Invoke separately to respect set -e
    format_single_file "$file" "$check_mode"
    result=$?

    if [[ $result -eq 0 ]]; then
      if [[ "$check_mode" != "true" ]]; then
        # Check if file actually changed
        local after_checksum=$(cksum "$file" 2> /dev/null | awk '{print $1}')
        if [[ "$before_checksum" != "$after_checksum" ]]; then
          formatted=$((formatted + 1))
          changed_files+=("$file")
          if [[ "$QUIET_MODE" != "true" ]]; then
            echo "re-formatted" >&2
          fi
        else
          if [[ "$QUIET_MODE" != "true" ]]; then
            echo "no-changes" >&2
          fi
        fi
      else
        if [[ "$QUIET_MODE" != "true" ]]; then
          echo "ok" >&2
        fi
      fi
    else
      errors=$((errors + 1))
      if [[ "$check_mode" == "true" ]]; then
        if [[ "$QUIET_MODE" != "true" ]]; then
          echo "needs-formatting" >&2
        fi
      else
        if [[ "$QUIET_MODE" != "true" ]]; then
          echo "failed" >&2
        fi
      fi
    fi
  done

  # Summary
  if [[ "$check_mode" == "true" ]]; then
    if [[ "$errors" -eq 0 ]]; then
      if [[ "$QUIET_MODE" != "true" ]]; then
        echo "✅ All $total files are properly formatted" >&2
      fi
    else
      # Always show errors, even in quiet mode
      echo "❌ $errors of $total files need formatting" >&2
      return 1
    fi
  else
    if [[ "$total" -eq 0 ]]; then
      if [[ "$QUIET_MODE" != "true" ]]; then
        echo "ℹ️  No supported files found" >&2
      fi
    elif [[ "$formatted" -eq 0 ]]; then
      if [[ "$QUIET_MODE" != "true" ]]; then
        echo "ℹ️  All $total files already properly formatted" >&2
      fi
    else
      if [[ "$QUIET_MODE" != "true" ]]; then
        echo "✅ Formatted $formatted of $total files" >&2
        if [[ ${#changed_files[@]} -gt 0 && "$VERBOSE_MODE" == "true" ]]; then
          echo "📝 Files that were formatted:" >&2
          for file in "${changed_files[@]}"; do
            echo "    $(basename "$file")" >&2
          done
        fi
      fi
    fi
  fi

  return 0
}

# Main function - argument parsing and execution
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c | --check)
        CHECK_MODE=true
        shift
        ;;
      -b | --batch)
        BATCH_MODE=true
        shift
        ;;
      -q | --quiet)
        QUIET_MODE=true
        shift
        ;;
      -v | --verbose)
        VERBOSE_MODE=true
        shift
        ;;
      --version)
        echo "format-files.sh version $VERSION"
        exit 0
        ;;
      -h | --help)
        show_usage
        exit 0
        ;;
      -*)
        echo "Unknown option: $1" >&2
        show_usage >&2
        exit 1
        ;;
      *)
        FILES+=("$1")
        shift
        ;;
    esac
  done

  # Validate arguments
  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Error: At least one file path is required" >&2
    show_usage >&2
    exit 1
  fi

  # Execute based on number of files (batch mode is now automatic for multiple files)
  if [[ ${#FILES[@]} -eq 1 ]]; then
    # Single file mode
    format_single_file "${FILES[0]}" "$CHECK_MODE"
    result=$?
    if [[ $result -eq 0 ]]; then
      if [[ "$CHECK_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
        echo "✓ Formatting complete: $(basename "${FILES[0]}")" >&2
      fi
    else
      exit 1
    fi
  else
    # Multiple files mode (batch processing)
    format_batch_files "$CHECK_MODE" "${FILES[@]}"
  fi
}

# Run main function with all arguments
main "$@"
