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
  End
