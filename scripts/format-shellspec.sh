#!/bin/bash
# format-shellspec.sh
# Formats ShellSpec test files with proper indentation

echo "🎨 Formatting ShellSpec tests..."

# Use awk for robust text processing
format_file() {
  local file="$1"
  local temp_file="${file}.tmp"

  awk '
  BEGIN { 
    indent = 0
    in_heredoc = 0
    heredoc_marker = ""
    in_quoted_string = 0
  }
  
  # Detect heredoc start
  /<<[[:space:]]*['\''"]?[A-Za-z_][A-Za-z0-9_]*['\''"]?/ {
    if (!in_heredoc && match($0, /<<[[:space:]]*['\''"]?([A-Za-z_][A-Za-z0-9_]*)['\''"]?/, arr)) {
      heredoc_marker = arr[1]
      in_heredoc = 1
    }
  }
  
  # Pass through heredoc content unchanged
  in_heredoc == 1 {
    print $0
    if ($0 == heredoc_marker) {
      in_heredoc = 0
      heredoc_marker = ""
    }
    next
  }
  
  # Detect multi-line quoted strings (echo "content...)
  /echo[[:space:]]+"/ && !/echo[[:space:]]+"[^"]*"[[:space:]]*$/ {
    in_quoted_string = 1
  }
  
  # Pass through quoted string content unchanged
  in_quoted_string == 1 {
    print $0
    if (/"[[:space:]]*>/) {
      in_quoted_string = 0
    }
    next
  }
  
  # Pass through empty lines and comments unchanged
  /^[[:space:]]*$/ || /^[[:space:]]*#/ {
    print $0
    next
  }
  
  # Remove leading whitespace to get the content
  {
    content = $0
    sub(/^[[:space:]]+/, "", content)
  }
  
  # Handle End keyword - decrease indent before printing
  content ~ /^End[[:space:]]*$/ {
    if (indent > 0) indent -= 2
    printf "%*sEnd\n", indent, ""
    next
  }
  
  # Print line with current indentation
  {
    if (length(content) > 0) {
      printf "%*s%s\n", indent, "", content
    } else {
      print ""
    }
  }
  
  # Increase indent after block-opening keywords
  content ~ /^(Describe|Context|It|Specify|Example|Before|After|BeforeAll|AfterAll)[[:space:]]/ {
    indent += 2
  }
  ' "$file" > "$temp_file"

  # Only update if file changed
  if ! cmp -s "$file" "$temp_file"; then
    mv "$temp_file" "$file"
    return 0
  else
    rm -f "$temp_file"
    return 1
  fi
}

# Process all spec files
formatted=0
total=0

for file in spec/*_spec.sh; do
  [ -f "$file" ] || continue
  total=$((total + 1))

  echo -n "  Formatting $(basename "$file")... "
  if format_file "$file"; then
    echo "✓"
    formatted=$((formatted + 1))
  else
    echo "already formatted"
  fi
done

# Summary
if [ $total -eq 0 ]; then
  echo "  No ShellSpec files found"
elif [ $formatted -eq 0 ]; then
  echo "  All $total files already properly formatted"
else
  echo "  ✅ Formatted $formatted of $total ShellSpec files"
fi

exit 0
