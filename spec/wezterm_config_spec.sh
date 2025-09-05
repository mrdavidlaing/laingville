#!/bin/bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe 'WezTerm configuration validation'
  Describe 'dotfiles/mrdavidlaing/.config/wezterm/wezterm.lua'
    It 'should have valid WezTerm syntax and load without errors'
      Skip if "wezterm is not available" test ! -x "$(command -v wezterm 2>/dev/null)"
      When call wezterm --config-file dotfiles/mrdavidlaing/.config/wezterm/wezterm.lua ls-fonts --list-system
      The status should be success
      The stdout should not be blank
      The stderr should eq ""
    End
  End
End
