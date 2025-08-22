#!/bin/bash

# format-shellspec.sh
# Formats ShellSpec test files with proper indentation
# Part of the Laingville project formatting pipeline

set -euo pipefail

# Find all ShellSpec test files
spec_files=$(find spec -name "*_spec.sh" -type f 2> /dev/null || true)

if [[ -z "$spec_files" ]]; then
  echo "No ShellSpec files found to format"
  exit 0
fi

format_shellspec_file() {
  local file="$1"
  local temp_file
  temp_file=$(mktemp)
  local indent=0
  local formatted=0

  while IFS= read -r line; do
    # Skip empty lines and comments (preserve as-is)
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      echo "$line" >> "$temp_file"
      continue
    fi

    # Handle End statements (decrease indent before printing)
    if [[ "$line" =~ ^[[:space:]]*End[[:space:]]*$ ]]; then
      ((indent -= 2))
      if [[ $indent -lt 0 ]]; then
        indent=0
      fi
      printf "%*s%s\n" "$indent" "" "End" >> "$temp_file"
      continue
    fi

    # Remove existing indentation
    line=$(echo "$line" | sed 's/^[[:space:]]*//')

    # Print line with current indentation
    printf "%*s%s\n" "$indent" "" "$line" >> "$temp_file"

    # Increase indent after Describe/It statements
    if [[ "$line" =~ ^(Describe|It)[[:space:]] ]]; then
      ((indent += 2))
    fi

  done < "$file"

  # Check if file changed
  if ! cmp -s "$file" "$temp_file"; then
    mv "$temp_file" "$file"
    echo "  ✓ Formatted $file"
    formatted=1
  else
    rm "$temp_file"
  fi

  return $formatted
}

echo "Formatting ShellSpec test files..."

total_formatted=0
file_count=0

for file in $spec_files; do
  ((file_count++))
  if format_shellspec_file "$file"; then
    ((total_formatted++))
  fi
done

if [[ $total_formatted -eq 0 ]]; then
  echo "  All $file_count ShellSpec files already properly formatted"
else
  echo "  Formatted $total_formatted of $file_count ShellSpec files"
fi
