#!/bin/bash

Describe 'tmux configuration validation'
Describe 'dotfiles/mrdavidlaing/.config/tmux/tmux.conf'
It 'should have valid tmux syntax'
Skip if "tmux is not available" ! command -v tmux > /dev/null 2>&1
When call tmux -S /tmp/tmux-test-$$ -f dotfiles/mrdavidlaing/.config/tmux/tmux.conf start-server \; source-file dotfiles/mrdavidlaing/.config/tmux/tmux.conf \; kill-server
The status should be success
The stderr should eq ""
End
End
End
