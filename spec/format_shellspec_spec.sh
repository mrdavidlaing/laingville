#!/bin/bash

Describe "format-shellspec.sh script"
  Before "cd '${SHELLSPEC_PROJECT_ROOT}'"

    Describe "basic functionality"
      It "runs the format script successfully"
        When run ./scripts/format-shellspec.sh
        The status should be success
        The output should include "Formatting ShellSpec tests"
      End
    End

    Describe "cross-platform AWK compatibility" 
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
    End

    Describe "heredoc formatting"
      # Test the format_file function directly on fixtures
      format_test_file() {
      local input_file="$1"
      local expected_file="$2"
      local temp_file=$(mktemp)
        
      cp "$input_file" "$temp_file"
        
        # Extract format_file function and run it
      eval "$(sed -n '/^format_file() {/,/^}/p' scripts/format-shellspec.sh)"
      format_file "$temp_file"
        
        # Compare with expected output
      diff -u "$expected_file" "$temp_file"
      local result=$?
        
      rm -f "$temp_file"
      return "$result"
      }

      It "preserves YAML structure in heredocs"
        When call format_test_file "spec/fixtures/format_input_yaml_heredoc.sh" "spec/fixtures/format_expected_yaml_heredoc.sh"
        The status should be success
      End

      It "preserves shell scripts in heredocs"
        When call format_test_file "spec/fixtures/format_input_script_heredoc.sh" "spec/fixtures/format_expected_script_heredoc.sh"
        The status should be success
      End

      It "preserves basic heredoc content"
        When call format_test_file "spec/fixtures/format_input_heredoc.sh" "spec/fixtures/format_expected_heredoc.sh"
        The status should be success
      End
    End
  End
