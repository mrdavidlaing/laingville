#!/bin/bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe 'Lazygit configuration validation'
  Describe 'dotfiles/mrdavidlaing/.config/lazygit/config.yml'
    It 'should have valid YAML syntax and be parseable by lazygit'
      Skip if "lazygit is not available" test ! -x "$(command -v lazygit 2>/dev/null)"

# Test that the config can be loaded without errors by checking config validation
# This validates both YAML syntax and lazygit-specific configuration including migrations
      When call lazygit --use-config-file dotfiles/mrdavidlaing/.config/lazygit/config.yml --config
      The status should be success
      The stdout should include "gui:"
      The stderr should not include "Couldn't migrate"
      The stderr should not include "yaml node"
      The stderr should not include "not a dictionary"
      The stderr should not include "parse"
      The stderr should not include "invalid"
    End
  End
End
