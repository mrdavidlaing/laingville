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
echo "$content" > "$temp_file"
echo "$temp_file"
}

# Test helper to clean up temp files
cleanup_temp_file() {
local temp_file="$1"
[[ -f "$temp_file" ]] && rm -f "$temp_file"
}

Describe "format-files.sh - Comprehensive Formatting Test Suite"
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"

    Describe "Basic Functionality"
      It "shows help when called with --help"
        When run ./scripts/format-files.sh --help
        The status should be success
        The output should include "Usage:"
        The output should include "format-files.sh"
        The output should include "*.sh, *.bash"
        The output should include "*_spec.sh"
        The output should include "*_spec.sh"
      End

      It "shows help when called with -h"
        When run ./scripts/format-files.sh -h
        The status should be success
        The output should include "Usage:"
      End

      It "fails when no file is provided"
        When run ./scripts/format-files.sh
        The status should be failure
        The stderr should include "Error: At least one file path is required"
      End

      It "fails when file does not exist"
        When run ./scripts/format-files.sh nonexistent.sh
        The status should be failure
        The stderr should include "Error: File does not exist"
      End

      It "fails with unknown option"
        When run ./scripts/format-files.sh --unknown-option
        The status should be failure
        The stderr should include "Unknown option"
      End

      It "handles multiple files automatically"
        When run ./scripts/format-files.sh --check scripts/lint-bash.sh scripts/format-files.sh
        The status should be success
        The stderr should include "Processing 2 files"
      End
    End

    Describe "File Type Detection"
      It "detects bash files (.sh)"
      # Create a simple bash file
        temp_file=$(create_temp_test_file "#!/bin/bash\necho 'test'")

        When run ./scripts/format-files.sh "$temp_file"
        The status should be success
        The stderr should include "Formatting bash file"

        cleanup_temp_file "$temp_file"
      End

      It "detects bash files (.bash)"
        temp_file=$(create_temp_test_file "#!/bin/bash\necho 'test'" "bash")

        When run ./scripts/format-files.sh "$temp_file"
        The status should be success
        The stderr should include "Formatting bash file"

        cleanup_temp_file "$temp_file"
      End

      It "detects ShellSpec files (*_spec.sh)"
        temp_file=$(create_temp_test_file "Describe 'test'\nIt 'works'\nEnd\nEnd" "_spec.sh")

        When run ./scripts/format-files.sh "$temp_file"
        The status should be success
        The stderr should include "Formatting ShellSpec file"

        cleanup_temp_file "$temp_file"
      End


      It "handles unsupported file types gracefully"
        temp_file=$(create_temp_test_file "some content" "txt")

        When run ./scripts/format-files.sh "$temp_file"
        The status should be success
        The stderr should include "✓ Formatting complete"
        The stderr should include "No formatter available for file type"

        cleanup_temp_file "$temp_file"
      End
    End

    Describe "Single File Mode"
      It "formats a single bash file successfully"
        temp_file=$(create_temp_test_file "#!/bin/bash\necho    'test'")

        When run ./scripts/format-files.sh "$temp_file"
        The status should be success
        The stderr should include "✓ Formatting complete"

        cleanup_temp_file "$temp_file"
      End

      It "handles check mode on properly formatted file"
        temp_file=$(create_temp_test_file "#!/bin/bash\necho 'test'")

        When run ./scripts/format-files.sh --check "$temp_file"
        The status should be success
        The output should be blank

        cleanup_temp_file "$temp_file"
      End
    End

    Describe "Batch Mode"
      It "formats multiple files in batch mode"
        temp_file1=$(create_temp_test_file "#!/bin/bash\necho 'test1'")
        temp_file2=$(create_temp_test_file "#!/bin/bash\necho 'test2'")

        When run ./scripts/format-files.sh --batch "$temp_file1" "$temp_file2"
        The status should be success
        The stderr should include "🎨 Processing 2 files"
        The stderr should include "no-changes"

        cleanup_temp_file "$temp_file1"
        cleanup_temp_file "$temp_file2"
      End

      It "handles mixed file types in batch mode"
        temp_bash=$(create_temp_test_file "#!/bin/bash\necho 'bash'")
        temp_spec=$(create_temp_test_file "Describe 'test'\nEnd" "spec.sh")
        temp_ps1=$(create_temp_test_file "Write-Host 'ps1'" "ps1")

        When run ./scripts/format-files.sh --batch "$temp_bash" "$temp_spec" "$temp_ps1"
        The status should be success
        The stderr should include "🎨 Processing 3 files"

        cleanup_temp_file "$temp_bash"
        cleanup_temp_file "$temp_spec"
        cleanup_temp_file "$temp_ps1"
      End

      It "handles batch check mode"
        temp_file1=$(create_temp_test_file "#!/bin/bash\necho 'test1'")
        temp_file2=$(create_temp_test_file "#!/bin/bash\necho 'test2'")

        When run ./scripts/format-files.sh --check --batch "$temp_file1" "$temp_file2"
        The status should be success
        The stderr should include "✅ All 2 files are properly formatted"

        cleanup_temp_file "$temp_file1"
        cleanup_temp_file "$temp_file2"
      End
    End

    Describe "Batch Processing Optimizations"
      It "processes multiple bash files efficiently"
        # Create 5 bash files to test batch processing
        temp_files=()
        for i in 1 2 3 4 5; do
        temp_files+=("$(create_temp_test_file "#!/bin/bash\necho 'test$i'")")
        done

        When run ./scripts/format-files.sh --batch "${temp_files[@]}"
        The status should be success
        The stderr should include "🎨 Processing 5 files"
        The stderr should include "[shfmt"

        # Cleanup
        for f in "${temp_files[@]}"; do
        cleanup_temp_file "$f"
        done
      End

      It "processes multiple PowerShell files efficiently"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        # Create 3 PowerShell files to test batch processing
        temp_files=()
        for i in 1 2 3; do
        temp_files+=("$(create_temp_test_file "Write-Host 'test$i'" "ps1")")
        done

        When run ./scripts/format-files.sh --batch "${temp_files[@]}"
        The status should be success
        The stderr should include "🎨 Processing 3 files"
        The stderr should include "[powershell"

        # Cleanup
        for f in "${temp_files[@]}"; do
        cleanup_temp_file "$f"
        done
      End

      It "processes multiple ShellSpec files efficiently"
        # Create 3 ShellSpec files
        temp_files=()
        for i in 1 2 3; do
        temp_files+=("$(create_temp_test_file "Describe 'test$i'\nIt 'works'\nEnd\nEnd" "_spec.sh")")
        done

        When run ./scripts/format-files.sh --batch "${temp_files[@]}"
        The status should be success
        The stderr should include "🎨 Processing 3 files"
        The stderr should include "[shellspec"

        # Cleanup
        for f in "${temp_files[@]}"; do
        cleanup_temp_file "$f"
        done
      End

      It "handles large batches of mixed file types"
        # Create 10 bash, 5 ShellSpec, 3 PowerShell files
        temp_files=()

        # Bash files
        for i in 1 2 3 4 5 6 7 8 9 10; do
        temp_files+=("$(create_temp_test_file "#!/bin/bash\necho 'bash$i'")")
        done

        # ShellSpec files
        for i in 1 2 3 4 5; do
        temp_files+=("$(create_temp_test_file "Describe 'test$i'\nEnd" "_spec.sh")")
        done

        # PowerShell files (only if available)
        if command -v pwsh > /dev/null 2>&1 || command -v pwsh.exe > /dev/null 2>&1; then
        for i in 1 2 3; do
        temp_files+=("$(create_temp_test_file "Write-Host 'ps$i'" "ps1")")
        done
        expected_count=18
        else
        expected_count=15
        fi

        When run ./scripts/format-files.sh --batch "${temp_files[@]}"
        The status should be success
        The stderr should include "🎨 Processing $expected_count files"

        # Cleanup
        for f in "${temp_files[@]}"; do
        cleanup_temp_file "$f"
        done
      End

      It "detects changes correctly in batch mode"
        # Create a file with poor formatting (no indentation)
        temp_file=$(mktemp_with_suffix ".sh")
        cat > "$temp_file" << 'TESTEOF'
#!/bin/bash
if true; then
echo 'test'
fi
TESTEOF

        # Get checksum before formatting
        before_sum=$(cksum "$temp_file" | awk '{print $1}')

        # Format the file
        ./scripts/format-files.sh --batch "$temp_file" > /dev/null 2>&1

        # Get checksum after formatting
        after_sum=$(cksum "$temp_file" | awk '{print $1}')

        # Checksums should differ (file was changed)
        When run test "$before_sum" != "$after_sum"
        The status should be success

        cleanup_temp_file "$temp_file"
      End
    End

    Describe "ShellSpec Formatting with Fixtures"
    # Test helper function that uses format-files.sh directly
      format_test_file() {
      local input_file="$1"
      local expected_file="$2"
      local temp_file
      temp_file=$(mktemp_with_suffix "_spec.sh")

      # Copy input to temp file
      cp "$input_file" "$temp_file"

      # Format using format-files.sh
      ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

      # Compare with expected output
      diff -u "$expected_file" "$temp_file"
      local result=$?

      rm -f "$temp_file"
      return "$result"
      }

      It "formats basic ShellSpec structure correctly"
        When call format_test_file "spec/fixtures/format_input_basic.sh" "spec/fixtures/format_expected_basic.sh"
        The status should be success
      End

      It "preserves heredoc content"
        When call format_test_file "spec/fixtures/format_input_heredoc.sh" "spec/fixtures/format_expected_heredoc.sh"
        The status should be success
      End

      It "preserves YAML structure in heredocs"
        When call format_test_file "spec/fixtures/format_input_yaml_heredoc.sh" "spec/fixtures/format_expected_yaml_heredoc.sh"
        The status should be success
      End

      It "preserves shell scripts in heredocs"
        When call format_test_file "spec/fixtures/format_input_script_heredoc.sh" "spec/fixtures/format_expected_script_heredoc.sh"
        The status should be success
      End

      It "handles complex ShellSpec structures"
        When call format_test_file "spec/fixtures/format_input_complex.sh" "spec/fixtures/format_expected_complex.sh"
        The status should be success
      End
    End

    Describe "Cross-platform Compatibility"
      It "works with basic AWK commands"
        When run awk 'BEGIN { print "test" }'
        The status should be success
        The output should equal "test"
      End

      It "supports POSIX character classes"
        When run awk 'BEGIN { s = "  test"; gsub(/^[[:space:]]+/, "", s); print s }'
        The status should be success
        The output should equal "test"
      End

      It "supports string functions used in formatting"
        When run awk 'BEGIN { print substr("hello", 2, 3) }'
        The status should be success
        The output should equal "ell"
      End

      It "supports match function for regex"
        When run awk 'BEGIN { if (match("test123", /[0-9]+/)) print "found" }'
        The status should be success
        The output should equal "found"
      End
    End

    Describe "Integration Tests"
      It "works with real ShellSpec files in the project"
      # Test with a real spec file from the project
        When run ./scripts/format-files.sh --check spec/shared_functions_spec.sh
        The status should be success
      End

      It "can format multiple real files in batch"
        When run ./scripts/format-files.sh --check --batch spec/shared_functions_spec.sh spec/logging_functions_spec.sh
        The status should be success
        The stderr should include "All 2 files are properly formatted"
      End
    End

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

    Describe "Line Ending Standards - PowerShell (CRLF)"
      It "converts PowerShell files with LF to CRLF"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        temp_file=$(mktemp_with_suffix ".ps1")
        # Create file with LF line endings
        printf 'Write-Host "test"\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check last 2 bytes should be 0d 0a (CRLF)
        last_two=$(tail -c 2 "$temp_file" | od -An -tx1 | tr -d ' ')

        When run test "$last_two" = "0d0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End

      It "maintains CRLF line endings in PowerShell files"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        temp_file=$(mktemp_with_suffix ".ps1")
        # Create file with CRLF
        printf 'Write-Host "test"\r\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check last 2 bytes should still be 0d 0a (CRLF)
        last_two=$(tail -c 2 "$temp_file" | od -An -tx1 | tr -d ' ')

        When run test "$last_two" = "0d0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End

      It "normalizes mixed line endings in PowerShell files to CRLF"
        Skip if "PowerShell not available" ! command -v pwsh > /dev/null 2>&1 && ! command -v pwsh.exe > /dev/null 2>&1

        temp_file=$(mktemp_with_suffix ".ps1")
        # Mix LF and CRLF
        printf 'Write-Host "line1"\nWrite-Host "line2"\r\n' > "$temp_file"

        # Format the file
        ./scripts/format-files.sh "$temp_file" > /dev/null 2>&1

        # Check last 2 bytes should be 0d 0a (CRLF)
        last_two=$(tail -c 2 "$temp_file" | od -An -tx1 | tr -d ' ')

        When run test "$last_two" = "0d0a"
        The status should be success

        cleanup_temp_file "$temp_file"
      End
    End

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
