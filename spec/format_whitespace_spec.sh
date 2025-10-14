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

Describe "format-files.sh - Whitespace Standards"
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"

    Describe "Trailing Newline Standards"
      It "adds trailing newline to bash file that lacks one"
        temp_file=$(mktemp_with_suffix ".sh")
        # Create file without trailing newline
        printf '#!/bin/bash\necho "test"' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check last byte is 0a (LF)
        last_byte=$(tail -c 1 "$temp_file" | od -An -tx1 | tr -d ' ')

        When run test "$last_byte" = "0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End

      It "reduces multiple blank lines at end to single newline for bash"
        temp_file=$(mktemp_with_suffix ".sh")
        # Create file with multiple blank lines at end
        printf '#!/bin/bash\necho "test"\n\n\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check file ends with exactly one newline (last char is newline, second-to-last is not)
        last_two=$(tail -c 2 "$temp_file" | od -An -tx1 | tr -d ' ')

        # Should NOT be two newlines (0a0a)
        When run test "$last_two" != "0a0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End

      It "adds trailing CRLF to PowerShell file that lacks one"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        temp_file=$(mktemp_with_suffix ".ps1")
        # Create file without trailing newline
        printf 'Write-Host "test"' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check last 2 bytes are 0d 0a (CRLF)
        last_two=$(tail -c 2 "$temp_file" | od -An -tx1 | tr -d ' ')

        When run test "$last_two" = "0d0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End

      It "reduces multiple blank lines at end to single CRLF for PowerShell"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        temp_file=$(mktemp_with_suffix ".ps1")
        # Create file with multiple blank lines at end
        printf 'Write-Host "test"\r\n\r\n\r\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check file ends with exactly one CRLF
        # Read last 4 bytes - should be 0d 0a (not 0d 0a 0d 0a)
        last_four=$(tail -c 4 "$temp_file" | od -An -tx1 | tr -d ' ')

        # Should end with single CRLF, not double
        When run test "$last_four" != "0d0a0d0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End
    End

    Describe "Trailing Whitespace Standards"
      It "removes trailing spaces from bash file lines"
        temp_file=$(mktemp_with_suffix ".sh")
        # Create file with trailing spaces
        printf '#!/bin/bash  \necho "test"   \n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check no lines have trailing spaces (grep should fail)
        When run grep ' $' "$temp_file"
        The status should be failure

        cleanup_temp_file "$temp_file"
      End

      It "removes trailing tabs from bash file lines"
        temp_file=$(mktemp_with_suffix ".sh")
        # Create file with trailing tabs
        printf '#!/bin/bash\t\necho "test"\t\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check no lines have trailing tabs
        When run grep $'\t$' "$temp_file"
        The status should be failure

        cleanup_temp_file "$temp_file"
      End

      It "removes trailing spaces from PowerShell files while preserving CRLF"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        temp_file=$(mktemp_with_suffix ".ps1")
        # Create file with trailing spaces and CRLF
        printf 'Write-Host "test"   \r\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check no trailing spaces before CRLF
        When run grep ' '$'\r$' "$temp_file"
        The status should be failure

        cleanup_temp_file "$temp_file"
      End

      It "preserves empty lines while removing their whitespace"
        temp_file=$(mktemp_with_suffix ".sh")
        # Create file with whitespace-only lines
        printf '#!/bin/bash\n   \necho "test"\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Should still have 3 lines
        line_count=$(wc -l < "$temp_file")

        When run test "$line_count" -ge 3
        The status should be success

        cleanup_temp_file "$temp_file"
      End
    End
  End
