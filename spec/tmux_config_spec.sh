#!/bin/bash

# ShellSpec framework functions (Before, After, It, etc.) trigger SC2218 false positives
# shellcheck disable=SC2218

Describe 'tmux configuration validation'
  Describe 'dotfiles/mrdavidlaing/.config/tmux/tmux.conf'
    It 'should have valid tmux syntax'
      Skip if "tmux is not available" ! command -v tmux > /dev/null 2>&1
      Skip if "tmux socket creation blocked (likely sandbox)" bash -c '
        socket="/tmp/tmux-spec-probe-$$"
        if tmux -S "${socket}" start-server >/dev/null 2>&1; then
          if [ -S "${socket}" ]; then
            tmux -S "${socket}" kill-server >/dev/null 2>&1 || true
            exit 1
          else
            exit 0
          fi
        else
          exit 0
        fi
      '
      When call tmux -S /tmp/tmux-test-$$ -f dotfiles/mrdavidlaing/.config/tmux/tmux.conf start-server \; source-file dotfiles/mrdavidlaing/.config/tmux/tmux.conf \; kill-server
      The status should be success
      The stderr should eq ""
    End
  End
End
