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
  echo "  *_spec.sh               - ShellSpec formatting"
  echo "  *.ps1                   - PowerShell formatting (requires pwsh/PowerShell 7+)"
  echo ""
  echo "Examples:"
  echo "  $0 script.sh                    # Format single file"
  echo "  $0 file1.sh file2.sh           # Format multiple files"
  echo "  $0 --check script.sh           # Check single file"
  echo "  $0 --check *.sh                # Check multiple files"
}

# === Line Ending Utility Functions ===

# Pre-process: Convert any line endings to LF temporarily
# This normalizes files with mixed line endings so formatters can process them
normalize_to_lf() {
  local file="$1"
  # Combined sed operations for better performance
  sed -i -e 's/[ \t]*$//' -e 's/\r$//' "$file"
}

# Post-process: Ensure exactly one LF at end (for bash/shell files)
ensure_single_newline_lf() {
  local file="$1"
  # Use printf to ensure exactly one trailing LF
  printf '%s\n' "$(cat "$file")" > "$file"
}

# Post-process: Ensure exactly one CRLF at end (for PowerShell files)
ensure_single_newline_crlf() {
  local file="$1"
  local ps_file_path="$2" # Windows path if needed for WSL
  local pwsh_cmd="$3"

  # Use PowerShell to handle all line ending and whitespace logic
  # This ensures consistent CRLF behavior across all platforms
  $pwsh_cmd -NoProfile -Command "
    \$content = [System.IO.File]::ReadAllText('$ps_file_path')
    # Remove trailing whitespace from each line (but preserve line endings temporarily)
    \$content = \$content -replace '[ \t]+(\r?\n)', '\$1'
    # Convert all line endings to CRLF (normalize LF to CRLF)
    \$content = \$content -replace '\r?\n', \"\`r\`n\"
    # Ensure exactly one CRLF at end of file (remove any extra trailing newlines)
    \$content = \$content -replace '(\r\n)+$', \"\`r\`n\"
    # Write with explicit UTF8 encoding without BOM
    \$utf8NoBom = New-Object System.Text.UTF8Encoding(\$false)
    [System.IO.File]::WriteAllText('$ps_file_path', \$content, \$utf8NoBom)
  " 2> /dev/null
}

# === File Formatting Functions ===

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

