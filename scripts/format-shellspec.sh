#!/bin/bash
# format-shellspec.sh
# Formats ShellSpec test files with proper indentation
# Compatible with both GNU AWK (Linux) and BSD AWK (macOS)

echo "🎨 Formatting ShellSpec tests..."

# Cross-platform compatible AWK formatting function
format_file() {
  local file="$1"
  local temp_file="${file}.tmp"

  # Use a portable AWK script that works on both GNU and BSD AWK
  awk '
  BEGIN { 
    indent = 0
    in_heredoc = 0
    heredoc_marker = ""
    in_quoted_string = 0
  }
  
  # Detect heredoc start - simplified pattern without complex regex
  # Look for << followed by optional spaces and an identifier
  /<</ && !in_heredoc {
    # Extract heredoc marker using basic string functions (portable)
    heredoc_line = $0
    # Find the position of <<
    heredoc_pos = index(heredoc_line, "<<")
    if (heredoc_pos > 0) {
      # Extract everything after <<
      marker_part = substr(heredoc_line, heredoc_pos + 2)
      # Remove leading spaces
      gsub(/^[[:space:]]*/, "", marker_part)
      # Remove quotes if present (simplified - handle common cases)
      gsub(/^['"'"']/, "", marker_part)
      gsub(/['"'"']$/, "", marker_part)
      # Extract just the marker (everything up to first space or special char)
      if (match(marker_part, /^[A-Za-z_][A-Za-z0-9_]*/)) {
        heredoc_marker = substr(marker_part, RSTART, RLENGTH)
        in_heredoc = 1
      }
    }
    print $0
    next
  }
  
  # Pass through heredoc content unchanged
  in_heredoc == 1 {
    print $0
    # Check if this line matches the heredoc end marker exactly
    if ($0 == heredoc_marker) {
      in_heredoc = 0
      heredoc_marker = ""
    }
    next
  }
  
  # Detect multi-line quoted strings - basic pattern
  # This is a simplified version that handles common cases
  /echo[[:space:]]+"/ && !/echo[[:space:]]+"[^"]*"[[:space:]]*$/ {
    in_quoted_string = 1
  }
  
  # Pass through quoted string content unchanged
  in_quoted_string == 1 {
    print $0
    # End quoted string if line ends with quote and redirect
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
  
  # Process content lines
  {
    # Store original line and create content without leading whitespace
    original_line = $0
    content = original_line
    # Remove leading whitespace to normalize content
    gsub(/^[[:space:]]+/, "", content)
  }
  
  # Handle End keyword - decrease indent before printing
  content ~ /^End[[:space:]]*$/ {
    if (indent > 0) {
      indent = indent - 2
    }
    # Print with current indentation
    for (i = 0; i < indent; i++) {
      printf " "
    }
    print "End"
    next
  }
  
  # Print line with current indentation level
  {
    if (length(content) > 0) {
      # Print indentation
      for (i = 0; i < indent; i++) {
        printf " "
      }
      print content
    } else {
      # Empty line - just print as-is
      print ""
    }
  }
  
  # Increase indent after block-opening keywords
  # Use simple pattern matching instead of complex regex
  content ~ /^Describe[[:space:]]/ || content ~ /^Context[[:space:]]/ || 
  content ~ /^It[[:space:]]/ || content ~ /^Specify[[:space:]]/ || 
  content ~ /^Example[[:space:]]/ || content ~ /^Before[[:space:]]/ || 
  content ~ /^After[[:space:]]/ || content ~ /^BeforeAll[[:space:]]/ || 
  content ~ /^AfterAll[[:space:]]/ {
    indent = indent + 2
  }
  ' "$file" > "$temp_file"

  # Only update if file changed and temp file is not empty
  if [ -s "$temp_file" ] && ! cmp -s "$file" "$temp_file"; then
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
