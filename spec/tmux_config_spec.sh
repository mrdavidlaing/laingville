#!/bin/bash

Describe 'tmux configuration validation'
  Describe 'dotfiles/mrdavidlaing/.config/tmux/tmux.conf'
    It 'should have valid tmux syntax'
      When call tmux -f dotfiles/mrdavidlaing/.config/tmux/tmux.conf start-server \; source-file dotfiles/mrdavidlaing/.config/tmux/tmux.conf \; kill-server
      The status should be success
      The stderr should eq ""
    End
  End
End