# Batch format multiple bash files using shfmt (shfmt supports multiple files natively)
batch_format_shfmt_files() {
  local check_mode="$1"
  shift
  local files=("$@")

  [[ ${#files[@]} -eq 0 ]] && return 0

  if ! command -v shfmt > /dev/null 2>&1; then
    echo "Error: shfmt not found. Please install shfmt to format bash files." >&2
    return 1
  fi

  if [[ "$check_mode" == "true" ]]; then
    # Check mode - shfmt -d returns non-zero if files need formatting
    if ! shfmt -d "${files[@]}" > /dev/null 2>&1; then
      return 1
    fi
  else
    # Format mode - shfmt can format multiple files at once
    shfmt -w "${files[@]}"
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
    # shellcheck disable=SC2310  # Function invoked in if condition, set -e disabled intentionally
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

    # shellcheck disable=SC2310  # Function invoked in if condition, set -e disabled intentionally
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

# Format a single PowerShell file using pwsh
format_powershell_file() {
  local file_path="$1"
  local check_mode="$2"

  # Check if pwsh is available (check both Unix and Windows paths for WSL compatibility)
  local pwsh_cmd=""
  if command -v pwsh > /dev/null 2>&1; then
    pwsh_cmd="pwsh"
  elif command -v pwsh.exe > /dev/null 2>&1; then
    pwsh_cmd="pwsh.exe"
  else
    if [[ "$BATCH_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
      echo "ℹ️  Skipping PowerShell formatting: pwsh not available on this platform" >&2
      echo "    Install PowerShell 7+ to enable .ps1 file formatting" >&2
    fi
    return 0
  fi

  # Check if PowerShell formatting is available and functional
  # Try a simple formatting test to ensure everything works
  if ! $pwsh_cmd -NoProfile -Command "
    try {
      \$testCode = 'Write-Host test'
      \$formatted = Invoke-Formatter -ScriptDefinition \$testCode -ErrorAction Stop
      if (\$formatted) {
        exit 0
      } else {
        exit 1
      }
    } catch {
      exit 1
    }
  " > /dev/null 2>&1; then
    if [[ "$BATCH_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
      echo "ℹ️  Skipping PowerShell formatting: PowerShell formatting not functional" >&2
      echo "    Install/update PSScriptAnalyzer module to enable .ps1 file formatting" >&2
    fi
    return 0
  fi

  if [[ "$check_mode" == "true" ]]; then
    # Convert Unix path to Windows path if we're in WSL
    local ps_file_path="$file_path"
    if [[ "$pwsh_cmd" == "pwsh.exe" ]] && command -v wslpath > /dev/null 2>&1; then
      ps_file_path=$(wslpath -w "$file_path")
    fi

    # Check mode - verify if file needs formatting
    # Use PowerShell's parser to check for syntax issues that formatting would fix
    if $pwsh_cmd -NoProfile -Command "
      try {
        [System.Management.Automation.Language.Parser]::ParseFile('$ps_file_path', [ref]\$null, [ref]\$null) | Out-Null
        exit 0
      } catch {
        exit 1
      }
    " 2> /dev/null; then
      # File parses correctly, no formatting needed
      return 0
    else
      echo "File needs PowerShell formatting: $file_path" >&2
      return 1
    fi
  else
    # Format mode - apply formatting
    if [[ "$BATCH_MODE" != "true" && "$QUIET_MODE" != "true" ]]; then
      echo "Formatting PowerShell file: $(basename "$file_path")" >&2
    fi

    # Convert Unix path to Windows path if we're in WSL
    local ps_file_path="$file_path"
    if [[ "$pwsh_cmd" == "pwsh.exe" ]] && command -v wslpath > /dev/null 2>&1; then
      ps_file_path=$(wslpath -w "$file_path")
    fi

    # Pre-process: normalize to LF temporarily to avoid mixed line ending errors
    normalize_to_lf "$file_path"

    # Use PowerShell's built-in formatting capabilities
    if $pwsh_cmd -NoProfile -Command "
      try {
        \$content = Get-Content '$ps_file_path' -Raw
        \$formatted = Invoke-Formatter -ScriptDefinition \$content
        # Write back to file as UTF8 without BOM
        \$utf8NoBom = New-Object System.Text.UTF8Encoding(\$false)
        [System.IO.File]::WriteAllText('$ps_file_path', \$formatted, \$utf8NoBom)
      } catch {
        Write-Error \"Failed to format PowerShell file: \$_\"
        exit 1
      }
    " 2> /dev/null; then
      # Post-process: Convert all line endings to CRLF and ensure exactly one at end
      ensure_single_newline_crlf "$file_path" "$ps_file_path" "$pwsh_cmd"
      return 0
    else
      echo "Error: Failed to format PowerShell file: $file_path" >&2
      return 1
    fi
  fi
}

# Batch format multiple PowerShell files in a single pwsh invocation
batch_format_powershell_files() {
  local check_mode="$1"
  shift
  local files=("$@")

  [[ ${#files[@]} -eq 0 ]] && return 0

  # Check if pwsh is available
  local pwsh_cmd=""
  if command -v pwsh > /dev/null 2>&1; then
    pwsh_cmd="pwsh"
  elif command -v pwsh.exe > /dev/null 2>&1; then
    pwsh_cmd="pwsh.exe"
  else
    return 0
  fi

  # Check if PowerShell formatting is functional (do once for all files)
  if ! $pwsh_cmd -NoProfile -Command "
    try {
      \$testCode = 'Write-Host test'
      \$formatted = Invoke-Formatter -ScriptDefinition \$testCode -ErrorAction Stop
      exit 0
    } catch {
      exit 1
    }
  " > /dev/null 2>&1; then
    return 0
  fi

  # Build PowerShell script to process all files
  local ps_script=""
  local file_list=""

  # Convert file paths for WSL if needed
  for file in "${files[@]}"; do
    local ps_file_path="$file"
    if [[ "$pwsh_cmd" == "pwsh.exe" ]] && command -v wslpath > /dev/null 2>&1; then
      ps_file_path=$(wslpath -w "$file")
    fi
    file_list="${file_list}'${ps_file_path}',"
  done
  file_list="${file_list%,}" # Remove trailing comma

  if [[ "$check_mode" == "true" ]]; then
    # Check mode - just verify syntax
    ps_script="
      \$files = @($file_list)
      \$errors = 0
      foreach (\$file in \$files) {
        try {
          [System.Management.Automation.Language.Parser]::ParseFile(\$file, [ref]\$null, [ref]\$null) | Out-Null
        } catch {
          \$errors++
        }
      }
      exit \$errors
    "
  else
    # Format mode - first normalize line endings, then format
    if [[ "$check_mode" != "true" ]]; then
      # Pre-process files to normalize line endings before PowerShell formatting
      for file in "${files[@]}"; do
        normalize_to_lf "$file"
      done
    fi

    ps_script="
      \$files = @($file_list)
      \$errors = 0
      foreach (\$file in \$files) {
        try {
          \$content = Get-Content \$file -Raw
          \$formatted = Invoke-Formatter -ScriptDefinition \$content
          # Write back to file as UTF8 without BOM
          \$utf8NoBom = New-Object System.Text.UTF8Encoding(\$false)
          [System.IO.File]::WriteAllText(\$file, \$formatted, \$utf8NoBom)
        } catch {
          Write-Error \"Failed to format \$file\"
          \$errors++
        }
      }
      exit \$errors
    "
  fi

  # Execute PowerShell script
  if $pwsh_cmd -NoProfile -Command "$ps_script" 2> /dev/null; then
    if [[ "$check_mode" != "true" ]]; then
      # Post-process files: Out-File adds CRLF, ensure proper ending
      for file in "${files[@]}"; do
        # Convert path for WSL if needed
        local ps_file_path="$file"
        if [[ "$pwsh_cmd" == "pwsh.exe" ]] && command -v wslpath > /dev/null 2>&1; then
          ps_file_path=$(wslpath -w "$file")
        fi

        ensure_single_newline_crlf "$file" "$ps_file_path" "$pwsh_cmd"
      done
    fi
    return 0
  else
    return 1
  fi
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
    *.ps1)
      echo "powershell format_powershell_file"
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
  # shellcheck disable=SC2311  # Function in command substitution, set -e disabled intentionally
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

  # Group files by formatter type for batch processing
  local shfmt_files=()
  local shellspec_files=()
  local powershell_files=()
  local other_files=()

  # Store checksums before formatting (for format mode only)
  # Using parallel arrays for bash 3.2 compatibility
  local checksum_files=()
  local checksum_values=()

  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    total=$((total + 1))

    # Store checksum if in format mode
    if [[ "$check_mode" != "true" ]]; then
      checksum_files+=("$file")
      checksum_values+=("$(cksum "$file" 2> /dev/null | awk '{print $1}')")
    fi

    # Group by formatter type
    local file_info formatter_name
    # shellcheck disable=SC2311
    file_info=$(get_file_info "$file")
    formatter_name=$(echo "$file_info" | awk '{print $1}')

    case "$formatter_name" in
      shfmt)
        shfmt_files+=("$file")
        ;;
      shellspec)
        shellspec_files+=("$file")
        ;;
      powershell)
        powershell_files+=("$file")
        ;;
      *)
        other_files+=("$file")
        ;;
    esac
  done

  # Process shfmt files in batch
  if [[ ${#shfmt_files[@]} -gt 0 ]]; then
    if [[ "$QUIET_MODE" != "true" ]]; then
      echo "  📦 Batch formatting ${#shfmt_files[@]} bash files with shfmt..." >&2
    fi
    # shellcheck disable=SC2310
    if batch_format_shfmt_files "$check_mode" "${shfmt_files[@]}"; then
      # Process each file for reporting
      for file in "${shfmt_files[@]}"; do
        if [[ "$QUIET_MODE" != "true" ]]; then
          printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "shfmt" >&2
        fi

        if [[ "$check_mode" != "true" ]]; then
          local after_checksum=$(cksum "$file" 2> /dev/null | awk '{print $1}')
          # Find before checksum from parallel arrays
          local before_checksum=""
          for ((i = 0; i < ${#checksum_files[@]}; i++)); do
            if [[ "${checksum_files[$i]}" == "$file" ]]; then
              before_checksum="${checksum_values[$i]}"
              break
            fi
          done
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
      done
    else
      errors=$((errors + ${#shfmt_files[@]}))
      for file in "${shfmt_files[@]}"; do
        if [[ "$QUIET_MODE" != "true" ]]; then
          printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "shfmt" >&2
          if [[ "$check_mode" == "true" ]]; then
            echo "needs-formatting" >&2
          else
            echo "failed" >&2
          fi
        fi
      done
    fi
  fi

  # Process PowerShell files in batch
  if [[ ${#powershell_files[@]} -gt 0 ]]; then
    if [[ "$QUIET_MODE" != "true" ]]; then
      echo "  📦 Batch formatting ${#powershell_files[@]} PowerShell files..." >&2
    fi
    # shellcheck disable=SC2310
    if batch_format_powershell_files "$check_mode" "${powershell_files[@]}"; then
      # Process each file for reporting
      for file in "${powershell_files[@]}"; do
        if [[ "$QUIET_MODE" != "true" ]]; then
          printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "powershell" >&2
        fi

        if [[ "$check_mode" != "true" ]]; then
          local after_checksum=$(cksum "$file" 2> /dev/null | awk '{print $1}')
          # Find before checksum from parallel arrays
          local before_checksum=""
          for ((i = 0; i < ${#checksum_files[@]}; i++)); do
            if [[ "${checksum_files[$i]}" == "$file" ]]; then
              before_checksum="${checksum_values[$i]}"
              break
            fi
          done
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
      done
    else
      errors=$((errors + ${#powershell_files[@]}))
      for file in "${powershell_files[@]}"; do
        if [[ "$QUIET_MODE" != "true" ]]; then
          printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "powershell" >&2
          if [[ "$check_mode" == "true" ]]; then
            echo "needs-formatting" >&2
          else
            echo "failed" >&2
          fi
        fi
      done
    fi
  fi

  # Process ShellSpec files individually (AWK is already efficient)
  for file in "${shellspec_files[@]}"; do
    if [[ "$QUIET_MODE" != "true" ]]; then
      printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "shellspec" >&2
    fi

    # shellcheck disable=SC2310
    if format_single_file "$file" "$check_mode"; then
      result=0
    else
      result=$?
    fi

    if [[ $result -eq 0 ]]; then
      if [[ "$check_mode" != "true" ]]; then
        local after_checksum=$(cksum "$file" 2> /dev/null | awk '{print $1}')
        # Find before checksum from parallel arrays
        local before_checksum=""
        for ((i = 0; i < ${#checksum_files[@]}; i++)); do
          if [[ "${checksum_files[$i]}" == "$file" ]]; then
            before_checksum="${checksum_values[$i]}"
            break
          fi
        done
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
      if [[ "$QUIET_MODE" != "true" ]]; then
        if [[ "$check_mode" == "true" ]]; then
          echo "needs-formatting" >&2
        else
          echo "failed" >&2
        fi
      fi
    fi
  done

  # Process other files individually
  for file in "${other_files[@]}"; do
    local file_info formatter_name
    # shellcheck disable=SC2311
    file_info=$(get_file_info "$file")
    formatter_name=$(echo "$file_info" | awk '{print $1}')

    if [[ "$QUIET_MODE" != "true" ]]; then
      printf "  formatting %-40s [%-10s] ... " "$(basename "$file")" "$formatter_name" >&2
    fi

    # shellcheck disable=SC2310
    if format_single_file "$file" "$check_mode"; then
      result=0
    else
      result=$?
    fi

    if [[ $result -eq 0 ]]; then
      if [[ "$check_mode" != "true" ]]; then
        local after_checksum=$(cksum "$file" 2> /dev/null | awk '{print $1}')
        # Find before checksum from parallel arrays
        local before_checksum=""
        for ((i = 0; i < ${#checksum_files[@]}; i++)); do
          if [[ "${checksum_files[$i]}" == "$file" ]]; then
            before_checksum="${checksum_values[$i]}"
            break
          fi
        done
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
      if [[ "$QUIET_MODE" != "true" ]]; then
        if [[ "$check_mode" == "true" ]]; then
          echo "needs-formatting" >&2
        else
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
