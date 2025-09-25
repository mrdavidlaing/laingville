#!/usr/bin/awk -f
# ShellSpec formatter - formats ShellSpec test files with proper indentation
# Usage: awk -f lib/shellspec-formatter.awk input_file > output_file

BEGIN {
  indent = 0
  in_heredoc = 0
  heredoc_marker = ""
  in_quoted_string = 0
  in_bash_script = 0
  pre_heredoc_indent = 0
}

# Detect heredoc start - simplified pattern without complex regex
# Look for << followed by optional spaces and an identifier
/<</ && !in_heredoc {
  # Store current indent level before entering heredoc
  pre_heredoc_indent = indent

  # Extract heredoc marker using basic string functions (portable)
  heredoc_line = $0
  # Find the position of <<
  heredoc_pos = index(heredoc_line, "<<")
  if (heredoc_pos > 0) {
    # Extract everything after <<
    marker_part = substr(heredoc_line, heredoc_pos + 2)
    # Remove leading and trailing spaces
    gsub(/^[[:space:]]*/, "", marker_part)
    gsub(/[[:space:]]*$/, "", marker_part)
    # Remove quotes if present (handle both single and double quotes)
    if (match(marker_part, /^['"].*['"]$/)) {
      marker_part = substr(marker_part, 2, length(marker_part) - 2)
    }
    # Use the marker as-is (should be something like EOF, END, etc.)
    if (length(marker_part) > 0) {
      heredoc_marker = marker_part
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
    # Restore indent to pre-heredoc level
    indent = pre_heredoc_indent
  }
  next
}

# Detect inline bash scripts - look for bash -c ' pattern (also handle sh -c)
/bash[[:space:]]+-c[[:space:]]*'[[:space:]]*$/ && !in_bash_script {
  in_bash_script = 1
  print $0
  next
}

# Also handle sh -c ' pattern
/sh[[:space:]]+-c[[:space:]]*'[[:space:]]*$/ && !in_bash_script {
  in_bash_script = 1
  print $0
  next
}

# Pass through bash script content unchanged
in_bash_script == 1 {
  print $0
  # Check if line ends with single quote to close the bash script
  if (/^[[:space:]]*'[[:space:]]*$/) {
    in_bash_script = 0
  }
  next
}

# Detect multi-line quoted strings - basic pattern
# This is a simplified version that handles common cases
/echo[[:space:]]+\\042/ && !/echo[[:space:]]+\\042[^\\042]*\\042[[:space:]]*$/ {
  in_quoted_string = 1
}

# Pass through quoted string content unchanged
in_quoted_string == 1 {
  print $0
  # End quoted string if line ends with quote and redirect
  if (/\\042[[:space:]]*>/) {
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

    # Increase indent after block-opening keywords (after printing)
    if (content ~ /^Describe[[:space:]]/ || content ~ /^Context[[:space:]]/ ||
        content ~ /^It[[:space:]]/ || content ~ /^Specify[[:space:]]/ ||
        content ~ /^Example[[:space:]]/ || content ~ /^Before[[:space:]]/ ||
        content ~ /^After[[:space:]]/ || content ~ /^BeforeAll[[:space:]]/ ||
        content ~ /^AfterAll[[:space:]]/) {
      indent = indent + 2
    }
  } else {
    # Empty line - just print as-is
    print ""
  }
}