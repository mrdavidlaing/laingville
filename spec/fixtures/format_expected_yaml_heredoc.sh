#!/bin/bash

Describe "YAML heredoc test"
It "should preserve YAML structure in heredocs"
# Create test YAML file
cat > "${temp_file}" << 'EOF'
arch:
  yay:
    - vim
    - curl
windows:
  winget:
    - Git.Git
EOF

chmod +x "${script_file}"

When call test_command
The status should be success
End
End
