#!/bin/bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Include lib/polyfill.functions.bash

# Test helper function to create temp files for testing
create_temp_test_file() {
local content="$1"
local extension="${2:-sh}"
local temp_file
temp_file=$(mktemp_with_suffix ".$extension")
printf '%s\n' "$content" > "$temp_file"
printf '%s\n' "$temp_file"
}

# Test helper to clean up temp files
cleanup_temp_file() {
local temp_file="$1"
[[ -f "$temp_file" ]] && rm -f "$temp_file"
}

Describe "format-files.sh - Line Ending Standards"
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"

    Describe "Line Ending Standards - Bash/Shell (LF)"
      It "converts bash files with CRLF to LF"
        temp_file=$(mktemp_with_suffix ".sh")
        # Create file with CRLF line endings
        printf '#!/bin/bash\r\necho "test"\r\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Verify CRLF was removed (grep should fail to find \r)
        When run grep -q $'\r' "$temp_file"
        The status should be failure

        cleanup_temp_file "$temp_file"
      End

      It "maintains LF line endings in bash files"
        temp_file=$(mktemp_with_suffix ".sh")
        printf '#!/bin/bash\necho "test"\n' > "$temp_file"

        # Get checksum before
        before=$(cksum "$temp_file" | awk '{print $1}')

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Get checksum after
        after=$(cksum "$temp_file" | awk '{print $1}')

        # File should be unchanged (same checksum)
        When run test "$before" = "$after"
        The status should be success

        cleanup_temp_file "$temp_file"
      End

      It "normalizes mixed line endings in bash files to LF"
        temp_file=$(mktemp_with_suffix ".sh")
        # Mix LF and CRLF
        printf '#!/bin/bash\necho "line1"\r\necho "line2"\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Verify no CRLF remains
        When run grep -q $'\r' "$temp_file"
        The status should be failure

        cleanup_temp_file "$temp_file"
      End

      It "maintains LF in ShellSpec files"
        temp_file=$(mktemp_with_suffix "_spec.sh")
        printf 'Describe "test"\n  It "works"\n  End\nEnd\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Verify no CRLF
        When run grep -q $'\r' "$temp_file"
        The status should be failure

        cleanup_temp_file "$temp_file"
      End
    End
  End
